(* In_channel, OCaml's (4.14) subset (see Stdlib.mli): what a channel
 * gives. A channel is a descriptor of tiny-kernel's, read by its call
 * (mlsys.c's u_read, TinyCalls' too): a program that does not read one,
 * on tiny-cpu which has no files, does not name that call, and the
 * link leaves it out. TinyLibSystem.with_open_in opens one, as a
 * Chan.i *)
type t = in_channel

(* what is left of the channel, to its end *)
val input_all : t -> string
