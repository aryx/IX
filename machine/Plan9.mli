(* The Plan 9 process a program starts as, and its system calls: 5i's
 * personality (plan_arm.md, phase 8), for the a.out goken's and ix's
 * linkers write with -H2, run by the arm32 core.
 *
 * The a.out: a 32-byte big-endian header (magic 0x647, arm's; the text,
 * data and bss sizes, the entry), the text loaded with its header at
 * 0x1000, the data on the next page, the bss after it. The stack below
 * 0x80000000, as 5i's initstk lays it out: the Tos at its top (r0
 * points at it), then argc (argv[0] counted), argv, nil.
 *
 * A system call: `svc 0`, its number in r0 (principia's sys.h), the
 * arguments on the stack from sp+4 (where 5c's calling convention has
 * put them already), the result in r0; an error returns -1 and leaves
 * its text in the process's error string (errstr exchanges it).
 *
 * Plan 9 reaches much of the system through files, not calls: the few
 * the libc opens are the emulator's own (#c/pid, /dev/bintime,
 * /env/NAME, /proc/PID/note), the rest the host's. Directories read as
 * 9P stat records; notes (a posted one, or the host's SIGALRM as
 * "alarm") are delivered as principia's kernel delivers them, a Ureg
 * and the note's text on the stack and the notify() handler called,
 * noted(NCONT) putting the Ureg back. A child's exit string reaches
 * its parent's await through a pipe the fork made.
 *
 * Where it stands: the a.out is the linker's Exe's (its header
 * draws the 32 bytes), the calls are the ones mini-9pi's kernel
 * answers on the board, by the same numbers; a program linked -H2
 * so runs three ways, here on the host's files, in mini-qemu under
 * the kernel, and on a Pi. Linux is the sister module, another
 * system's calls over the same Host_calls.
 *
 * plan9-is-cleaner:
 * The table of calls has forty numbers, errstr the last, where
 * Linux's has several hundred, and not because Plan 9 does less:
 * what Unix adds a call for, Plan 9 puts in a file. The time is
 * /dev/bintime read, the process's id #c/pid, a variable of the
 * environment the file /env/NAME, and a signal sent is a string
 * written to /proc/PID/note. So this module, to play a kernel,
 * must play a few files as well as the calls; and the calls it has
 * are the ones that work on any file: open, pread, pwrite, close,
 * stat.
 *
 * plan9-is-cleaner:
 * Errors and endings are strings. A failed call returns -1 and the
 * reason is text, "file does not exist", that the program prints
 * as it is; Unix returns a number, errno, and each program carries
 * the table that turns 2 into a sentence. A process ends with a
 * string too (exits), empty for success, and a note is the text of
 * what happened ("interrupt", "alarm") where a signal is a number
 * from a fixed list. This module's tables from the host's errnos
 * and signals to those strings are the size of the difference. *)

type aout = { text : int; data : int; bss : int; entry : int }

(* the header, when the file is an arm Plan 9 a.out *)
val parse : string -> aout option

type proc

(* the process, the entry, the initial sp, the Tos (r0) *)
val load : Host_calls.t -> Memory.t -> aout -> string -> string list -> string list -> proc * int * int * int

(* each call logged to standard error by name (-y) *)
val log_calls : bool ref

val syscall : proc -> Arm32_isa.state -> unit

(* the pending notes delivered at [pc], the next instruction *)
val deliver : proc -> Arm32_isa.state -> pc:int -> unit
