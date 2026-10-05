(* Numbers as a format's bytes (a protocol's message, a disk's sector, a
 * file's header): read in a string, added to a buffer, set in bytes;
 * le the low byte first, be the high one.
 *
 * A number is an int. Those of 32 bits are read and written by halves,
 * so that the code is the same where an int has 31 bits (arm): there a
 * number of 2^30 or more reads as its low 31 bits (~0 as -1, a negative
 * one written back as it was). A number of 64 bits is an int64, the
 * stdlib's (String.get_int64_le, Buffer.add_int64_le). *)

(* at an offset of a string *)
val u8 : string -> int -> int
val le16 : string -> int -> int
val le32 : string -> int -> int
val be16 : string -> int -> int
val be32 : string -> int -> int

(* at a buffer's end: the number's low 8, 16 or 32 bits *)
val add_u8 : Buffer.t -> int -> unit
val add_le16 : Buffer.t -> int -> unit
val add_le32 : Buffer.t -> int -> unit
val add_be16 : Buffer.t -> int -> unit
val add_be32 : Buffer.t -> int -> unit

(* at an offset of bytes *)
val set_u8 : bytes -> int -> int -> unit
val set_le16 : bytes -> int -> int -> unit
val set_le32 : bytes -> int -> int -> unit

(* [o], [width], [n]: a number's low bytes, as many as said (1 to 8),
 * the low one first *)
val set_le : bytes -> int -> int -> int64 -> unit

(* a header's fields in a row: a number's 1, 2, 4 or 8 bytes (Q's from
 * an int, its sign extended), and bytes as they are *)
type field = B of int | W of int | L of int | Q of int | S of string

val le : field list -> string
val be : field list -> string
