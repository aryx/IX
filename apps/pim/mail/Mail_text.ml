(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_text.mli *)

let of_html (html : string) : string =
  let page = Line_mode.render 72 (Html_tree.of_string html) in
  let links =
    match page.links with
    | [] -> []
    | l ->
        ""
        :: List.mapi (fun i href -> Printf.sprintf "[%d] %s" (i + 1) href) l
  in
  String.concat "\n" (page.lines @ links)

let blank (s : string) : bool = String.trim s = ""

let size (n : int) : string =
  if n < 1024 then Printf.sprintf "%d bytes" n
  else if n < 1024 * 1024 then Printf.sprintf "%d KB" (n / 1024)
  else Printf.sprintf "%d MB" (n / (1024 * 1024))

let text (m : Mail.t) : string =
  let leaves = Mime.leaves m in
  let said (l : Mime.leaf) =
    l.mime = "text/plain" && l.filename = None && not (blank l.data)
  in
  let html = List.filter (fun (l : Mime.leaf) -> l.mime = "text/html") leaves in
  let body =
    if List.exists said leaves || html = [] then Mime.text m
    else
      String.concat "\n\n"
        (List.map (fun (l : Mime.leaf) -> of_html l.data) html)
  in
  let attached =
    List.map
      (fun (l : Mime.leaf) ->
        let name = match l.filename with Some f -> f | None -> "(no name)" in
        Printf.sprintf "[attached: %s, %s, %s]" name l.mime
          (size (String.length l.data)))
      (Mime.attachments m)
  in
  match attached with
  | [] -> body
  | l -> String.concat "\n" ((String.trim body ^ "\n") :: l)
