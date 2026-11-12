(* The system interface for tools that run on two systems, the host and
 * tiny-machine: the shell, the utilities, the compilers, the assembler
 * and the linker, the build system, the version control, the database,
 * the line editor and the profiler. Such a tool's files use only this
 * module and the pure functions of the standard library. There are two
 * implementations of this interface, next to it:
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
 * So the interface is what both systems can give, which means what the
 * smaller one, tiny-kernel, gives:
 * - a descriptor is a number;
 * - a call that fails raises Failure with the reason (on the host,
 *   the system's message; tiny-kernel has no reason to give);
 * - a child's status is already a string, as rc shows it.
 * What tiny-kernel lacks is simply not offered: there is no
 * environment except a PATH, no signal, and no terminal to query.
 *
 * m-ix has the same seam one level lower. Its tools (mini-rc,
 * mini-cat...) stand on lib_core (Cap, FS, Procs) over OCaml's Unix,
 * and lib_core/system/ implements that Unix twice, with Linux's system
 * calls and with Plan 9's (TinyLibSystem/plan9/), so one tool runs on
 * Linux and on mini-9pi. Here the seam is the tools' own interface, cut
 * down to what tiny-kernel gives, so that a tool cannot ask the host
 * for something the other system lacks.
 *
 * The capabilities matter on the host: there, a function that reaches
 * the system takes the object that allows it, and OCaml checks it.
 * tiny-ml reads the capability types and ignores them.
 *
 * A file's name is an Fpath.t, not a string. A tool decides once where
 * a word becomes a path, and the empty word is refused at that point
 * (Fpath.v "" raises) instead of being given to the system as a name.
 * The names in a directory (readdir) are segments, plain strings.
 *
 * design:
 * Why a module of its own, and not Sys.ml and Unix.ml in TinyLibCore/
 * next to List.ml and Hashtbl.ml? TinyLibCore is a subset of OCaml's
 * own modules, with the same names, types and results, so that a file
 * using List compiles unchanged by OCaml on the host and by tiny-ml on
 * TinyLibCore. That works because those modules are pure: one file
 * serves tiny-kernel, and OCaml's own serves the host. The system
 * cannot be split that way. On the host it is Unix, Cap, FS and Procs;
 * on tiny-kernel it is the kernel's calls. A TinyLibCore Unix.ml would
 * have to be a subset of OCaml's Unix, an interface far larger than
 * what tiny-kernel gives, built on strings and Unix_error, without
 * capabilities or Fpath.t. So this is a new interface, cut to the
 * smaller system, with one .mli and one implementation per system (a
 * virtual library in dune: TinyLibSystem/).
 * The other road, subsets of Sys and Unix, would let the tools use the
 * names OCaml programmers know, and a tool asking for a name that
 * tiny-kernel lacks would fail to compile there. But a tool relying on
 * what tiny-kernel can only fake would still compile: a stat's 12
 * fields of which it has 4, Unix_error's codes where it gives no
 * reason, an emulated dup2 or wait for one child. Here a type promises
 * only what both systems give. And a clean slate lets the interface be
 * the tools' own: a path is an Fpath.t, not a string; a function that
 * reaches the system takes the capability that allows it; and the
 * system is one module, not split between Sys and Unix as in OCaml.
 *)

(*****************************************************************************)
(* System types *)
(*****************************************************************************)

type pid = int

(* A file descriptor is a number. OCaml hides it (Unix.file_descr is
 * abstract: on Windows it is a handle), and most programs use channels.
 * Here tiny-kernel's calls take the number, and on the host it is
 * Unix's own (unix/'s fd, through Obj.magic). Tools need the number:
 * the shell's plumbing (dup2, pipe), where rc's >[2=1] names 2 and 1
 * and a child finds its input at 0, and a file read at offsets
 * (tiny-db's). A file read whole or piece by piece uses a channel
 * (with_open_in), as in OCaml. The cost: the type checker does not
 * catch an fd passed where a count was meant. *)
type fd = int

(* As rc shows it: "" for success, else the exit code, or "signal: "
 * and the signal's name. *)
type status = string

(* The st_ prefix is Unix's: tiny-ml's labels share one name space. *)
type stat = { st_dir : bool; st_size : int }

(* A date is in seconds since 2000-01-01 UTC. *)
type seconds = int
type milliseconds = int

(*****************************************************************************)
(* main() and other initialization helpers *)
(*****************************************************************************)

(* [main name f] calls f with every capability and the arguments (name
 * first). For Err msg, or a Failure that escapes f, msg is printed after
 * name and the status is 1; for Code n, or ExitCode n raised, it is n.
 * name also prefixes the host's logs. Host-only programs (tiny-cpu,
 * tiny-machine, tiny-mkfat, Mkfont) use it too, to print errors alike. *)
val main : string -> (Cap.all_caps -> string array -> Exit.t) -> unit

(* [logging args] removes -v, -debug and -quiet from args and sets Logs'
 * level from them (info, debug, none; warnings by default), as m-ix's
 * Logging.flags does. It is not done for every program, since grep has
 * its own -v. Messages go to stderr after the name given to [main]. *)
val logging : string list -> string list

val environment : < Cap.env; .. > -> (string * string) list
val getpid : < Cap.env; .. > -> pid

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

(* [print] is buffered until [flush]; [eprint] writes at once. *)
val print : < Cap.stdout; .. > -> string -> unit
val eprint : < Cap.stderr; .. > -> string -> unit
val flush : < Cap.stdout; Cap.stderr; .. > -> unit

(* A line without its newline; None at the end of the input. *)
val read_line : < Cap.stdin; .. > -> string option

val isatty : fd -> bool

(* From now on, an interrupt typed is for the program run, not this one. *)
val ignore_interrupt : < Cap.signal; .. > -> unit

(* In raw mode each key comes as typed, and ^C is a key, not an
 * interrupt: what an editor or a game wants. *)
val raw_console : < Cap.keyboard; .. > -> bool -> unit

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* The functions on files raise Failure with the reason, unless said
 * otherwise. open_out creates or empties the file. *)
