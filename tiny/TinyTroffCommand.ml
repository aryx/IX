(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tiny-troff on the host: TinyTroff.ml, a page of tiny-office's (or a
 * Markdown file) printed on the standard output, as tiny-kernel's troff
 * does (TinyKernel/user/troff.ml):
 *
 *     tiny-troff page.ixd             its text, 72 columns
 *     tiny-troff -h page.ixd          its web page
 *     tiny-troff -p page.ixd          its PDF *)

let usage = "usage: tiny-troff [-h | -p] file"

let main (caps : < Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. >) =
  let print f file = Console.print caps (f (FS.read caps (Fpath.v file))); 0 in
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | [ file ] -> print (TinyTroff.to_text 72) file
  | [ "-h"; file ] -> print (TinyTroff.to_html file) file
  | [ "-p"; file ] -> print TinyTroff.to_pdf file
  | _ -> Console.eprint caps (usage ^ "\n"); 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
