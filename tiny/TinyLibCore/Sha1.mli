(* Sha1, lib_crypto's subset (see Stdlib.mli): a digest of 20 bytes,
 * its words of 32 bits each two halves of 16 (an integer of tiny-ml's
 * has 31), the rotations and the sums on the halves *)
type t
val string : string -> t
val to_hex : t -> string
