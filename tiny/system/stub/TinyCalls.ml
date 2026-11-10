(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyKernel.ml's calls, for a program built by OCaml: what
 * TinyLibPlayground.ml asks of its machine, so that a game is tested on
 * the host first (plan_tiny_windows.md). On tiny-machine these names
 * are externals (../tinykernel/TinyCalls.ml, which names mlsys.c's
 * functions); tiny-ml reads `open TinyCalls` and leaves it. Here there
 * is no kernel: what a program writes to where it draws (fd_draw) is
 * kept in [drawn], for a test to give TinyKernelGraphics.ml; no key is
 * ever typed, the clock does not move, and there is no network (u_dial
 * answers -1). *)

(* a program's first descriptors (../TinyCalls.mli) *)
let fd_stdin = 0
let fd_stdout = 1
let fd_stderr = 2
let fd_draw = 3
let fd_mouse = 4

let drawn = Buffer.create 4096
(* (old: 1, where the interface says 0 when all was written) *)
let u_write fd s = if fd = fd_draw then Buffer.add_string drawn s; 0
let u_read (_ : int) (_ : int) = ""
let u_ready (_ : int array) (_ : int) (_ : int) = 0
let u_rawcons (_ : int) = 0

let u_open (_ : string) (_ : int) = -1
(* u_open's flags (../TinyCalls.mli) *)
let o_read = 0
let o_anew = 0x601
let o_write = 0x201
let o_read_write = 0x202
let u_close (_ : int) = 0
let u_stat (_ : string) = ""

let u_ticks () = 0
let u_time () = 0
let u_seed () = 0

let u_spawn (_ : string) (_ : string list) = -1
(* a program with no arguments (tiny-ml compiles this file too, for the
 * tests on tiny-cpu, and has no Sys.argv) *)
let u_argc () = 1
let u_arg (_ : int) = "test"

let u_dial (_ : string) (_ : int) = -1
