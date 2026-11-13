(* In_channel: a subset of OCaml's (4.14) module (see Stdlib.mli), for
 * reading a channel. A channel is a descriptor of tiny-kernel's, read
 * by tiny-kernel's call (mlsys.c's u_read, which TinyLibSystem uses
 * too). A program that does not read a channel, such as one on tiny-cpu,
 * which has no files, does not name that call, and the link leaves it
 * out. TinyLibSystem.with_open_in opens a channel, as a Chan.i. *)
type t = in_channel

(* [input_all] reads what is left of the channel, up to its end *)
val input_all : t -> string

(* [input ic buf pos len] reads what the channel gives next, up to len
 * bytes, into buf at pos, without waiting for more. It returns how many
 * bytes it read, and 0 at the end. It is for reading a file a piece at
 * a time, or the console's input as it comes. *)
val input : t -> bytes -> int -> int -> int
