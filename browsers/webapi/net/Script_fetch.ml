(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/net/Script_fetch.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_fetch.mli *)
open Js_value
open Script_types
open Script_host

let header (a : answer) (name : string) : string option = Cors.header a.headers name

(*****************************************************************************)
(* The request out, the answer back *)
(*****************************************************************************)

let ask ~(cors : bool) ~(headers : (string * string) list) ~(ahead : (string -> unit) option) (t : t) ~(meth : string) ~(url : string) ~(post : (string * string) option) (k : (answer, string) result -> unit) : int =
  t.next_request <- t.next_request + 1;
  let rid = t.next_request in
  if not cors then t.exempt <- rid :: t.exempt;
  let meth = String.uppercase_ascii meth in
  (* what the browser's Fetch cannot send is answered at once, by a failure *)
  if meth <> "GET" && meth <> "POST" then k (Error (meth ^ " is not sent here: GET and POST only"))
  else (
    let url = Browser_url.resolve t.base url in
    (* Origin: said to another site, and with any POST (the Fetch
     * Standard's "serializing a request origin") *)
    let origin = if meth = "POST" || Cors.origin url <> Cors.origin t.base then [ ("Origin", Cors.origin t.base) ] else [] in
    (* the script's own headers, but those that are the browser's to say *)
    let own (k, _) = not (List.mem (String.lowercase_ascii k) [ "host"; "cookie"; "origin"; "connection"; "content-length"; "content-type"; "accept-encoding"; "user-agent" ]) in
    t.requests <- { rid; meth; url; ahead; said = origin @ List.filter own headers; post = (if meth = "POST" then Some ((match post with Some v_ -> v_ | None -> ("text/plain;charset=UTF-8", ""))) else None) } :: t.requests;
    t.waiting <- (rid, k) :: t.waiting);
  rid

let forget (t : t) (rid : int) : unit = t.waiting <- List.remove_assoc rid t.waiting

let answer (t : t) (rid : int) (result : (answer, string) result) : unit =
  match List.assoc_opt rid t.waiting with
  | None -> ()
  | Some k ->
      forget t rid;
      k
        (match result with
        (* an answer the page may not read (Cors) is no answer *)
        | Ok a when (not (List.mem rid t.exempt)) && not (Cors.readable ~page:t.base ~url:a.final a.headers) ->
            let why = Cors.blocked ~page:t.base ~url:a.final in
            t.console <- why :: t.console;
            t.log why;
            Error why
        | r -> r)

let call (t : t) (f : value) ~(this : value) (args : value list) : unit =
  match f with
  | Object { kind = Closure _ | Host_function _; _ } -> (
      try ignore (Js_eval.call_in_run t.engine f ~this args)
      with Throw v ->
        let e = Js_eval.error_of t.engine v in
        let line = Printf.sprintf "%s (line %d)" (if String.starts_with ~prefix:"Uncaught" e.message then e.message else "Uncaught " ^ e.message) e.line in
        t.console <- line :: t.console;
        t.log line)
  | _ -> ()

(*****************************************************************************)
(* fetch *)
(*****************************************************************************)

(* a request's body as the bytes to send: a text as it is; bytes (a
 * Uint8Array, an ArrayBuffer: a payload the page compressed itself)
 * each a character -- not the list of their numbers, "31,139,8,0",
 * which is what a server was sent and said so *)
let body_bytes (t : t) (v : value) : string =
  let of_items (o : obj) = String.concat "" (List.map (fun b -> String.make 1 (Char.chr (int_of_float (to_number b) land 255))) (array_items o)) in
  match v with
  | Object ({ kind = Array _; _ } as o) -> of_items o
  | Object _ -> ( match Js_eval.get t.engine v "_bytes" with Object ({ kind = Array _; _ } as o) -> of_items o | _ -> to_string v)
  | v -> to_string v

let fn (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

(* a promise already settled *)
let resolved (t : t) (f : unit -> value) : value =
  let p, resolve, reject = Js_eval.promise t.engine in
  (match f () with v -> resolve v | exception Throw e -> reject e);
  p

(* JSON.parse, the engine's *)
let parse_json (t : t) (text : string) : value =
  match Js_eval.global t.engine "JSON" with
  | Some json -> Js_eval.call_in_run t.engine (Js_eval.get t.engine json "parse") ~this:json [ String text ]
  | None -> Undefined

(* what fetch's promise gives: the answer, its body as promises *)
let response (t : t) (a : answer) : value =
  let o = new_object () in
  let headers = new_object () in
  set_own headers "get" (fn "get" (fun args -> match header a (str (arg args 0)) with Some v -> String v | None -> Null));
  set_own headers "has" (fn "has" (fun args -> Bool (header a (str (arg args 0)) <> None)));
  set_own headers "forEach" (fn "forEach" (fun args -> List.iter (fun (k, v) -> call t (arg args 0) ~this:Undefined [ String v; String (String.lowercase_ascii k) ]) a.headers; Undefined));
  set_own o "ok" (Bool (a.status >= 200 && a.status < 300));
  set_own o "status" (Number (float_of_int a.status));
  set_own o "statusText" (String (Http.reason a.status));
  set_own o "url" (String a.final);
  set_own o "redirected" (Bool false);
  (* gone through as a Headers is: Gmail's fetch reads an answer's with entries() *)
  let listed (f : string * string -> value) = fn "entries" (fun _ -> Js_builtins.iterator (List.map (fun (k, v) -> f (String.lowercase_ascii k, v)) (List.sort compare a.headers))) in
  set_own headers "entries" (listed (fun (k, v) -> Object (Js_value.new_array [ String k; String v ])));
  set_own headers "@@iterator" (listed (fun (k, v) -> Object (Js_value.new_array [ String k; String v ])));
  set_own headers "keys" (listed (fun (k, _) -> String k));
  set_own headers "values" (listed (fun (_, v) -> String v));
  set_own o "headers" (Object headers);
  set_own o "text" (fn "text" (fun _ -> resolved t (fun () -> String a.body)));
  set_own o "json" (fn "json" (fun _ -> resolved t (fun () -> parse_json t a.body)));
  set_own o "clone" (fn "clone" (fun _ -> Object o));
  Object o

let install (t : t) (define : string -> value -> unit) : unit =
  define "fetch"
    (fn "fetch" (fun args ->
         (* fetch(url, init), fetch(request): an object with a url *)
         let property (v : value) (k : string) : value = match v with Object _ -> Js_eval.get t.engine v k | _ -> Undefined in
         let url = match arg args 0 with Object _ as r when property r "url" <> Undefined -> str (property r "url") | v -> str v in
         (* a Request says its own method and body, if nothing else does *)
         let init = match (arg args 1, arg args 0) with Undefined, (Object _ as r) -> r | i, _ -> i in
         let meth = match property init "method" with Undefined -> "GET" | m -> str m in
         (* its headers: an object of them, or a Headers and the one it keeps *)
         let headers = match property init "headers" with Object _ as h -> (match property h "_h" with Object _ as kept -> kept | _ -> h) | v -> v in
         let said = match headers with Object o -> List.map (fun k -> (k, str (property headers k))) (Js_value.keys o) | _ -> [] in
         let content_type = match List.find_opt (fun (k, _) -> String.lowercase_ascii k = "content-type") said with Some (_, c) -> c | None -> "text/plain;charset=UTF-8" in
         let post = match property init "body" with Undefined | Null -> None | b -> Some (content_type, body_bytes t b) in
         let p, resolve, reject = Js_eval.promise t.engine in
         ignore
           (ask ~cors:true ~headers:said ~ahead:None t ~meth ~url ~post (fun result ->
                match result with
                | Ok a -> resolve (response t a)
                (* no answer, or one not to be read: as browsers say it *)
                | Error _ -> reject (error "TypeError" "Failed to fetch")));
         p))
