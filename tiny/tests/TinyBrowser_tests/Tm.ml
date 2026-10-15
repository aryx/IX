(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Runs TinyBrowser.ml on tiny-cpu, built by tiny-ml -tm; it does what
 * Host.ml does on the host. It reads the page from the standard input
 * in messages of at most 1,000 bytes (what tiny-kernel's wire gives),
 * and prints the lines. This file is only for tiny-ml: tiny-ml has no
 * modules, so the browser's functions are called without the
 * TinyBrowser. prefix, and the two externals are defined in tm.c.
 * usage: tiny-cpu tm.img width < page.html *)
external www_width : unit -> int = "www_width"
external www_read : int -> string = "www_read"

let () =
  let p = create (www_width ()) in
  let rec go () = let s = www_read 1000 in if s <> "" then begin feed p s; go () end in
  go ();
  finish p;
  print_string (dump p)
