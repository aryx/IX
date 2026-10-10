(* '#d', the descriptors as files (principia's devdup.c): for each
 * open descriptor N, N (opening it: the descriptor's channel again) and
 * Nctl (its offset and name). rc's /fd, and rcmain's '#d/0'.
 *
 * It is how a program that only takes file names is given a
 * descriptor: cat /fd/0 reads its standard input, and a command
 * that wants two inputs can have pipes for both, by name. Like #e,
 * the device has no tree: the directory is the calling process's
 * table of descriptors, read at each call.
 *
 * cs-history:
 * /dev/fd is from the eighth edition of Unix (from memory), and is
 * /dev/stdin and /proc/self/fd on today's systems. It is a small
 * thing that shows the larger one: once the kernel's tables have
 * names, programs need no option of their own for them (the dash
 * that means standard input, in each command that thought of it). *)

(* the device registered *)
val init : unit -> unit
