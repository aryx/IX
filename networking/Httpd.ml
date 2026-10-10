(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-httpd: a directory's files served over HTTP, to this machine
 * only (127.0.0.1), after the author's mini-chrome's tools/httpd: a
 * request read, its file answered (a directory: its index.html, or its
 * names as links), the connection closed, the next one taken. One
 * client at a time; GET only; nothing above the directory served. No
 * WebSocket here (mini-chrome's echoes one). *)

type caps = < Cap.network; Cap.open_in; Cap.readdir; Cap.stdout; Cap.stderr >

let usage = "usage: mini-httpd [-p port] [directory]
  -p  the port (8000; 0: one the system chooses, said on the first line)"

let content_type (name : string) : string =
  (* (lib_core's Filename has no extension) *)
  let base = Filename.basename name in
  let ext = match String.rindex_opt base '.' with Some i -> String.sub base i (String.length base - i) | None -> "" in
  match String.lowercase_ascii ext with
  | ".html" | ".htm" -> "text/html; charset=utf-8"
  | ".css" -> "text/css"
  | ".js" | ".mjs" -> "text/javascript"
  | ".json" -> "application/json"
  | ".txt" | ".md" | ".ml" | ".mli" -> "text/plain; charset=utf-8"
  | ".svg" -> "image/svg+xml"
  | ".png" -> "image/png"
  | ".jpg" | ".jpeg" -> "image/jpeg"
  | ".gif" -> "image/gif"
  | ".pdf" -> "application/pdf"
  | _ -> "application/octet-stream"

let chars (s : string) : char list = List.init (String.length s) (String.get s)

let escape (s : string) : string =
  String.concat "" (List.map (fun c -> match c with '&' -> "&amp;" | '<' -> "&lt;" | '>' -> "&gt;" | '"' -> "&quot;" | c -> String.make 1 c) (chars s))

(* %20 as a space; a + stays a + (a path, not a form's field) *)
let unescape (s : string) : string =
  let b = Buffer.create (String.length s) in
  let rec go i =
    if i < String.length s then
      match (s.[i], if i + 2 < String.length s then int_of_string_opt ("0x" ^ String.sub s (i + 1) 2) else None) with
      | '%', Some code -> Buffer.add_char b (Char.chr code); go (i + 3)
      | c, _ -> Buffer.add_char b c; go (i + 1)
  in
  go 0;
  Buffer.contents b

(* a name as a link's address: what a URL cannot hold as it is, as %XX *)
let quote (s : string) : string =
  String.concat "" (List.map (fun c -> match c with ' ' | '%' | '?' | '#' | '"' -> Printf.sprintf "%%%02X" (Char.code c) | c -> String.make 1 c) (chars s))

let html = "text/html; charset=utf-8"

let page (status : int) (text : string) : Http.response =
  Http.response status ~content_type:html
    (Printf.sprintf "<!doctype html><title>%d %s</title><h1>%d %s</h1><p>%s</p>\n" status (Http.reason status) status (Http.reason status) (escape text))

(* a directory's page: what is in it, each a link, the directories first *)
let listing (_caps : < Cap.readdir; .. >) (path : string) (dir : string) : Http.response =
  let names = List.sort compare (Array.to_list (Sys.readdir dir)) in
  let is_dir n = Sys.is_directory (Filename.concat dir n) in
  let item n = let n = if is_dir n then n ^ "/" else n in Printf.sprintf "<li><a href=\"%s\">%s</a>\n" (escape (quote n)) (escape n) in
  let dirs, files = List.partition is_dir names in
  Http.response 200 ~content_type:html
    (Printf.sprintf "<!doctype html><title>%s</title><h1>%s</h1>\n<ul>\n%s</ul>\n" (escape path) (escape path) (String.concat "" (List.map item (dirs @ files))))

let answer (caps : < Cap.open_in; Cap.readdir; .. >) ~(root : string) (request : Http.request) : Http.response =
  let target = match String.index_opt request.target '?' with Some i -> String.sub request.target 0 i | None -> request.target in
  let raw = unescape target in
  (* a/../b is b; more ".." than directories before them would go
   * above the root *)
  let above =
    let rec go depth parts = match parts with [] -> false | ".." :: rest -> depth = 0 || go (depth - 1) rest | ("" | ".") :: rest -> go depth rest | _ :: rest -> go (depth + 1) rest in
    go 0 (String.split_on_char '/' raw)
  in
  let path = Url.remove_dot_segments raw in
  let file = root ^ path in
  let send (file : string) : Http.response =
    try Http.response 200 ~content_type:(content_type file) (FS.read caps (Fpath.v file)) with Sys_error why -> page 403 why in
  if request.meth <> "GET" then page 405 (request.meth ^ " is not allowed here: only GET.")
  else if above || String.contains path '\000' || not (String.starts_with ~prefix:"/" path) then page 403 "Nothing above the directory served."
  else if not (Sys.file_exists file) then page 404 (path ^ " is not here.")
  else if not (Sys.is_directory file) then send file
  else if not (String.ends_with ~suffix:"/" path) then { (page 301 (path ^ "/")) with headers = [ ("Location", path ^ "/"); ("Content-Type", html) ] }
  else
    let index = Filename.concat file "index.html" in
    if Sys.file_exists index then send index else listing caps path file

(* a line of the log, out at once: a server's output is read while it runs *)
let say (caps : < Cap.stdout; .. >) (line : string) : unit =
  Console.print caps (line ^ "\n");
  flush (Console.stdout caps)

let listen (_caps : < Cap.network; .. >) (port : int) : Unix.file_descr * int =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
  Unix.listen sock 16;
  (sock, match Unix.getsockname sock with Unix.ADDR_INET (_, p) -> p | _ -> port)

(* a request read from a connection, piece by piece, until it is whole
 * (or the client is gone, says nothing for five seconds, or it is too
 * long to be one) *)
let read_request (fd : Unix.file_descr) : Http.parsed_request =
  let buffer = Bytes.create 4096 and so_far = Buffer.create 1024 in
  let rec go () =
    match Http.parse_request (Buffer.contents so_far) with
    | Http.Incomplete when Buffer.length so_far < 1_000_000 -> (
        match Unix.select [ fd ] [] [] 5.0 with
        | [], _, _ -> Http.Bad "nothing said in five seconds"
        | _ -> (
            match Unix.read fd buffer 0 4096 with
            | 0 -> Http.Bad "the connection closed before the request's end"
            | n -> Buffer.add_subbytes so_far buffer 0 n; go ()))
    | Http.Incomplete -> Http.Bad "the request is too long"
    | r -> r
  in
  go ()

let rec serve (caps : < caps; .. >) ~(root : string) (sock : Unix.file_descr) : 'a =
  let fd, _ = Unix.accept sock in
  (try
     let said, (response : Http.response) =
       match read_request fd with
       | Http.Request (r, _, _) -> (r.meth ^ " " ^ r.target, answer caps ~root r)
       | Http.Bad why -> ("?", page 400 why)
       | Http.Incomplete -> ("?", page 400 "not a whole request")
     in
     let bytes = Http.response_to_string response in
     let rec write pos = if pos < String.length bytes then write (pos + Unix.write_substring fd bytes pos (String.length bytes - pos)) in
     write 0;
     say caps (Printf.sprintf "%s %d %d" said response.status (String.length response.body))
   with Unix.Unix_error _ | Sys_error _ -> ());
  (try Unix.close fd with Unix.Unix_error _ -> ());
  serve caps ~root sock

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let rec options port root args =
    match args with
    | [] -> Some (port, root)
    | "-p" :: p :: rest -> ( match int_of_string_opt p with Some p -> options p root rest | None -> None)
    | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
    | dir :: rest -> options port dir rest
  in
  match options 8000 "." (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"
  | Some (_, root) when not (Sys.file_exists root && Sys.is_directory root) -> Console.eprint caps (root ^ ": not a directory\n"); Exit.Err "directory"
  | Some (port, root) -> (
      match listen caps port with
      | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "port %d: %s\n" port (Unix.error_message e)); Exit.Err "port"
      | sock, port ->
          (* a client that left before its answer: an error of the write, not
           * a signal that ends the program *)
          Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
          say caps (Printf.sprintf "serving %s on http://127.0.0.1:%d/" root port);
          serve caps ~root sock)

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
