(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/net/XMLHttpRequest.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See XMLHttpRequest.mli *)
open Js_value
open Script_types
open Script_host

let fn (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

(* new XMLHttpRequest(): [o], the object new made, given its state and
 * its methods *)
let make (t : t) (o : obj) : unit =
  let meth = ref "GET" and url = ref "" and content_type = ref "text/plain;charset=UTF-8" and headers = ref [] in
  let sent : int option ref = ref None and answered : answer option ref = ref None in
  let listeners : (string * value) list ref = ref [] in
  let set k v = set_own o k v in
  let state (n : int) = set "readyState" (Number (float_of_int n)) in
  (* an event: the on... property's function, then the listeners' *)
  let fire (typ : string) : unit =
    let ev = Script_events.make ~bubbles:false typ [ ("target", Object o); ("currentTarget", Object o) ] in
    Script_fetch.call t ((match (get_own o ("on" ^ typ)) with Some v_ -> v_ | None -> Undefined)) ~this:(Object o) [ ev ];
    List.iter (fun (ty, f) -> if ty = typ then Script_fetch.call t f ~this:(Object o) [ ev ]) !listeners
  in
  state 0;
  set "status" (Number 0.);
  set "statusText" (String "");
  set "responseText" (String "");
  set "response" (String "");
  set "responseURL" (String "");
  set "responseType" (String "");
  set "open" (fn "open" (fun args ->
      meth := str (arg args 0);
      url := str (arg args 1);
      state 1;
      fire "readystatechange";
      Undefined));
  set "setRequestHeader" (fn "setRequestHeader" (fun args ->
      if String.lowercase_ascii (str (arg args 0)) = "content-type" then content_type := str (arg args 1);
      headers := (str (arg args 0), str (arg args 1)) :: !headers;
      Undefined));
  set "send" (fn "send" (fun args ->
      let post = match arg args 0 with Undefined | Null -> None | body -> Some (!content_type, Script_fetch.body_bytes t body) in
      let done_ (result : (answer, string) result) : unit =
        (match result with
        | Ok a ->
            answered := Some a;
            set "status" (Number (float_of_int a.status));
            set "statusText" (String (Http.reason a.status));
            set "responseText" (String a.body);
            set "responseURL" (String a.final);
            (* responseType "json": the body parsed, null if it is not JSON *)
            set "response" (if get_own o "responseType" = Some (String "json") then (try Script_fetch.parse_json t a.body with Throw _ -> Null) else String a.body)
        | Error _ -> ());
        state 4;
        fire "readystatechange";
        fire (if Result.is_ok result then "load" else "error");
        fire "loadend"
      in
      (match get_own o "responseType" with
      (* an answer as bytes (an ArrayBuffer, a Blob) is not done here: a
       * string given for one would be read wrong. The request is not
       * sent and fails, a moment later, as one the network lost *)
      | Some (String ("arraybuffer" | "blob")) ->
          ignore (Event_loop.add ~frame:false t [ fn "failed" (fun _ -> done_ (Error "no bytes"); Undefined); Number 0. ] ~repeat:false)
      | _ -> sent := Some (Script_fetch.ask ~cors:true ~headers:(List.rev !headers) ~ahead:None t ~meth:!meth ~url:!url ~post done_));
      Undefined));
  (* what libraries set or call before sending, and that changes nothing here *)
  set "overrideMimeType" (fn "overrideMimeType" (fun _ -> Undefined));
  set "withCredentials" (Bool false);
  set "timeout" (Number 0.);
  (let upload = new_object () in
   set_own upload "addEventListener" (fn "addEventListener" (fun _ -> Undefined));
   set_own upload "removeEventListener" (fn "removeEventListener" (fun _ -> Undefined));
   set "upload" (Object upload));
  set "abort" (fn "abort" (fun _ -> Option.iter (Script_fetch.forget t) !sent; state 0; Undefined));
  set "getResponseHeader" (fn "getResponseHeader" (fun args ->
      match Option.bind !answered (fun a -> Script_fetch.header a (str (arg args 0))) with Some v -> String v | None -> Null));
  set "getAllResponseHeaders" (fn "getAllResponseHeaders" (fun _ ->
      String (match !answered with Some a -> String.concat "" (List.map (fun (k, v) -> String.lowercase_ascii k ^ ": " ^ v ^ "\r\n") a.headers) | None -> "")));
  set "addEventListener" (fn "addEventListener" (fun args -> listeners := !listeners @ [ (str (arg args 0), arg args 1) ]; Undefined));
  set "removeEventListener" (fn "removeEventListener" (fun args ->
      listeners := List.filter (fun (ty, f) -> not (ty = str (arg args 0) && strict_equal f (arg args 1))) !listeners;
      Undefined))

let install (t : t) (define : string -> value -> unit) : unit =
  let c =
    host_function "XMLHttpRequest" (fun ~this _ ->
        let o = match this with Object o -> o | _ -> throw "TypeError" "Failed to construct 'XMLHttpRequest': Please use the 'new' operator" in
        make t o;
        Undefined)
  in
  (match c with
  | Object c -> List.iter (fun (k, n) -> set_own c k (Number n)) [ ("UNSENT", 0.); ("OPENED", 1.); ("HEADERS_RECEIVED", 2.); ("LOADING", 3.); ("DONE", 4.) ]
  | _ -> ());
  define "XMLHttpRequest" c