val open_in : < Cap.open_in; .. > -> Fpath.t -> fd
val open_out : < Cap.open_out; .. > -> Fpath.t -> fd
val open_append : < Cap.open_out; .. > -> Fpath.t -> fd
val close : fd -> unit

(* To read and write anywhere (a database's file); creates it if needed. *)
val open_rw : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> fd

(* [seek fd off] is from the file's start. [seek_end] returns the end's
 * offset. *)
val seek : fd -> int -> unit
val seek_end : fd -> int

val read_file : < Cap.open_in; .. > -> Fpath.t -> string
val write_file : < Cap.open_out; .. > -> Fpath.t -> string -> unit

(* [with_open_in caps f file] closes the channel when f returns or
 * raises. A failed open's Failure gives the file and the reason on both
 * systems ("f: No such file or directory", "f: cannot open"), as
 * FS.with_open_in's Sys_error does on the host. *)
val with_open_in : < Cap.open_in; .. > -> (Chan.i -> 'a) -> Fpath.t -> 'a

(* with_open_out creates or empties the file; with_open_append adds. *)
val with_open_out :
  < Cap.open_out; .. > -> (Chan.o -> 'a) -> Fpath.t -> 'a
val with_open_append :
  < Cap.open_out; .. > -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* Do not mix with read_line, which keeps what it read past a line. *)
val stdin : < Cap.stdin; .. > -> Chan.i

(* [readdir] is in no particular order, and [] when it cannot read. *)
val readdir : < Cap.readdir; .. > -> Fpath.t -> string list
val is_directory : < Cap.readdir; .. > -> Fpath.t -> bool

val chdir : < Cap.chdir; .. > -> Fpath.t -> unit
val stat : < Cap.open_in; .. > -> Fpath.t -> stat
val exists : < Cap.open_in; .. > -> Fpath.t -> bool

(* How many names (hard links) the file has. *)
val links : < Cap.open_in; .. > -> Fpath.t -> int

(* The last write; 0 for the boot image's files on tiny-kernel. *)
val mtime : < Cap.open_in; .. > -> Fpath.t -> seconds

(* [remove] removes a file or an empty directory. *)
val mkdir : < Cap.open_out; .. > -> Fpath.t -> unit
val remove : < Cap.open_out; .. > -> Fpath.t -> unit

(* [link caps old new]: not for a directory. *)
val link : < Cap.open_out; .. > -> Fpath.t -> Fpath.t -> unit
val rename : < Cap.open_out; .. > -> Fpath.t -> Fpath.t -> unit

(* By the owner's x bit. tiny-kernel has no modes: there no file is
 * executable, and set_executable does nothing. *)
val is_executable : < Cap.open_in; .. > -> Fpath.t -> bool
val set_executable : < Cap.open_out; .. > -> Fpath.t -> bool -> unit

(* Sets an existing file's time to now, or creates it empty. *)
val touch : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> unit

val getcwd : < Cap.env; .. > -> Fpath.t

(*****************************************************************************)
(* Time *)
(*****************************************************************************)

(* From 2000 on both systems: tiny-ml's 31-bit integers hold seconds
 * since 2000 until 2034, but seconds since 1970 would not fit. *)
val time : < Cap.clock; .. > -> seconds

val sleep : < Cap.clock; .. > -> milliseconds -> unit

(* For durations, from some start (the boot on tiny-kernel, by ticks of
 * 2.5 ms). *)
val millis : < Cap.clock; .. > -> milliseconds

(* The machine's seed, or the clock when there is none. *)
val seed : < Cap.random; .. > -> int

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

(* fd_stdin is a window's keys. fd_draw takes drawing messages (see
 * KGraphics.mli); fd_mouse is a box of x, y and the buttons, a word
 * each, low byte first. Both come from a window, tiny-kernel's or the
 * host's (TinyLibSystem/sdl/); without one they are not open. *)
val fd_stdin : fd
val fd_stdout : fd
val fd_stderr : fd
val fd_draw : fd
val fd_mouse : fd

(* [ready fds until] returns the first of fds readable without waiting,
 * or None once [millis] reaches until (never without one). This is a
 * window's loop: a key, the mouse, the wire, or the next frame. *)
val ready : fd list -> milliseconds option -> fd option

(* [read fd max] does not wait for more than what comes next, as cat at
 * the console needs; "" at the end. *)
val read : fd -> int -> string

val read_all : fd -> string
val write : fd -> string -> unit

(* [save n] copies n away from the low numbers, not passed on to
 * programs run; None when n is not open. *)
val save : fd -> fd option

val dup2 : fd -> fd -> unit

(* The read end and the write end, not passed on to programs run. *)
val pipe : < Cap.pipe; .. > -> fd * fd

(* On tiny-kernel only: a pipe that keeps only what was last written,
 * read once, like the mouse on 4 (tiny-windows gives each window one). *)
val box : < Cap.pipe; .. > -> fd * fd

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* None in the child. Raises Failure when it cannot ("try again" on
 * tiny-kernel, all process slots taken). *)
val fork : < Cap.fork; .. > -> pid option

(* SIGKILL on the host; false when there is no such process, or it is
 * not ours to end. *)
val kill : < Cap.kill; .. > -> pid -> bool

(* [exec caps file argv env], env as name=value, returns only when it
 * fails, with the reason (always "not found" on tiny-kernel). *)
val exec :
  < Cap.exec; .. > -> Fpath.t -> string list -> string list -> string

(* For no such child the host raises Unix's error; tiny-kernel returns
 * "", a success. *)
val wait : < Cap.wait; .. > -> pid -> status

(* None when there is no child. *)
val wait_any : < Cap.wait; .. > -> (pid * status) option

(* [shell caps vars script] flushes, then starts rc -e on script with
 * vars (lists of words) set. On the host rc is tiny-shell from the
 * PATH, and vars go in its environment. On tiny-kernel, rc is /bin/rc,
 * vars become assignments, and the script goes in a file (an argument
 * has 64 bytes at most), which rc reads whole and removes first. *)
val shell :
  < Cap.fork; Cap.exec; Cap.env; Cap.open_out; Cap.stdout; Cap.stderr; .. > ->
  (string * string list) list -> string -> pid option

(* [spawn caps file argv] (argv with the name first) copies nothing of
 * this process, whereas fork copies it whole; it does not wait. The
 * browser's player and pager use it. *)
val spawn : < Cap.fork; Cap.exec; .. > -> Fpath.t -> string list -> pid option

(* Nothing is flushed. For Err msg, msg is printed on stderr first. *)
val exit : < Cap.exit; Cap.stderr; .. > -> Exit.t -> 'a

(*****************************************************************************)
(* The network *)
(*****************************************************************************)

(* Raises Failure. On the host it works only in a window, which plays
 * the wire's other end (port 70 of 10.0.0.1, a web page or a picture)
 * as tiny-machine does. *)
val dial : < Cap.network; .. > -> string -> int -> fd
