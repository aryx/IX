(* The arch's side of the system calls and notes (principia's
 * syscalls/arm/syscall.c): a call's number in R0 (principia's
 * numbering, sys.h), its arguments on the user's stack from sp+4 (5c's
 * stubs: MOVW R0, 0(FP); SWI $0), its result in R0 (a failure's -1,
 * errstr saying why), the call itself Systab's. And the notes'
 * delivery: notify (to the handler, on arm's NFrame below the user's
 * sp) and noted's return from it.
 *
 * A call, n = pread(fd, buf, 100, -1):
 *
 *     libc's pread, four instructions        the user's stack at SWI
 *       MOVW R0, 0(FP)   the first argument   sp+4   fd
 *       MOVW $10, R0     PREAD                sp+8   buf
 *       SWI  $0          the trap             sp+12  100
 *       RET                                   sp+16  -1  the offset,
 *                                             sp+20  -1  low then high
 *     here: the number from the frame's R0, 20 bytes read at sp+4
 *     (five words, whatever the call takes), Systab.call, and the
 *     result in the frame's R0. An Error on the way: the message kept
 *     for errstr, and -1.
 *
 * The kernel never returns a pointer to its own memory nor takes one
 * on trust: an argument that is an address is the user's, read and
 * written through Usermem, which checks it.
 *
 * A note is delivered on the way back to user mode, after a call or
 * an interrupt, never in the middle of the kernel's work (a sleeping
 * call is first made to fail: Proc's eintr). The kernel then makes
 * the program call its handler, as if it had done so itself: 216
 * bytes pushed below the user's sp, and the registers changed.
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
 * The handler runs as any function of the program, on its stack,
 * with the registers of the interrupted code laid out for it to
 * read or change. noted(NCONT) is a system call like another, whose
 * return puts those 18 words back instead of its own: the program
 * goes on where the note found it. A handler's address or stack
 * that is not the process's ends it ("suicide").
 *
 * others:
 * Linux on arm takes the number in R7 and the arguments in R0 to R6,
 * registers rather than the stack, and returns a negative errno in
 * R0 where this returns -1 and keeps a string (Errors). Unix's
 * signals are delivered as the notes are here, by a frame on the
 * user's stack and a call, sigreturn, to come back; a signal's
 * frame has in it besides the mask of the signals held meanwhile,
 * which notes have no notion of.
 *
 * cs-history:
 * A trap instruction with the call's number is how programs have
 * asked a supervisor for service since the 1960s; the name SWI,
 * software interrupt, is ARM's (1985), later written SVC. What
 * has not changed is that it costs: a call saves all the registers
 * and changes stacks before the first line of OCaml runs, and that
 * price is why read takes a buffer and not a byte.
 *
 * References: principia's Kernel.nw and Kernel_arm.nw (syscall.c,
 * notify, noted). notify(2) in the Plan 9 manual, for the handler's
 * side. principia's lib_core (libc/9syscall's mkfile), which writes
 * the stubs. *)

open Types

(* the running process's system call, from its trap frame *)
val syscall : proc -> unit

(* a pending note delivered on the way back to user mode (notify: to
 * the handler, or the process's end), the trap frame's type (a Ureg's:
 * the processor mode trapped to) *)
val notify : proc -> int -> unit

(* a trap's note (NDebug: "text pid: suicide: msg" when not handled),
 * delivered at once *)
val trap : proc -> string -> int -> unit

(* each call printed on the console (debugging) *)
val trace : bool ref

(* after a "suicide" line, a line more: the process's lr, sp, and its
 * stack's addresses of code (who called); false: 9pi's words alone *)
val traced : bool ref
