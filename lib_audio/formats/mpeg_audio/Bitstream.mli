(* Bitstream: a string read a few bits at a time, the most significant
 * bit of each byte first -- how every MPEG syntax element is laid out,
 * of any width, with no regard for byte boundaries (JPEG's reader, in
 * Jpeg, has the same idea, with its byte stuffing). Past the end,
 * zeros. *)

(* ix: the author's playground's libs/compression/Bits.mli, as Bitstream (machine has a Bits); less its start codes, a video's (docs/plans/plan_audio.md) *)

type t

val of_string : string -> t

(* [read b n]: the next [n] bits (up to 24), as a number *)
val read : t -> int -> int

(* [peek b n]: the same, without moving *)
val peek : t -> int -> int

val skip : t -> int -> unit

(* where we are, in bits from the start; and there again *)
val position : t -> int
val seek : t -> int -> unit

val at_end : t -> bool
