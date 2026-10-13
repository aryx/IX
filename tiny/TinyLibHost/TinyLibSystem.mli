(* What a tool asks of the system it runs on, for a tool that runs on
 * two: tiny-shell, on the host and on tiny-machine. One file of the
 * tool, TinyShell.ml, names only this and the pure functions of the
 * standard library; there are two files of this:
 *
 *                      TinyShell.ml
 *            ___________/        \___________
 *   on the host                        on tiny-machine
 *   TinyLibHost/TinyLibSystem.ml       TinyLibSystem.ml, with the
 *   (this one's), OCaml, built by      other TinyLibXxx.ml: tiny-ml's
 *   dune or mini-mk                    ML, given with TinyLibStd.ml
 *   over Unix, Cap, FS, Procs          over tiny-kernel's calls
 *   Linux                              tiny-kernel
 *
 * So the interface is what both systems can give, which is the
 * smaller one's, tiny-kernel's: a descriptor is a number, a call that
 * fails raises Failure with the reason (the host's has the system's
 * message, tiny-kernel's has no reason to give), a child's status is
 * already rc's string. What tiny-kernel has not is answered there by
 * nothing: no environment but a PATH, no signal, no terminal to ask
 * about.
 *
 * The capabilities are the host's: there, a function that reaches the
 * system takes the object that allows it, and OCaml checks it. tiny-ml
 * reads them and forgets them.
 *)

(* [main name f]: the program: f with every capability, its result the
 * exit's code; name is for the host's logs *)
val main : string -> (Cap.all_caps -> int) -> unit

(* the program's name, then its arguments *)
val argv : < Cap.argv; .. > -> string list

(* the variables the program was started with, each with its value *)
val environment : < Cap.env; .. > -> (string * string) list
val getpid : unit -> int

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

(* on the standard output, kept until flush; on the error's, at once *)
val print : < Cap.stdout; .. > -> string -> unit
val eprint : < Cap.stderr; .. > -> string -> unit
val flush : unit -> unit

(* a line of the standard input without its end; None at the input's end *)
val read_line : < Cap.stdin; .. > -> string option

(* whether a descriptor is a terminal, where someone types *)
val isatty : int -> bool

(* an interrupt typed at the terminal is for the program that runs,
 * not for this one *)
val ignore_interrupt : unit -> unit

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* a file's descriptor: to read it, to write it from nothing (made if
 * it is not there), to write at its end. Failure with the reason *)
val open_in : < Cap.open_in; .. > -> string -> int
val open_out : < Cap.open_out; .. > -> string -> int
val open_append : < Cap.open_out; .. > -> string -> int
val close : int -> unit

(* a file's text; Failure with the reason *)
val read_file : < Cap.open_in; .. > -> string -> string

(* all that a descriptor gives, to its end *)
val read_all : int -> string

(* a directory's names, in no order; none when it cannot be read *)
val readdir : string -> string list
val is_directory : string -> bool

(* Failure with the reason *)
val chdir : < Cap.chdir; .. > -> string -> unit

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

(* [save n]: a copy of descriptor n, away from the low numbers and not
 * given to a program run; None when n is not open *)
val save : int -> int option

(* [dup2 a b]: b is now what a is *)
val dup2 : int -> int -> unit

(* a pipe: where to read, where to write; not given to a program run *)
val pipe : unit -> int * int

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* a copy of this process: 0 in the copy, the copy's number here *)
val fork : < Cap.fork; .. > -> int

(* [exec caps file argv env]: this process becomes the program in file,
 * env its variables as name=value; when it cannot, the reason *)
val exec : < Cap.exec; .. > -> string -> string list -> string list -> string

(* a child's end, as rc's status: "" when all went well, its code, or
 * "signal: " and the signal's name *)
val wait : < Cap.wait; .. > -> int -> string

(* the end of this process, at once: nothing flushed *)
val exit : int -> 'a
