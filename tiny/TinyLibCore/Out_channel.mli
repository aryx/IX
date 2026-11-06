(* Out_channel, OCaml's (4.14) subset (see Stdlib.mli): what goes to a
 * channel. A channel is a descriptor of tiny-kernel's, written by its
 * call at once (mlsys.c's u_write; no buffer of ours, so nothing to
 * flush): as In_channel's read, a program that does not write one does
 * not name the call. TinyLibSystem.with_open_out opens one, as a
 * Chan.o *)
type t = out_channel

(* all of the string; Failure when the kernel refuses (OCaml's
 * Sys_error) *)
val output_string : t -> string -> unit
