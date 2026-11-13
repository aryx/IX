(* Marshal: a subset of OCaml's module (see Stdlib.mli). It turns a value
 * into bytes and back, in OCaml's format, so that tiny-ml's programs
 * read what the host's OCaml writes, and both sides write the same
 * bytes (the code is in the runtime, runtime/ml/ml.c). It handles no
 * float and no closure. What is shared stays shared, except with
 * No_sharing, where each copy is written anew. Closures is accepted
 * and ignored. *)
type extern_flags = No_sharing | Closures
val to_string : 'a -> extern_flags list -> string
val from_string : string -> int -> 'a
