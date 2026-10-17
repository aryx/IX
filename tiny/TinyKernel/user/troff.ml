(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* troff, a program of TinyKernel.ml's: ../../TinyTroff.ml, a page of
 * the office's (or a Markdown file) printed as text or as a web page
 * (given to tiny-ml with ../../TinyOffice.ml, which reads the page,
 * and what it is on, as one program: the Makefile).
 *
 *     troff file        its text, 72 columns
 *     troff -h file     its web page
 *
 * What is here: the file read (TinyLibGUI's read_file), printed on the
 * standard output. So a page is published by
 *
 *     troff -h page > page.html; put page.html
 *
 * put keeping it at the wire's other end. Not OCaml's to compile: it
 * names the kernel's calls. *)
open TinyTroff
open TinyLibGUI

let () =
  let n = u_argc () in
  let html = n = 3 && u_arg 1 = "-h" in
  if n <> 2 && not html then (ignore (u_write 2 "usage: troff [-h] file\n"); exit 1);
  let file = u_arg (n - 1) in
  ignore (u_write 1 (if html then to_html file (read_file file) else to_text 72 (read_file file)));
  exit 0
