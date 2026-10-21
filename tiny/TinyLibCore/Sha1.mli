(* Sha1, lib_crypto's subset (see Stdlib.mli): a digest of 20 bytes,
 * computed by the runtime (TinyMLRuntime/core.c) on the machine's words
 * of 32 bits (old: in ML, a word as two halves of 16, as an integer of
 * tiny-ml's has 31) *)
type t
val string : string -> t
(* the digest of the pieces [next ()] gives until "", none kept *)
val reads : (unit -> string) -> t
val to_hex : t -> string
