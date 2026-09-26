(* The arch's side of the system calls and notes (principia's
 * syscalls/arm/syscall.c): a call's number in R0 (principia's
 * numbering, sys.h), its arguments on the user's stack from sp+4 (5c's
 * stubs: MOVW R0, 0(FP); SWI $0), its result in R0 (a failure's -1,
 * errstr saying why), the call itself Systab's. And the notes'
 * delivery: notify (to the handler, on arm's NFrame below the user's
 * sp) and noted's return from it. *)

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
