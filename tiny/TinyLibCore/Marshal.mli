(* Marshal, OCaml's subset (see Stdlib.mli): a value as bytes and back,
 * in OCaml's format, so that what the host's OCaml writes tiny-ml's
 * programs read, and the same bytes on both sides (the runtime's
 * TinyMLRuntime/core.c). No float, no closure. The flags are taken and
 * left: what is shared stays shared. *)
type extern_flags = No_sharing | Closures
val to_string : 'a -> extern_flags list -> string
val from_string : string -> int -> 'a
