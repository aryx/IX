(* A delta writes an object as copies from a base object and inserted
 * bytes (git9's applydelta, and delta.c's encoder, phase 7).
 *
 * On the wire, a delta starts with the sizes of the base and of the
 * result (in 7-bit groups, least significant first), and then has
 * instructions. A byte with its top bit set is a copy: its low 7 bits
 * say which bytes of an offset (4 bytes) and of a length (3 bytes)
 * follow, and a length of 0 means 0x10000. A byte from 1 to 127 is an
 * insert of that many bytes, which follow it.
 *
 *    base "hello world", result "hello there":
 *    0b 0b | 90 06 | 05 't' 'h' 'e' 'r' 'e'
 *            copy 6 (from 0: no offset byte)   insert 5
 *
 * Here the instructions are a variant, decoded once and then applied. *)

type op = Copy of { off : int; len : int } | Insert of string

type t = { base_size : int; size : int; ops : op list }

exception Corrupt of string

val decode : string -> t
val encode : t -> string

(* the result; the sizes of the base and of the result are checked *)
val apply : string -> t -> string

(* git9's encoder (delta.c). Both objects are cut into content-defined
 * chunks of 128 to 8,192 bytes. A chunk is cut where a gear rolling
 * hash has its low 8 bits zero, so that a chunk boundary depends on
 * the bytes near it, not on offsets, and an insertion moves only the
 * chunks around it. Each chunk of the target that is found among the
 * base's chunks becomes a copy, stretched as far as the bytes keep
 * matching, and the other chunks become inserts. *)
type table

val table : string -> table
val deltify : table -> string -> t

(* git9's estimate of a delta's size (deltasz): 7 bytes for each copy,
 * the data and one byte for each insert, and 32 more *)
val estimate : t -> int
