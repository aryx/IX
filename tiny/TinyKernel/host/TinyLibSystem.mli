(* What a tool asks of the system it runs on, for a tool that runs on
 * two: tiny-shell and tiny-utils, on the host and on tiny-machine.
 * The tool's one file, TinyShell.ml or TinyUtilities.ml, names only
 * this and the pure functions of the standard library; there are two
 * files of this:
 *
 *               TinyShell.ml, TinyUtilities.ml
 *            ___________/        \___________
 *   on the host                        on tiny-machine
 *   TinyKernel/host/TinyLibSystem.ml   TinyKernel/libml/TinyLibSystem.ml
 *   (this one's), OCaml, built by      built by tiny-ml,
 *   dune or mini-mk                    on TinyLibCore/
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
 * exit's code; a Failure that f lets out said after name, the code 1.
 * name is for the host's logs too *)
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

(* a file's descriptor to read and write it, at any place (a database's
 * file); made empty when it is not there. Failure with the reason *)
val open_rw : < Cap.open_in; Cap.open_out; .. > -> string -> int

(* [seek fd off]: the next read or write at off from the file's start;
 * [seek_end fd]: at its end, which is the offset given *)
val seek : int -> int -> unit
val seek_end : int -> int

(* a file's text; Failure with the reason *)
val read_file : < Cap.open_in; .. > -> string -> string

(* all that a descriptor gives, to its end *)
val read_all : int -> string

(* a directory's names, in no order; none when it cannot be read *)
val readdir : string -> string list
val is_directory : string -> bool

(* Failure with the reason *)
val chdir : < Cap.chdir; .. > -> string -> unit

(* [read fd max]: what fd gives next, up to max bytes, without waiting
 * for more; "" at the end. For a program that must work on its input
 * as it comes (cat at the console) *)
val read : int -> int -> string

(* all of the string, written to the descriptor *)
val write : int -> string -> unit

(* whether a file is a directory, and its size in bytes; Failure with
 * the reason when it is not there *)
val stat : string -> bool * int

(* how many names a file has (its hard links); Failure with the reason
 * when it is not there *)
val links : string -> int

(* the date of a file's last write, seconds since 2000-01-01 (the image's
 * files on tiny-kernel: 0); Failure with the reason when it is not
 * there *)
val mtime : string -> int

(* a new directory; a file, or a directory that is empty, removed.
 * Failure with the reason *)
val mkdir : < Cap.open_out; .. > -> string -> unit
val remove : < Cap.open_out; .. > -> string -> unit

(* [link caps old new]: a second name for a file (not a directory).
 * Failure with the reason *)
val link : < Cap.open_out; .. > -> string -> string -> unit

(* [rename caps from to]: the file, or the directory, under another
 * name. Failure with the reason *)
val rename : < Cap.open_out; .. > -> string -> string -> unit

(* whether a file is a program to run, its x bit for its owner; [set_executable
 * caps file x]: its bit set, or cleared (tiny-kernel has no modes: no
 * file is one there, and the call does nothing) *)
val is_executable : string -> bool
val set_executable : < Cap.open_out; .. > -> string -> bool -> unit

(* a file that is there written now, as far as its time says; one that
 * is not there made, empty. Failure with the reason *)
val touch : < Cap.open_out; .. > -> string -> unit

(* the directory the process is in *)
val getcwd : < Cap.readdir; .. > -> string

(* the date, in seconds since 2000-01-01 UTC, on both sides: a 31-bit
 * integer of tiny-ml's holds them until 2034, where 1970's would not
 * fit (old: Unix's seconds on the host, 0 on tiny-kernel, which had no
 * clock of the day) *)
val time : unit -> int

(* nothing done for so many milliseconds *)
val sleep : int -> unit

(* a clock in milliseconds, from some start (the boot on tiny-kernel, 2.5
 * at a time, its ticks): for a time taken, the difference of two *)
val millis : unit -> int

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

(* the next child to end, and its status as wait's; None when there is
 * no child *)
val wait_any : < Cap.wait; .. > -> (int * string) option

(* [shell caps vars script]: a child that runs script by the system's
 * shell, vars among its variables (each a list of words), what was
 * printed flushed first; its pid. The
 * script is in that shell's language: the host's sh -e, tiny-kernel's
 * rc -e (there in a file, an argument having 64 bytes at most, which
 * rc reads whole and removes first; no environment: vars are rc's
 * assignments before it) *)
val shell :
  < Cap.fork; Cap.exec; Cap.env; Cap.open_out; .. > ->
  (string * string list) list -> string -> int

(* the end of this process, at once: nothing flushed *)
val exit : int -> 'a
