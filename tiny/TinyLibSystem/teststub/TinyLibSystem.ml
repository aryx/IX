(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibSystem for the tests of a window's program (../../TinyLibSystem.mli):
 * no kernel and no host. What the program writes where it draws
 * (fd_draw) is kept, in TinySystemTest.drawn, for a test to give
 * TinyKernelGraphics.ml; no key is ever typed (a read is "", the keys'
 * end), the clock does not move, and every file and process asked for
 * is a Failure (the speaker's open too: a game then plays in silence).
 * tiny-ml compiles this file too, for the tests on tiny-cpu, which has
 * three system calls: nothing here is Unix's. *)

type pid = int
type fd = int
type status = string
type stat = { st_dir : bool; st_size : int }
type seconds = int
type milliseconds = int

(* what a test's program asks and the stub has not *)
let none what = failwith (what ^ ": not in the tests' stub")

let main _ _ = none "main"
let logging args = args
let environment _ = []
let getpid _ = 1

(* the terminal: nothing printed, nothing read *)
let print _ _ = ()
let eprint _ _ = ()
let flush _ = ()
let read_line _ = None
let isatty _ = false
let ignore_interrupt _ = ()
let raw_console _ _ = ()

(* files: none *)
let open_in _ _ = none "open_in"
let open_out _ _ = none "open_out"
let open_append _ _ = none "open_append"
let close _ = ()
let open_rw _ _ = none "open_rw"
let seek _ _ = none "seek"
let seek_end _ = none "seek_end"
let read_file _ _ = none "read_file"
let write_file _ _ _ = none "write_file"
let with_open_in _ _ _ = none "with_open_in"
let with_open_out _ _ _ = none "with_open_out"
let with_open_append _ _ _ = none "with_open_append"
let stdin _ = none "stdin"
let readdir _ _ = []
let is_directory _ _ = false
let chdir _ _ = none "chdir"
let stat _ _ = none "stat"
let links _ _ = none "links"
let mtime _ _ = none "mtime"
let mkdir _ _ = none "mkdir"
let remove _ _ = none "remove"
let link _ _ _ = none "link"
let rename _ _ _ = none "rename"
let is_executable _ _ = false
let set_executable _ _ _ = none "set_executable"
let touch _ _ = none "touch"
let getcwd _ = none "getcwd"

(* the clock, still *)
let time _ = 0
let sleep _ _ = ()
let millis _ = 0
let seed _ = 0

(* descriptors: the drawing kept; a wait ends at once on the keys,
 * whose read is their end *)
let fd_stdin = 0
let fd_stdout = 1
let fd_stderr = 2
let fd_draw = 3
let fd_mouse = 4
let ready _ _ = Some fd_stdin
let read _ _ = ""
let read_all _ = ""
let write n s = if n = fd_draw then Buffer.add_string TinySystemTest.drawn s
let save _ = None
let dup2 _ _ = ()
let pipe _ = none "pipe"

(* processes: none *)
let fork _ = none "fork"
let kill _ _ = false
let exec _ _ _ _ = "not in the tests' stub"
let wait _ _ = ""
let wait_any _ = None
let shell _ _ _ = None
let spawn _ _ _ = None
let exit _ (e : Exit.t) =
  exit (match e with Exit.OK -> 0 | Exit.Err _ -> 1 | Exit.Code n -> n)

(* the network: none *)
let dial _ _ _ = none "dial"
