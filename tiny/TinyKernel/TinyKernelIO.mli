(* TinyKernel's reads and writes: what a descriptor's file does with n
 * bytes at a kernel's address, for each kind of file (a node, a pipe's
 * end, the console, a connection to the screen, a box, a link, a call,
 * a voice, a trace). Each answers at once, Some n done, or None: it
 * must wait, and TinyKernelCalls makes the call a Waiting process,
 * tried again by the scheduler.
 *
 *     read f a n   Some 0      the end (a pipe with no writer left)
 *                  Some k      k bytes put at a
 *                  Some (-1)   an error
 *                  None        nothing yet: try again later
 *
 * A trace is a file too (plan_tiny_debugger.md): its tracer writes
 * commands to it (a breakpoint, the registers, a step) and reads why
 * the process stopped.
 *
 * plan9-is-cleaner:
 * one read and one write for every kind of file, the devices and the
 * debugger's process included, as Plan 9's /proc/n/ctl is written to
 * and read from where Unix has ptrace's calls.
 *)

(* the console's input, typed and not yet read, and its end; the process
 * that has the console raw (rawcons), or 0, and whether it is alive *)
val typed : string ref
val typed_end : bool ref
val raw : int ref
val raw_on : unit -> bool

(* [read f a n]: up to n bytes of the file at the kernel's address a *)
val read : TinyKernelFiles.file -> int -> int -> int option

(* the network device's command (1 send, 2 take) on n bytes at its
 * buffer; a packet sent to the wire *)
val net_command : int -> int -> unit
val net_send : string -> unit

(* whether a process is traced; [pause p line]: it stopped, the line
 * said to its tracer; [stop p why]: the same, at its pc *)
val traced : TinyKernelProcs.proc -> bool
val pause : TinyKernelProcs.proc -> string -> unit
val stop : TinyKernelProcs.proc -> string -> unit

(* [write f a n]: n bytes at the kernel's address a written to the file *)
val write : TinyKernelFiles.file -> int -> int -> int option

(* whether a read would not wait *)
val readable : TinyKernelFiles.file -> bool
