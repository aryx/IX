(* The authentication's system calls (principia's security/auth.c):
 * fauth (an authentication file on a server's connection: devmnt's
 * auth) and fversion (the connection's 9P version negotiated).
 *
 *     afd = fauth(fd, aname)     T Auth: a file of the server's
 *     ... read and write afd ... whatever the two ends agree to say
 *     mount(fd, afd, old, ...)   T Attach, with that file as proof
 *
 * (mini-9pi's mount attaches without one, whatever afd is: Sysfile's
 * sysmount.)
 *
 * plan9-is-cleaner:
 * The kernel carries the conversation and understands none of it.
 * 9P says only that there is a file to read and write before the
 * attach; which protocol is spoken on it, with which keys, is
 * between the server and a program of the user's (Plan 9's
 * factotum, which holds the keys so that no other program does).
 * A new way to authenticate is then a change to two programs, and
 * no secret ever passes through this file's code.
 *
 * References: Russ Cox, Eric Grosse, Rob Pike, Dave Presotto and
 * Sean Quinlan, "Security in Plan 9" (USENIX Security 2002).
 * fauth(2) and attach(5) in the Plan 9 manual. *)

open Types

(* [sysfauth p fd aname]: the authentication file's descriptor *)
val sysfauth : proc -> int -> string -> int
(* [sysfversion p fd msize buf n]: the version the user's buffer holds *)
val sysfversion : proc -> int -> int -> int -> int -> int
