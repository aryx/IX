(* What a tool asks of the system it runs on, for a tool that runs on
 * two (the host and tiny-machine): the shell, the utilities, the
 * compilers, the assembler and the linker, the build system, the
 * version control, the database, the line editor, the profiler. Such a
 * tool's files name only this and the pure functions of the standard
 * library; there are two files of this, beside it:
 *
 *               TinyShell.ml, TinyUtilities.ml, ...
 *            ___________/        \___________
 *   on the host                        on tiny-machine
 *   unix/TinyLibSystem.ml, OCaml,      tinykernel/TinyLibSystem.ml,
 *   built by dune or mini-mk           built by tiny-ml,
 *                                      on TinyLibCore/
 *   over Unix, Cap, FS, Procs          over tiny-kernel's calls
 *   Linux, macOS                       tiny-kernel
 *
 * So the interface is what both systems can give, which is the
 * smaller one's, tiny-kernel's: a descriptor is a number, a call that
 * fails raises Failure with the reason (the host's has the system's
 * message, tiny-kernel's has no reason to give), a child's status is
 * already rc's string. What tiny-kernel has not is answered there by
 * nothing: no environment but a PATH, no signal, no terminal to ask
 * about.
 *
 * m-ix has the same seam one level lower: its tools (mini-rc,
 * mini-cat...) stand on lib_core (Cap, FS, Procs) over OCaml's Unix,
 * and lib_core/system/ has that Unix twice, by Linux's system calls
 * and by Plan 9's (TinyLibSystem/plan9/), so one tool runs on Linux and on
 * mini-9pi. Here the seam is the tools' own interface, cut to what
 * tiny-kernel gives, so that a tool cannot ask the host for what the
 * other system lacks.
 *
 * The capabilities are the host's: there, a function that reaches the
 * system takes the object that allows it, and OCaml checks it. tiny-ml
 * reads them and forgets them.
 *
 * A file's name is an Fpath.t, not a string: a tool decides where a
 * word becomes a path, once, and the empty word is refused there
 * (Fpath.v "" raises), where it went before as a name to the system
 * (old: strings, each tool's "" handled, or not, at each call). The
 * names a directory has (readdir) are segments, strings.
 *
 * design:
 * Why a module of its own, and not Sys.ml and Unix.ml in TinyLibCore/
 * beside List.ml and Hashtbl.ml: TinyLibCore is a subset of OCaml's
 * own modules, the same names, types and results, so that a file
 * naming List compiles unchanged by OCaml on the host and by tiny-ml
 * on TinyLibCore. That works because those modules are pure: one file
 * serves tiny-kernel, OCaml's own serves the host. The system cannot
 * be split that way: on the host it is Unix, Cap, FS and Procs, on
 * tiny-kernel its calls, and a TinyLibCore Unix.ml would have to be a
 * subset of OCaml's Unix, an interface far larger than tiny-kernel
 * gives, of strings and Unix_error, without the capabilities or
 * Fpath.t. So this is a new interface, cut to the smaller system's,
 * with one .mli and a file for each system (a virtual library in
 * dune: TinyLibSystem/). The other road, Sys and Unix subsets, would let
 * the tools use the names OCaml programmers know, and a tool asking
 * for a name tiny-kernel lacks would fail to compile there; but not a
 * tool relying on what tiny-kernel can only fake: a stats' 12 fields
 * of which it has 4, Unix_error's codes where it gives no reason, a
 * dup2 or a wait for one child emulated. Here a type promises only
 * what both systems give. And a clean slate lets the interface be the
 * tools' own: a path is an Fpath.t, not a string; a function that
 * reaches the system takes the capability that allows it; and the
 * system is one module, not OCaml's split of it between Sys and Unix.
 *)

(*****************************************************************************)
(* System types *)
(*****************************************************************************)

(* a process's number, the system's *)
type pid = int

(* A file's descriptor, a number too (0, 1, 2 the standard input,
 * output, error), where OCaml hides it: Unix.file_descr is abstract
 * (on Windows a descriptor is a handle, not a number), and most
 * programs use the buffered channels over it. Here both systems number
 * them: tiny-kernel's calls take the number, and on the host it is
 * Unix's own (unix/'s fd, by Obj.magic). And the tools that need a
 * descriptor need its number: the shell's plumbing (dup2, pipe), where
 * rc's >[2=1] names 2 and 1, and a child finds its input at 0 because
 * it is 0; a file read and written at offsets (tiny-db's). A file read
 * or written whole, or a piece at a time, is a channel instead
 * (with_open_in, with_open_out), as in OCaml. What the alias costs: an
 * fd is an int to the type checker, which does not catch one passed
 * where a count was meant. *)
type fd = int

(* how a child ended, as rc says it: "" when all went well, its code,
 * or "signal: " and the signal's name *)
type status = string

(* a file's kind and size, in bytes (st_, Unix's prefix: the labels
 * are one name space in tiny-ml) *)
type stat = { st_dir : bool; st_size : int }

(* the date, seconds since 2000-01-01 UTC; a time taken *)
type seconds = int
type milliseconds = int

(*****************************************************************************)
(* main() and other initialization helpers *)
(*****************************************************************************)

(* [main name f]: the program: f with every capability and its
 * arguments (its name first), its result how it ends: Err's words, or
 * a Failure's that f lets out, said after name, the status 1; Code n
 * (or ExitCode n raised), n. name is for the host's logs too. The
 * host-only programs (tiny-cpu, tiny-machine and its helpers, tiny-mkfs,
 * Mkfont) end by it too, for the same words said the same way *)
val main : string -> (Cap.all_caps -> string array -> Exit.t) -> unit

(* [logging args]: args without -v, -debug and -quiet, the level of
 * Logs' messages set by them (info, debug, none; warnings by default),
 * as m-ix's Logging.flags. A program that wants them calls it on its
 * arguments; it is not done for all of them, since grep has its own
 * -v. The messages go to stderr after the program's name (main's) *)
