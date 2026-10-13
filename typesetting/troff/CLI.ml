(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in ; Cap.stdin ; Cap.stdout ; Cap.stderr >

let usage =
  "usage: mini-troff [-man|-ms|-md|-latex] [-T text|pdf|md] [file ...]\n\
  \  -man     the files are manual pages, man(6)'s macros\n\
  \  -ms      papers, ms(6)'s\n\
  \  -md      documents in Markdown's lines and \\name[options]{text}\n\
  \  -latex   simple LaTeX, and noweb's chunks of code in it\n\
  \           (with none: a file named .md or .ixd is in Markdown's\n\
  \           lines, one named .tex or .nw in LaTeX, a file with a .TH\n\
  \           is a manual page, another a paper)\n\
  \  -T text  written for a terminal (what is done with no -T)\n\
  \  -T pdf   a PDF file, on the standard output: one file read\n\
  \  -T md    the document written again, in Markdown's lines\n\
  \  -T words the PDF file's words, as text (what a typesetter is given,\n\
  \           which is not always what a terminal is)\n\
   no file: the standard input. What is not understood is said on the\n\
   standard error, with its line.\n"

exception Usage

type way = Text | Pdf | Words | Source

type package = Man | Ms | Md | Tex

(* what a file is written in, when it is not said: a manual page has a
 * .TH *)
let package_of (name : string) (source : string) : package =
  let ends (e : string) : bool = let n = String.length name and m = String.length e in n >= m && String.sub name (n - m) m = e in
  if ends ".md" || ends ".ixd" then Md else
  if ends ".tex" || ends ".nw" then Tex else
  let rec go (lines : string list) = match lines with [] -> Ms | l :: rest -> if String.starts_with ~prefix:".TH" l then Man else go rest in
  go (String.split_on_char '\n' source)

let typeset (way : way) (package : package option) (load : string -> string option) (name : string) (source : string) : string * string list =
  let paper = way <> Text in
  let roff = Roff.create (if paper then Roff.Typesetter else Roff.Terminal) source in
  if paper then Roff.set_measure roff To_pdf.measure;
  Roff.set_loader roff load;
  let doc, complaints =
    match (match package with Some p -> p | None -> package_of name source) with
    | Man -> let d = Man.read roff in (d, Roff.complaints roff)
    | Ms -> let d = Ms.read roff in (d, Roff.complaints roff)
    | Md -> Ixdoc.read paper load source
    | Tex -> Latex.read paper load source in
  let said = List.map (fun (line, what) -> Printf.sprintf "%s:%d: %s: not known" name line what) complaints in
  match way with
  | Text -> (To_text.page doc, said)
  | Source -> (Ixdoc.print paper doc, said)
  (* (with the characters the file has for others: a dash for a minus) *)
  | Words -> (To_text.page (Doc.map_text (fun (style : Doc.style) s -> To_pdf.shown style.font s) doc), said)
  | Pdf ->
      let bytes, missing, over = To_pdf.file doc in
      (bytes,
       said @ List.map (fun c -> Printf.sprintf "%s: the character %s: not in the fonts" name c) missing
       @ (if over > 0 then [ Printf.sprintf "%s: %d lines go past the paper's right edge" name over ] else []))

(* all of a descriptor *)
let contents (fd : Unix.file_descr) : string =
  let all = Buffer.create 8192 and buf = Bytes.create 8192 in
  let rec go () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; go () | exception Unix.Unix_error _ -> () in
  go (); Buffer.contents all

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  try
    let way = ref Text and package = ref None in
    let rec options (l : string list) : string list =
      match l with
      | "-man" :: rest -> package := Some Man; options rest
      | "-ms" :: rest -> package := Some Ms; options rest
      | "-md" :: rest -> package := Some Md; options rest
      | "-latex" :: rest -> package := Some Tex; options rest
      | "-T" :: "md" :: rest -> way := Source; options rest
      | "-T" :: "text" :: rest | "-Ttext" :: rest -> way := Text; options rest
      | "-T" :: "pdf" :: rest | "-Tpdf" :: rest -> way := Pdf; options rest
      | "-T" :: "words" :: rest -> way := Words; options rest
      | "--" :: rest -> rest
      | a :: _ when String.length a > 1 && a.[0] = '-' -> raise Usage
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    (* (a PDF file is one document) *)
    if !way = Pdf && List.length files > 1 then raise Usage;
    let failed = ref false in
    let one (name : string) (source : string) =
      (* (a file that the document names: .so, a picture's, \input's;
       * as it is named, or from where the document is, as LaTeX's are) *)
      let read (file : string) : string option = match FS.path file with Ok p -> FS.read_opt caps p | Error _ -> None in
      let load (file : string) : string option =
        match read file with
        | Some s -> Some s
        | None -> if Filename.is_relative file && Filename.dirname name <> "." then read (Filename.concat (Filename.dirname name) file) else None in
      let page, complaints = typeset !way !package load name source in
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
