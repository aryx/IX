(* Numbers as the bytes of a format (a protocol's message, a disk's
 * sector, a file's header). They are read from a string, added to a
 * buffer, or set in bytes. The le functions put the low byte first,
 * and the be functions the high byte.
 *
 * A number is an int. The numbers of 32 bits are read and written by
 * halves, so that the code is the same where an int has 31 bits (arm).
 * There a number of 2^30 or more reads as its low 31 bits: ~0 reads as
 * -1, and a negative number is written back as it was. A number of 64
 * bits is an int64, and the stdlib handles it (String.get_int64_le,
 * Buffer.add_int64_le).
 *
 *     0x12345678 in four bytes:
 *       add_le32     78 56 34 12       the low byte first
 *       add_be32     12 34 56 78       the high byte first, as written
 *
 *     le [ B 1; W 0x0203; L 0x04050607; S "ab" ]
 *                    01 03 02 07 06 05 04 61 62
 *
 * {b An int of 31 bits.} OCaml and mini-ml keep an integer in the
 * machine's word with one bit taken: the lowest, set to 1, tells the
 * collector that the word is a number and not the address of a
 * block (an address is even). The integer n is the word 2n + 1:
 *
 *     a word of 32 bits (arm)    [ n, 31 bits                    | 1 ]
 *     an address                 [ 30 bits                     | 0 0 ]
 *
 * So on arm an int goes from -2^30 to 2^30 - 1, and on arm64 it has
 * 63 bits. A 32-bit field of a format does not fit in arm's int: the
 * address 0x80000000, a checksum, or a color with its alpha. Code that
 * must be right there keeps such a number as two halves of 16 bits,
 * or as an int32 or an int64, which are blocks (and cost an
 * allocation). The functions here do the bytes by halves, so that
 * no intermediate result is lost; but what they give back is still
 * an int, with the limits above.
 *
 * Where it stands: 9P's messages are packed with these functions
 * (P9_wire); a card's partition table and its FAT are set and read
 * with them (Mkcard, Fdisk); the version control's pack file is
 * big-endian (Pack); and the linker sets a datum's bytes in the data
 * section with [set_le].
 *
 * terminology:
 * Little-endian and big-endian are Danny Cohen's words (1980), from
 * Gulliver's Travels, where two peoples are at war over the end at
 * which an egg is opened. His point was that either order works, and
 * that one must be agreed on. The networks agreed on the big end
 * (IP, TCP), and the x86 and arm processors, as they are run today,
 * on the little one. 9P is little-endian, and Plan 9's a.out header
 * is big-endian.
 *
 * References: Danny Cohen, "On Holy Wars and a Plea for Peace"
 * (Internet Experiment Note 137, 1980; IEEE Computer, 1981);
 * OCaml's manual, "Interfacing C with OCaml", for a value's word. *)

(* The number at an offset of a string *)
val u8 : string -> int -> int
val le16 : string -> int -> int
val le32 : string -> int -> int
val be16 : string -> int -> int
val be32 : string -> int -> int

(* Adds the number's low 8, 16 or 32 bits at the end of a buffer *)
val add_u8 : Buffer.t -> int -> unit
val add_le16 : Buffer.t -> int -> unit
val add_le32 : Buffer.t -> int -> unit
val add_be16 : Buffer.t -> int -> unit
val add_be32 : Buffer.t -> int -> unit

(* Sets the number at an offset of bytes *)
val set_u8 : bytes -> int -> int -> unit
val set_le16 : bytes -> int -> int -> unit
val set_le32 : bytes -> int -> int -> unit

(* [set_le b o width n] sets the low [width] bytes of [n] (1 to 8) at
 * offset [o], the low byte first *)
val set_le : bytes -> int -> int -> int64 -> unit

(* The fields of a header, in a row: B, W, L and Q give a number's 1,
 * 2, 4 or 8 bytes (Q's number is an int, with its sign extended), and
 * S gives bytes as they are *)
type field = B of int | W of int | L of int | Q of int | S of string

val le : field list -> string
val be : field list -> string