val logging : string list -> string list

(* the variables the program was started with, each with its value *)
val environment : < Cap.env; .. > -> (string * string) list
val getpid : < Cap.env; .. > -> pid

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

(* on the standard output, kept until flush; on the error's, at once *)
val print : < Cap.stdout; .. > -> string -> unit
val eprint : < Cap.stderr; .. > -> string -> unit
val flush : < Cap.stdout; Cap.stderr; .. > -> unit

(* a line of the standard input without its end; None at the input's end *)
val read_line : < Cap.stdin; .. > -> string option

(* whether a descriptor is a terminal, where someone types *)
val isatty : fd -> bool

(* an interrupt typed at the terminal is for the program that runs,
 * not for this one *)
val ignore_interrupt : < Cap.signal; .. > -> unit

(* [raw_console caps raw]: the terminal raw (each key as it is typed,
 * ^C a key, not an interrupt) or not: what an editor or a game wants of
 * its keys *)
val raw_console : < Cap.keyboard; .. > -> bool -> unit

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* a file's descriptor: to read it, to write it from nothing (made if
 * it is not there), to write at its end. Failure with the reason *)
val open_in : < Cap.open_in; .. > -> Fpath.t -> fd
val open_out : < Cap.open_out; .. > -> Fpath.t -> fd
val open_append : < Cap.open_out; .. > -> Fpath.t -> fd
val close : fd -> unit

(* a file's descriptor to read and write it, at any place (a database's
 * file); made empty when it is not there. Failure with the reason *)
val open_rw : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> fd

(* [seek fd off]: the next read or write at off from the file's start;
 * [seek_end fd]: at its end, which is the offset given *)
val seek : fd -> int -> unit
val seek_end : fd -> int

(* a file's text; Failure with the reason. [write_file caps file s]: the
 * file made s, created or emptied first *)
val read_file : < Cap.open_in; .. > -> Fpath.t -> string
val write_file : < Cap.open_out; .. > -> Fpath.t -> string -> unit

