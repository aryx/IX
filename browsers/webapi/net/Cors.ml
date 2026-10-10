(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/net/Cors.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Cors.mli *)

(* a URL's origin: its scheme, host and port, as "scheme://host:port",
 * the port left out when it is the scheme's own; "null" for a URL
 * that has no host *)
let origin (url : string) : string =
  match String.index_opt url ':' with
  | Some i when i + 2 < String.length url && url.[i + 1] = '/' && url.[i + 2] = '/' ->
      let scheme = String.lowercase_ascii (String.sub url 0 i) in
      let rest = String.sub url (i + 3) (String.length url - i - 3) in
      let stop = List.fold_left (fun stop c -> match String.index_opt rest c with Some j -> min stop j | None -> stop) (String.length rest) [ '/'; '?'; '#' ] in
      let authority = String.lowercase_ascii (String.sub rest 0 stop) in
      (* past a user's name, were there one *)
      let host = match String.rindex_opt authority '@' with Some j -> String.sub authority (j + 1) (String.length authority - j - 1) | None -> authority in
      let default = match scheme with "http" | "ws" -> ":80" | "https" | "wss" -> ":443" | _ -> ":" in
      let host = if String.ends_with ~suffix:default host then String.sub host 0 (String.length host - String.length default) else host in
      if host = "" then "null" else scheme ^ "://" ^ host
  | _ -> "null"

let same_origin (a : string) (b : string) : bool = origin a = origin b

let header (headers : (string * string) list) (name : string) : string option =
  List.find_map (fun (k, v) -> if String.lowercase_ascii k = String.lowercase_ascii name then Some (String.trim v) else None) headers

(* the page's own origin's, or one whose answer says the page may *)
let readable ~(page : string) ~(url : string) (headers : (string * string) list) : bool =
  same_origin page url || match header headers "Access-Control-Allow-Origin" with Some allowed -> allowed = "*" || allowed = origin page | None -> false

let blocked ~(page : string) ~(url : string) : string =
  Printf.sprintf "%s has been blocked by CORS policy: no Access-Control-Allow-Origin header for %s" url (origin page)
