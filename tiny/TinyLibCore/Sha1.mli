(* Sha1: a subset of lib_crypto's module (see Stdlib.mli). A digest has
 * 20 bytes, and the runtime computes it (runtime/ml/ml.c) on the
 * machine's words of 32 bits. *)
type t
val string : string -> t
(* [reads next] is the digest of the pieces that [next ()] gives until
 * "", without keeping them *)
val reads : (unit -> string) -> t
val to_hex : t -> string
(* [of_hex] takes 40 lowercase hex digits. It raises Invalid_argument
 * when the string's length is not 40, but it does not check the
 * digits themselves. *)
val of_hex : string -> t
