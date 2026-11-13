(* '#d' shows the descriptors as files (principia's devdup.c). For each
 * open descriptor N there are two files: N, which when opened gives the
 * descriptor's channel again, and Nctl, which holds its offset and name.
 * It is rc's /fd, and rcmain reads '#d/0'.
 *
 * It is how a program that only takes file names is given a
 * descriptor: cat /fd/0 reads its standard input, and a command
 * that wants two inputs can have pipes for both, by name. Like #e,
 * the device has no tree: the directory is the calling process's
 * table of descriptors, read at each call.
 *
 * cs-history:
 * /dev/fd is from the eighth edition of Unix; on today's systems it is
 * /dev/stdin and /proc/self/fd. It is a small thing that shows a larger
 * one: once the kernel's tables have names, programs need no option of
 * their own for them (such as the dash that means standard input, in
 * each command that thought of it). *)

(* registers the device *)
val init : unit -> unit
