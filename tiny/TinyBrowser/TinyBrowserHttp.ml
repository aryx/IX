(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowserHttp.mli *)
open TinyBrowserText

(*****************************************************************************)
(* Requests *)
(*****************************************************************************)

let request url = "GET " ^ url ^ " HTTP/1.0\r\nUser-Agent: www\r\n\r\n"

(* the first line's middle: what is between its first and its last
 * space (an address typed with a space in it is still one) *)
let asked s =
  let line =
    match String.index_opt s '\n' with
    | Some i -> String.trim (String.sub s 0 i)
    | None -> String.trim s in
  match String.index_opt line ' ', String.rindex_opt line ' ' with
  | Some i, Some j when j > i && String.sub line 0 i = "GET" ->
    Some (String.trim (String.sub line i (j - i)))
  | _ -> None

(*****************************************************************************)
(* Responses *)
(*****************************************************************************)

let reason status =
  match status with
  | 200 -> "OK" | 301 -> "Moved Permanently" | 302 -> "Found"
  | 304 -> "Not Modified" | 400 -> "Bad Request" | 403 -> "Forbidden"
  | 404 -> "Not Found" | 500 -> "Internal Server Error"
  | 502 -> "Bad Gateway" | _ -> ""

let response status headers body =
  "HTTP/1.0 " ^ string_of_int status ^ " " ^ reason status ^ "\r\n"
  ^ String.concat ""
      (List.map (fun (n, v) -> n ^ ": " ^ v ^ "\r\n") headers)
  ^ "Content-Length: " ^ string_of_int (String.length body) ^ "\r\n\r\n"
  ^ body

(* an empty line ends the head, its line ends \r\n or \n alone *)
let head_end s =
  let a = find s "\r\n\r\n" 0 and b = find s "\n\n" 0 in
  if a >= 0 && (b < 0 || a + 2 <= b) then a + 4
  else if b >= 0 then b + 2
  else -1

let status head =
  if not (String.starts_with "HTTP/" head) then 0
  else
    match String.index_opt head ' ' with
    | Some i when String.length head >= i + 4 ->
      number (String.sub head (i + 1) 3)
    | _ -> 0

let header head name =
  let name = String.lowercase_ascii name in
  let rec look lines =
    match lines with
    | [] -> ""
    | l :: rest ->
      (match String.index_opt l ':' with
       | Some i when String.lowercase_ascii (String.trim (String.sub l 0 i))
                     = name ->
         String.trim (String.sub l (i + 1) (String.length l - i - 1))
       | _ -> look rest) in
  match String.split_on_char '\n' head with
  | _ :: lines -> look lines
  | [] -> ""

let media_type head =
  let v = header head "Content-Type" in
  String.lowercase_ascii
    (String.trim
       (match String.index_opt v ';' with
        | Some i -> String.sub v 0 i
        | None -> v))
