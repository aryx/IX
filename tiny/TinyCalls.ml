(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyKernel.ml's calls, for a program built by OCaml: what
 * TinyPlayground.ml asks of its machine, so that a game is tested on
 * the host first (plan_tiny_windows.md). On tiny-machine these names
 * are externals (TinyKernel/user/calls.ml, which names mlsys.c's
 * functions); tiny-ml reads `open TinyCalls` and leaves it. Here there
 * is no kernel: what a program writes to where it draws (its
 * descriptor 3) is kept in [drawn], for a test to give TinyGraphics.ml;
 * no key is ever typed and the clock does not move. *)

let drawn = Buffer.create 4096
let u_write fd s = if fd = 3 then Buffer.add_string drawn s; 1
let u_read (_ : int) (_ : int) = ""
let u_ready (_ : int array) (_ : int) (_ : int) = 0
let u_ticks () = 0
