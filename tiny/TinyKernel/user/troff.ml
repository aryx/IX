(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* troff, a program of TinyKernel.ml's: ../../TinyTroff.ml, a page of
 * the office's (or a Markdown file) printed as text or as a web page
 * (../../TinyOffice.ml reads the page).
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
 * the host (tiny-troff, ../../sdl/): its calls TinyCalls's, the host's
 * files and standard output (no window: troff draws nothing). *)
open TinyCalls
open TinyLibGUI
open TinyTroff

let () =
  let n = u_argc () in
  let flag = if n = 3 then u_arg 1 else "" in
  if n <> 2 && flag <> "-h" && flag <> "-p" then (ignore (u_write 2 "usage: troff [-h | -p] file\n"); exit 1);
  let file = u_arg (n - 1) in
  let doc = read_file file in
  ignore (u_write 1 (if flag = "-h" then to_html file doc else if flag = "-p" then to_pdf doc else to_text 72 doc));
  exit 0
