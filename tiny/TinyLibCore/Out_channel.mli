(* Out_channel: a subset of OCaml's (4.14) module (see Stdlib.mli), for
 * writing to a channel. A channel is a descriptor of tiny-kernel's,
 * written at once by tiny-kernel's call (mlsys.c's u_write). There is
 * no buffer of ours, so there is nothing to flush. As with In_channel's
 * read, a program that does not write to a channel does not name the
 * call. TinyLibSystem.with_open_out opens a channel, as a Chan.o. *)
type t = out_channel

(* [output_string] writes all of the string; it raises Failure when the
 * kernel refuses (where OCaml raises Sys_error) *)
val output_string : t -> string -> unit