(* [with_open_in caps f file]: f on the file opened, a channel that
 * knows its name (In_channel.input_all reads it), closed when f
 * returns or raises; an open's Failure says the file and the reason,
 * on both systems ("f: No such file or directory", "f: cannot open"),
 * as FS.with_open_in's Sys_error on the host *)
val with_open_in : < Cap.open_in; .. > -> (Chan.i -> 'a) -> Fpath.t -> 'a

(* [with_open_out caps f file]: f on the file opened to write, from
 * nothing (made if it is not there), a channel that knows its name
 * (Out_channel.output_string writes it), closed when f returns or
 * raises; Failure with the reason *)
val with_open_out :
  < Cap.open_out; .. > -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* the same, to write at the file's end (made if it is not there) *)
val with_open_append :
  < Cap.open_out; .. > -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* the standard input as a channel (In_channel.input reads what comes;
 * not with read_line, which keeps what it read past a line) *)
val stdin : < Cap.stdin; .. > -> Chan.i

(* a directory's names, in no order; none when it cannot be read *)
val readdir : < Cap.readdir; .. > -> Fpath.t -> string list
val is_directory : < Cap.readdir; .. > -> Fpath.t -> bool

(* the current directory changed to dir; Failure with the reason *)
val chdir : < Cap.chdir; .. > -> Fpath.t -> unit

(* whether a file is a directory, and its size; Failure with the
 * reason when it is not there *)
val stat : < Cap.open_in; .. > -> Fpath.t -> stat

(* whether a file or a directory is there *)
val exists : < Cap.open_in; .. > -> Fpath.t -> bool

(* how many names a file has (its hard links); Failure with the reason
 * when it is not there *)
val links : < Cap.open_in; .. > -> Fpath.t -> int

(* the date of a file's last write (the image's files on tiny-kernel:
 * 0); Failure with the reason when it is not there *)
val mtime : < Cap.open_in; .. > -> Fpath.t -> seconds

(* a new directory; a file, or a directory that is empty, removed.
 * Failure with the reason *)
val mkdir : < Cap.open_out; .. > -> Fpath.t -> unit
val remove : < Cap.open_out; .. > -> Fpath.t -> unit

(* [link caps old new]: a second name for a file (not a directory).
 * Failure with the reason *)
val link : < Cap.open_out; .. > -> Fpath.t -> Fpath.t -> unit

(* [rename caps from to]: the file, or the directory, under another
 * name. Failure with the reason *)
val rename : < Cap.open_out; .. > -> Fpath.t -> Fpath.t -> unit

(* whether a file is a program to run, its x bit for its owner; [set_executable
 * caps file x]: its bit set, or cleared (tiny-kernel has no modes: no
 * file is one there, and the call does nothing) *)
val is_executable : < Cap.open_in; .. > -> Fpath.t -> bool
val set_executable : < Cap.open_out; .. > -> Fpath.t -> bool -> unit

(* a file that is there written now, as far as its time says; one that
 * is not there made, empty. Failure with the reason *)
val touch : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> unit

(* the directory the process is in *)
val getcwd : < Cap.env; .. > -> Fpath.t

(*****************************************************************************)
(* Time *)
(*****************************************************************************)

(* the date, the same on both sides: a 31-bit integer of tiny-ml's
 * holds 2000's seconds until 2034, where 1970's would not fit (old:
 * Unix's seconds on the host, 0 on tiny-kernel, which had no clock of
 * the day) *)
val time : < Cap.clock; .. > -> seconds

(* nothing done for so long *)
val sleep : < Cap.clock; .. > -> milliseconds -> unit

(* a clock, from some start (the boot on tiny-kernel, 2.5 ms at a
 * time, its ticks): for a time taken, the difference of two *)
val millis : < Cap.clock; .. > -> milliseconds

(* a seed for a program's first random number: the machine's, or the
 * clock when it has none (a game's first piece) *)
val seed : < Cap.random; .. > -> int

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

(* A program's first descriptors: its input (a window's keys), its
 * output (the console), its errors, where it draws (the drawing
 * messages, TinyKernelGraphics.mli's), and its mouse (a box: x, y, the
 * buttons, a word each, the low bytes first). The last two are a
 * window's: tiny-kernel's, or the host's window (TinyLibSystem/sdl/);
 * on the host with no window they are not open, and a write there
 * fails *)
val fd_stdin : fd
val fd_stdout : fd
val fd_stderr : fd
val fd_draw : fd
val fd_mouse : fd

(* [ready fds until]: the first of fds that can be read without
 * waiting, waiting for one until the clock (millis's) is until, None
 * then; with no until, until one is ready. A window's loop: a key, the
 * mouse, the wire, or the next frame *)
val ready : fd list -> milliseconds option -> fd option

(* [read fd max]: what fd gives next, up to max bytes, without waiting
 * for more; "" at the end. For a program that must work on its input
 * as it comes (cat at the console) *)
val read : fd -> int -> string

(* all that a descriptor gives, to its end *)
val read_all : fd -> string

(* all of the string, written to the descriptor *)
val write : fd -> string -> unit

(* [save n]: a copy of descriptor n, away from the low numbers and not
 * given to a program run; None when n is not open *)
val save : fd -> fd option

(* [dup2 a b]: b is now what a is *)
val dup2 : fd -> fd -> unit

(* a pipe: where to read, where to write; not given to a program run *)
val pipe : < Cap.pipe; .. > -> fd * fd

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* a copy of this process: None in the copy, Some of the copy's pid
 * here; Failure when there can be none ("try again" on tiny-kernel,
 * its processes all taken; old: -1 there, an int for three answers) *)
val fork : < Cap.fork; .. > -> pid option

(* [kill caps pid]: that process ended at once (the host's SIGKILL);
 * false when there is none, or it is not ours to end *)
val kill : < Cap.kill; .. > -> pid -> bool

(* [exec caps file argv env]: this process becomes the program in file,
 * env its variables as name=value; when it cannot, the reason (the
 * host's the system's message; tiny-kernel's always "not found") *)
val exec :
  < Cap.exec; .. > -> Fpath.t -> string list -> string list -> string

(* a child's end; for no such child, the host's raises Unix's error,
 * tiny-kernel's says "", a success *)
val wait : < Cap.wait; .. > -> pid -> status

(* the next child to end, and how; None when there is no child *)
val wait_any : < Cap.wait; .. > -> (pid * status) option

(* [shell caps vars script]: a child that runs script by the system's
 * shell, vars among its variables (each a list of words), what was
 * printed flushed first; its pid, None when no child could be made
 * (old: -1). The
 * script is in that shell's language: the host's sh -e, tiny-kernel's
 * rc -e (there in a file, an argument having 64 bytes at most, which
 * rc reads whole and removes first; no environment: vars are rc's
 * assignments before it) *)
val shell :
  < Cap.fork; Cap.exec; Cap.env; Cap.open_out; Cap.stdout; Cap.stderr; .. > ->
  (string * string list) list -> string -> pid option

(* [spawn caps file argv]: a child running the program in file, argv
 * its arguments (its name first), not waited for: nothing of this
 * process copied, where fork and exec copy it whole; its pid, None when
 * it cannot (the browser's player and pager) *)
val spawn : < Cap.fork; Cap.exec; .. > -> Fpath.t -> string list -> pid option

(* the end of this process, at once: nothing flushed; Err's words said
 * first, on the standard error *)
val exit : < Cap.exit; Cap.stderr; .. > -> Exit.t -> 'a

(*****************************************************************************)
(* The network *)
(*****************************************************************************)

(* [dial caps address port]: a connection to a machine's port, its
 * descriptor; Failure when there is none. tiny-kernel's wire, and the
 * host's window, which answers the wire's other end (port 70 of
 * 10.0.0.1, a web page, a picture) as tiny-machine does; the host
 * without a window has no wire *)
val dial : < Cap.network; .. > -> string -> int -> fd
