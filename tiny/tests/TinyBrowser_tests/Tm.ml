(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Runs TinyBrowser.ml on tiny-cpu, built by tiny-ml; it does what
 * Host.ml does on the host. It reads the page from the standard input
 * in messages of at most 1,000 bytes (what tiny-kernel's wire gives),
 * and prints the lines. This file is only for tiny-ml: the two
 * externals are defined in tm.c.
 * (old: the browser's functions called without the TinyBrowser.
 * prefix, when tiny-ml had no modules)
 * usage: tiny-cpu tm.img width < page.html *)
external www_width : unit -> int = "www_width"
external www_read : int -> string = "www_read"

let () =
  let p = TinyBrowser.create (www_width ()) in
  let rec go () =
    let s = www_read 1000 in
    if s <> "" then begin TinyBrowser.feed p s; go () end in
  go ();
  TinyBrowser.finish p;
  print_string (Testutil_browser.dump p (www_width ()))
