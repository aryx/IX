(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* troff, a program of TinyKernel.ml's: ../TinyTroff.ml, a page of
 * the office's (or a Markdown file) printed as text or as a web page
 * (../TinyOffice/TinyOfficeFile.ml reads the page).
 *
 *     troff file        its text, 72 columns
 *     troff -h file     its web page
 *     troff -p file     its PDF
 *
 * What is here: the file read (TinyLibGUI's read_file), printed on the
 * standard output. So a page is published by
 *
 *     troff -h page > page.html; put page.html
 *
 * put keeping it at the wire's other end. OCaml compiles it too, for
 * the host (tiny-troff, sdl/): its system TinyLibSystem's, the host's
 * files and standard output (no window: troff draws nothing). *)
module TSys = TinyLibSystem
open TinyTroff

let () =
  TSys.main "troff" (fun caps argv ->
    let flag = if Array.length argv = 3 then argv.(1) else "" in
    if Array.length argv <> 2 && flag <> "-h" && flag <> "-p" then begin
      TSys.eprint caps "usage: troff [-h | -p] file\n";
      Exit.Code 1
    end
    else begin
      let file = argv.(Array.length argv - 1) in
      (* (a file not there read as "", as before: TSys's Failure caught) *)
      let doc = try TSys.read_file caps (Fpath.v file) with Failure _ -> "" in
      TSys.print caps
        (if flag = "-h" then to_html file doc
         else if flag = "-p" then to_pdf doc
         else to_text 72 doc);
      Exit.OK
    end)
