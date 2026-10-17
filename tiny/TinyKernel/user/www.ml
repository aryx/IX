(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* www, tiny-kernel's web browser: ../../TinyBrowser.ml's browse, on the
 * address given (its words joined, so that www Plan 9 from Bell Labs
 * needs no quotes). The Makefile gives tiny-ml ../libml/calls.ml,
 * ../../TinyLibStd.ml, ../../TinyLibDraw.ml and ../../TinyBrowser.ml
 * before this file, as one program, and links it as an a.out that asks
 * for 10 MB (tiny-cpu -a 10): a page's lines live in the heap. OCaml
 * compiles it too, for the host (tiny-www, ../../sdl/): its calls
 * TinyCalls's, a window's and the host's network.
 *
 *     www OCaml *)
open TinyCalls
open TinyBrowser

let () =
  let n = u_argc () in
  if n < 2 then (ignore (u_write 2 "usage: www address\n"); exit 1);
  let rec words i acc = if i >= n then acc else words (i + 1) (if acc = "" then u_arg i else acc ^ " " ^ u_arg i) in
  browse (words 1 "");
  exit 0
