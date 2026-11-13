(* TinyKernel's reads and writes: what each kind of file behind a
 * descriptor does with n bytes at an address in the kernel's memory.
 * The kinds are a node, a pipe's end, the console, a connection to the
 * screen, a box, a network link, a call, an audio voice, and a trace.
 * Each read or write answers at once. Some n means n bytes were done;
 * None means the call must wait: KCalls then makes the process Waiting,
 * and the scheduler tries the call again later.
 *
 *     read f a n   Some 0      end of file (a pipe with no writer left)
 *                  Some k      k bytes were put at a
 *                  Some (-1)   an error
 *                  None        nothing yet: try again later
 *
 * A trace is a file too (plan_tiny_debugger.md). The tracer writes
 * commands to it (set a breakpoint, show the registers, step) and reads
 * from it why the process stopped.
 *
 * plan9-is-cleaner:
 * There is one read and one write for every kind of file, including
 * the devices and the debugger's view of a process. Plan 9 likewise
 * controls a process by writing to and reading from /proc/n/ctl, where
 * Unix has ptrace with calls of its own.
 *)

(* [typed] is console input not read yet. [raw] is the pid that put the
 * console in raw mode (rawcons), or 0; [raw_on] says whether that
 * process is alive. *)
val typed : string ref
val typed_end : bool ref
val raw : int ref
val raw_on : unit -> bool

(* [read f a n] reads up to n bytes to the kernel's address a. *)
val read : KFiles.file -> int -> int -> int option

(* [net_command n cmd] gives the network device a command on n bytes in
 * the buffer: cmd 1 sends them, and cmd 2 takes them. *)
val net_command : int -> int -> unit
val net_send : string -> unit

(* [pause p line] stops p and sends line to its tracer; [stop p why]
 * also gives p's pc. *)
val traced : KProcs.proc -> bool
val pause : KProcs.proc -> string -> unit
val stop : KProcs.proc -> string -> unit

(* [write f a n] writes the n bytes at the kernel's address a. *)
val write : KFiles.file -> int -> int -> int option

(* [readable f] says whether a read of the file would not wait. *)
val readable : KFiles.file -> bool
