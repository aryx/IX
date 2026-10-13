(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in ; Cap.stdin ; Cap.stdout ; Cap.stderr >

let usage =
  "usage: mini-troff [-man] [-T text] [file ...]\n\
  \  -man     the files are manual pages (the only kind read today)\n\
  \  -T text  written for a terminal (the only way today)\n\
   no file: the standard input. What is not understood is said on the\n\
   standard error, with its line.\n"

exception Usage

let text (name : string) (source : string) : string * string list =
  let roff = Roff.create Roff.Terminal source in
  let doc = Man.read roff in
  (To_text.page doc, List.map (fun (line, what) -> Printf.sprintf "%s:%d: %s: not known" name line what) (Roff.complaints roff))

(* all of a descriptor *)
let contents (fd : Unix.file_descr) : string =
  let all = Buffer.create 8192 and buf = Bytes.create 8192 in
  let rec go () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; go () | exception Unix.Unix_error _ -> () in
  go (); Buffer.contents all

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  try
    let rec options (l : string list) : string list =
      match l with
      | "-man" :: rest -> options rest
      | "-T" :: "text" :: rest | "-Ttext" :: rest -> options rest
      | "--" :: rest -> rest
      | a :: _ when String.length a > 1 && a.[0] = '-' -> raise Usage
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    let failed = ref false in
    let one (name : string) (source : string) =
      let page, complaints = text name source in
      Console.print caps page;
      List.iter (fun c -> Console.eprint caps (c ^ "\n")) complaints in
    if files = [] then one "<stdin>" (contents (Console.stdin_fd caps))
    else
      List.iter (fun file ->
        match FS.open_in_fd caps file with
        | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "mini-troff: %s: %s\n" file (Unix.error_message e)); failed := true
        | fd -> one file (Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> contents fd))) files;
    if !failed then Exit.Err "can't open" else Exit.OK
  with Usage -> Console.eprint caps usage; Exit.Err "usage"
