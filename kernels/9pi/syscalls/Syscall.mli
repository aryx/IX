(* The arch's side of the system calls and notes (principia's
 * syscalls/arm/syscall.c). A call's number is in R0 (with principia's
 * numbering, from sys.h), and its arguments are on the user's stack
 * from sp+4 (5c's stubs do MOVW R0, 0(FP); SWI $0). Its result goes in
 * R0 (-1 for a failure, with errstr saying why), and Systab makes the
 * call itself. This module also delivers the notes: notify goes to the
 * handler, on arm's NFrame below the user's sp, and noted returns from
 * it.
 *
 * Here is a call, n = pread(fd, buf, 100, -1):
 *
 *     libc's pread, four instructions        the user's stack at SWI
 *       MOVW R0, 0(FP)   the first argument   sp+4   fd
 *       MOVW $10, R0     PREAD                sp+8   buf
 *       SWI  $0          the trap             sp+12  100
 *       RET                                   sp+16  -1  the offset,
 *                                             sp+20  -1  low then high
 *     Here the kernel takes the number from the frame's R0, reads 20
 *     bytes at sp+4 (five words, whatever the call takes), calls
 *     Systab.call, and puts the result in the frame's R0. When an
 *     Error is raised on the way, the message is kept for errstr, and
 *     the result is -1.
 *
 * The kernel never returns a pointer to its own memory, nor takes one
 * on trust: an argument that is an address is the user's, and it is
 * read and written through Usermem, which checks it.
 *
 * A note is delivered on the way back to user mode, after a call or
 * an interrupt, never in the middle of the kernel's work (a sleeping
 * call is first made to fail, with Proc's eintr). The kernel then makes
 * the program call its handler, as if it had done so itself: it pushes
 * 216 bytes below the user's sp, and changes the registers.
 *
 *     sp' = sp - 216   0             no return: a handler ends by noted
 *     sp' + 4          sp' + 144     its first argument, the Ureg
 *     sp' + 8          sp' + 12      its second, the note
 *     sp' + 12         the note's text, 128 bytes (ERRMAX)
 *     sp' + 140        the frame of a handler before this one
 *     sp' + 144        the Ureg, 18 words: what the registers were
 *     sp               (r0-r12, sp, link, the trap's type, psr, pc)
 *
 *     then: pc = the handler (notify's), sp = sp', R0 = sp' + 144
 *
 * The handler runs as any function of the program does, on its stack,
 * with the registers of the interrupted code laid out for it to read
 * or change. noted(NCONT) is a system call like any other, but its
 * return puts those 18 words back instead of its own registers, so the
 * program goes on where the note found it. When the handler's address
 * or its stack is not the process's, the process ends ("suicide").
 *
 * others:
 * Linux on arm takes the number in R7 and the arguments in R0 to R6,
 * in registers rather than on the stack. It returns a negative errno
 * in R0, where this kernel returns -1 and keeps a string (Errors).
 * Unix's signals are delivered as the notes are here, by a frame on
 * the user's stack and a call, sigreturn, to come back. A signal's
 * frame also holds the mask of the signals held meanwhile, which notes
 * have no notion of.
 *
 * cs-history:
 * A trap instruction with the call's number is how programs have
 * asked a supervisor for service since the 1960s. The name SWI, for
 * software interrupt, is ARM's (1985), later written SVC. What has not
 * changed is that it costs: a call saves all the registers and changes
 * stacks before the first line of OCaml runs, and that price is why
 * read takes a buffer and not a byte.
 *
 * References: principia's Kernel.nw and Kernel_arm.nw (syscall.c,
 * notify, noted). notify(2) in the Plan 9 manual, for the handler's
 * side. principia's lib_core (libc/9syscall's mkfile), which writes
 * the stubs. *)

open Types

(* makes the running process's system call, from its trap frame *)
val syscall : proc -> unit

(* [notify p typ] delivers a pending note on the way back to user mode
 * (notify): it goes to the handler, or it ends the process. typ is the
 * trap frame's type (a Ureg's type: the processor mode trapped to). *)
val notify : proc -> int -> unit

(* delivers a trap's note at once (NDebug: it prints "text pid: suicide:
 * msg" when the note is not handled) *)
val trap : proc -> string -> int -> unit

(* when true, each call is printed on the console (for debugging) *)
val trace : bool ref

(* when true, a "suicide" line is followed by one more line: the
 * process's lr and sp, and the addresses of code on its stack (who
 * called). When false, only 9pi's words are printed. *)
val traced : bool ref
