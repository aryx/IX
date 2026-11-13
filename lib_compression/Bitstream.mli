(* Bitstream: a string read a few bits at a time, the most significant
 * bit of each byte first. This is how every MPEG syntax element is laid
 * out: it can have any width, with no regard for byte boundaries. (The
 * JPEG reader, in Jpeg, has the same idea, with its byte stuffing.)
 * Past the end of the string, the bits read are zeros. *)

(* ix: copied from libs/compression/Bits.mli in the author's playground,
 * renamed Bitstream because machine has a Bits. Its start codes are
 * kept for the MPEG-1 video reader (Mpeg1). *)

type t

val of_string : string -> t

(* [read b n] reads the next [n] bits (up to 24), as a number *)
val read : t -> int -> int

(* [peek b n] does the same, without moving *)
val peek : t -> int -> int

val skip : t -> int -> unit

(* [position] says where we are, in bits from the start; [seek] goes
 * back there *)
val position : t -> int
val seek : t -> int -> unit

val at_end : t -> bool

(* [next_start_code b] moves to the next byte boundary, then to the next
 * 00 00 01. It returns the code byte after it, with the reader just past
 * that byte, or None at the end. Each layer of an MPEG-1 video begins
 * this way. *)
val next_start_code : t -> int option
