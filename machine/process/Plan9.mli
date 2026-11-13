(* The Plan 9 process that a program starts as, and its system calls.
 * It is 5i's personality (plan_arm.md, phase 8), for the a.out that
 * goken's and ix's linkers write with -H2, run by the arm32 core.
 *
 * The a.out has a 32-byte big-endian header, with the magic (0x647,
 * arm's), the text, data and bss sizes, and the entry. The text is
 * loaded with its header at 0x1000, the data on the next page, and the
 * bss after it. The stack is below 0x80000000, laid out as 5i's
 * initstk does: the Tos at its top (r0 points at it), then argc
 * (counting argv[0]), argv, and nil.
 *
 * A system call is `svc 0`, with its number in r0 (principia's sys.h),
 * the arguments on the stack from sp+4 (where 5c's calling convention
 * has already put them), and the result in r0. An error returns -1 and
 * leaves its text in the process's error string (errstr exchanges
 * it).
 *
 * Plan 9 reaches much of the system through files, not calls. The few
 * files the libc opens are the emulator's own (#c/pid, /dev/bintime,
 * /env/NAME, /proc/PID/note), and the rest are the host's. Directories
 * read as 9P stat records. Notes (a posted one, or the host's SIGALRM
 * as "alarm") are delivered as principia's kernel delivers them: a
 * Ureg and the note's text go on the stack, the notify() handler is
 * called, and noted(NCONT) puts the Ureg back. A child's exit string
 * reaches its parent's await through a pipe that the fork made.
 *
 * The segments a program attaches with segattach are segments of the
 * Memory. They are zeros, of class "memory" or "shared", and go below
 * the stack when no address is asked. segflush drops the processor's
 * decoded instructions (as a debugger's write does, with
 * Memory.code_written), so code that the program writes there, as a
 * JIT does, runs as written. Without it, the old instructions would
 * run, as they would from a real processor's instruction cache
 * (tests/plan9/seg.c shows both).
 *
 * Where it stands: the a.out is the one the linker's Exe writes (Exe's
 * header draws the 32 bytes), and the calls are the ones mini-9pi's
 * kernel answers on the board, with the same numbers. So a program
 * linked with -H2 runs three ways: here on the host's files, in
 * mini-qemu under the kernel, and on a Pi. Linux is the sister module,
 * with another system's calls over the same Host_calls.
 *
 * plan9-is-cleaner:
 * The table of calls has forty numbers, with errstr the last, where
 * Linux's has several hundred, and not because Plan 9 does less. What
 * Unix adds a call for, Plan 9 puts in a file. The time is read from
 * /dev/bintime, the process's id from #c/pid, and a variable of the
 * environment is the file /env/NAME; a signal is sent by writing a
 * string to /proc/PID/note. So to play a kernel, this module must play
 * a few files as well as the calls, and the calls it has are the ones
 * that work on any file: open, pread, pwrite, close, stat.
 *
 * plan9-is-cleaner:
 * Errors and endings are strings. A failed call returns -1, and the
 * reason is a text, such as "file does not exist", that the program
 * prints as it is. Unix returns a number, errno, and each program
 * carries the table that turns 2 into a sentence. A process ends with
 * a string too (exits), empty for success, and a note is the text of
 * what happened ("interrupt", "alarm"), where a signal is a number from
 * a fixed list. This module's tables, from the host's errnos and
 * signals to those strings, measure the difference. *)

type aout = { text : int; data : int; bss : int; entry : int }

(* the header, when the file is an arm Plan 9 a.out *)
val parse : string -> aout option

type proc

(* returns the process, the entry, the initial sp and the Tos (r0) *)
val load : Host_calls.t -> Memory.t -> aout -> string -> string list -> string list -> proc * int * int * int

(* logs each call to standard error by its name (-y) *)
val log_calls : bool ref

val syscall : proc -> Arm32_isa.state -> unit

(* delivers the pending notes at [pc], the next instruction *)
val deliver : proc -> Arm32_isa.state -> pc:int -> unit

(* arm's breakpoint instruction (5db's BKPT), and what it does at pc.
 * It posts the note "sys: breakpoint" and leaves the pc at the
 * breakpoint, so a traced process stops there for its debugger
 * (Proc9). *)
val breakpoint_instruction : int
val breakpoint : proc -> Arm32_isa.state -> pc:int -> unit
