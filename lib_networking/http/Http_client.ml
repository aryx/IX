(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/unix/Http_client.ml; no optional argument (post an option, five redirections, Tcp's timeout), get_once is once; options (more headers, the connection kept, a jar of cookies) said by the _with functions (docs/plans/plan_browser.md) *)

(* See Http_client.mli *)

let ( let* ) = Result.bind
let max_redirects = 5

(* what a request says and does besides: more headers (a script's own),
 * whether an https:// connection is kept for the next request to its
 * host (Keep_alive.mli, with the numbers), and the jar its cookies are
 * from and its answer's go to *)
type options = { said : Http.header list; keep : bool; jar : Cookie_jar.t option }

let defaults : options = { said = []; keep = false; jar = None }

let prepare_with (o : options) ~(post : (string * string) option) (url : Url.t) : (string * int * string, string) result =
  match (url.scheme, url.authority, Url.port url) with
  | Some ("http" | "https"), Some (a : Url.authority), Some port ->
      (* the Host header says the port only when it isn't the default *)
      let host_header = match a.port with Some p -> Printf.sprintf "%s:%d" a.host p | None -> a.host in
      (* "[::1]" in a URL, "::1" for the resolver *)
      let host =
        if String.starts_with ~prefix:"[" a.host then String.sub a.host 1 (String.length a.host - 2) else a.host
      in
      let target = Url.request_target url in
      (* the cookies kept for that URL, said back *)
      let cookie = match Option.bind o.jar (fun jar -> Cookie_jar.header jar url) with Some c -> [ ("Cookie", c) ] | None -> [] in
      let kept (r : Http.request) = if o.keep && url.scheme = Some "https" then Http.keeping r else r in
      let bytes =
        match post with
        | None -> Http.request_to_string ~body:"" (kept (Http.saying (cookie @ o.said) (Http.get ~host:host_header target)))
        | Some (content_type, body) -> Http.request_to_string ~body (kept (Http.saying (cookie @ o.said) (Http.post ~host:host_header ~content_type ~body target)))
      in
      Ok (host, port, bytes)
  | Some ("http" | "https"), _, _ -> Error (Printf.sprintf "%s: no host" (Url.to_string url))
  | _ -> Error (Printf.sprintf "%s: not an http:// or https:// URL" (Url.to_string url))

(* one request, no redirection followed: over TCP, or inside TLS for
   https:// (Tls_client, our own TLS 1.3) *)
let once_with (o : options) (caps : < Cap.network; Cap.open_in; .. >) ~(post : (string * string) option) (url : Url.t) : (Http.response, string) result =
  let* host, port, request = prepare_with o ~post url in
  let* (response : Http.response) =
    if url.scheme = Some "https" then
      let trust = Tls_client.system_roots caps in
      (* old: Tls_client.exchange alone, a connection and its handshake a request *)
      let* answer = if o.keep then Keep_alive.exchange caps ~trust ~host ~port request else Tls_client.exchange caps ~trust ~host ~port request in
      Http.parse_response answer
    else
      match Tcp.exchange caps ~host ~port request with
      | answer -> Http.parse_response answer
      | exception Unix.Unix_error (e, _, _) -> Error (Printf.sprintf "%s: %s" (Url.to_string url) (Unix.error_message e))
      | exception Failure msg -> Error msg
  in
  (* the cookies it sets, kept -- a redirection's too, before the next
   * request is made (a login answers 302 and Set-Cookie) *)
  (match o.jar with Some jar -> Cookie_jar.received jar url response.headers | None -> ());
  Ok response

let fetch_with (o : options) (caps : < Cap.network; Cap.open_in; .. >) ~(post : (string * string) option) (s : string) : (string * Http.response, string) result =
  let rec follow ~(post : (string * string) option) (url : Url.t) (left : int) =
    let* (response : Http.response) = once_with o caps ~post url in
    match (Http.is_redirect response.status, Http.header "Location" response.headers) with
    | true, Some location ->
        if left = 0 then Error (Printf.sprintf "%s: too many redirections" s)
        else
          let* next = Url.parse location in
          (* a redirection is followed with a GET, as browsers do *)
          follow ~post:None (Url.resolve url next) (left - 1)
    | _ -> Ok (Url.to_string url, response)
  in
  let* url = Url.parse s in
  follow ~post url max_redirects

let prepare ~(post : (string * string) option) (url : Url.t) : (string * int * string, string) result = prepare_with defaults ~post url
let once (caps : < Cap.network; Cap.open_in; .. >) ~(post : (string * string) option) (url : Url.t) : (Http.response, string) result = once_with defaults caps ~post url
let fetch (caps : < Cap.network; Cap.open_in; .. >) ~(post : (string * string) option) (s : string) : (string * Http.response, string) result = fetch_with defaults caps ~post s

let get (caps : < Cap.network; Cap.open_in; .. >) (s : string) : (Http.response, string) result = Result.map snd (fetch caps ~post:None s)
