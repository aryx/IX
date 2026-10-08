(* Plan 9's error(): the kernel's work abandoned, the system call
 * failing with the message (errstr); and principia's error strings
 * (kernel/core/error.c). *)

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
