(* Plan 9's error(): the kernel's work abandoned, the system call
 * failing with the message (errstr); and principia's error strings
 * (kernel/core/error.c).
 *
 *     open("/nofile", OREAD)
 *       Kchan.namec: the root's device has no such name
 *         raise (Error "'/nofile' file does not exist")  (nameerror)
 *       ... no one between catches it ...
 *       Syscall.syscall: p.errstr <- the message; R0 <- -1
 *     the program: open returned -1; errstr(buf, n) reads the message,
 *     which is what its %r prints
 *
 * Whatever the kernel was doing for the call is given up where it
 * was: a function that holds something to give back catches the
 * exception, gives it back and raises again (Sysfile's sysopen closes
 * the channel when no descriptor is free).
 *
 * design:
 * Exceptions, in a kernel written in C. Plan 9's kernel has them by
 * hand: error(msg) is a longjmp to the last waserror() of the
 * process, a setjmp whose buffers are a stack in the Proc, and each
 * function with something to release writes if(waserror()){ release;
 * nexterror(); } ... poperror(). Forgetting a poperror is a bug the
 * compiler cannot see. Here it is the language's own try and raise,
 * and Errors.ml is fifty lines.
 *
 * plan9-is-cleaner:
 * An error is a string, not a number. Unix's errno is one of a fixed
 * list (ENOENT 2, EACCES 13...) that every program and every kernel
 * must agree on, and that a new kind of failure has no number in. A
 * string needs no agreement: a file server, which is any program,
 * answers a request with Rerror and its own words, Devmnt raises them
 * as they are, and the user reads what the server said ("file does
 * not exist", or a database's own complaint) through a kernel that
 * never knew the error. The strings below are only the kernel's own. *)

(* Plan 9's error(): the kernel's work abandoned, the system call
 * failing with the message (errstr) *)
exception Error of string

(* principia's error strings (kernel/core/error.c) *)
val enonexist : string
val ebadsharp : string
val enotdir : string
val eisdir : string
val eperm : string
val ebadusefd : string
val ebadarg : string
val ebadfd : string
val enofd : string
val ebadexec : string
val enovmem : string
val esoverlap : string
val enegoff : string
val egreg : string
val eexist : string
val enocreate : string
val eunmount : string
val eismtpt : string
val enochild : string
val ehungup : string
val edirseek : string
val eisstream : string
val eshortstat : string
val ebadstat : string
val einuse : string
val ebadctl : string

(* Plan 9's nameerror: "'name' error" *)
val nameerror : string -> string -> 'a
