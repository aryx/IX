(* mini-ld -m 5|7 [-H2|-H6|-H7] [-nofollow] [-E entry] [-o out] files...
 * mini-ld -m 5|7 -a lib.a objects...  (a library)
 * -nofollow: the code in the objects' order, not along its flow as 5l
 * and 7l lay it out (Follow): the same behavior, not goken's
 * bytes. *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
