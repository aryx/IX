(* The authentication's system calls (principia's security/auth.c):
 * - fauth opens an authentication file on a server's connection
 *   (devmnt's auth);
 * - fversion negotiates the connection's 9P version.
 *
 *     afd = fauth(fd, aname)     T Auth: a file of the server's
 *     ... read and write afd ... whatever the two ends agree to say
 *     mount(fd, afd, old, ...)   T Attach, with that file as proof
 *
 * (mini-9pi's mount attaches without that file, whatever afd is: see
 * Sysfile's sysmount.)
 *
 * plan9-is-cleaner:
 * The kernel carries the conversation and understands none of it. 9P
 * says only that there is a file to read and write before the attach.
 * Which protocol is spoken on it, and with which keys, is a matter
 * between the server and one of the user's programs (on Plan 9,
 * factotum, which holds the keys so that no other program does). A new
 * way to authenticate is then a change to two programs, and no secret
 * ever passes through this file's code.
 *
 * References: Russ Cox, Eric Grosse, Rob Pike, Dave Presotto and
 * Sean Quinlan, "Security in Plan 9" (USENIX Security 2002).
 * fauth(2) and attach(5) in the Plan 9 manual. *)

open Types

(* [sysfauth p fd aname] returns the authentication file's descriptor *)
val sysfauth : proc -> int -> string -> int
(* [sysfversion p fd msize buf n] negotiates the version that the user's
 * buffer holds *)
val sysfversion : proc -> int -> int -> int -> int -> int
