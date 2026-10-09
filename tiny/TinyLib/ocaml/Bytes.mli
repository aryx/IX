(* TinyLib: lib_core/base/Bytes, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * OCaml. Copyright 1996 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

(** Byte sequences: mutable, of a fixed length, a byte a [char].

   An index of [s] is valid in [[0...l-1]], [l] its length; a position
   (the point between two bytes) in [[0...l]]. [start] and [len]
   designate a valid range if [len >= 0] and [start] and [start+len]
   are valid positions. *)

(* ix: OCaml 4.14's bytes.mli; the primitives' names are mini-ml's
 * (%string_length for %bytes_length...: the same block is under a
 * string and under bytes). *)

external length : bytes -> int = "%string_length"

external get : bytes -> int -> char = "%string_safe_get"
(** @raise Invalid_argument if the index is not valid. *)

external set : bytes -> int -> char -> unit = "%string_safe_set"
(** @raise Invalid_argument if the index is not valid. *)

external create : int -> bytes = "create_string"
(** [create n]: [n] bytes, not initialized.
    @raise Invalid_argument if [n < 0] or [n > ]{!Sys.max_string_length}. *)

val make : int -> char -> bytes
(** [make n c]: [n] bytes, each [c]. Raises as [create]. *)

val empty : bytes

val copy : bytes -> bytes

val of_string : string -> bytes
(** A copy. *)

val to_string : bytes -> string
(** A copy. *)

val sub : bytes -> int -> int -> bytes
(** [sub s pos len]: a copy of that range.
    @raise Invalid_argument if the range is not valid. *)

val sub_string : bytes -> int -> int -> string
(** As {!sub}, a string. *)


val blit :
  bytes -> int -> bytes -> int -> int
  -> unit
(** [blit src src_pos dst dst_pos len]; correct when [src] and [dst]
    are the same and the ranges overlap.
    @raise Invalid_argument if a range is not valid. *)

val blit_string :
  string -> int -> bytes -> int -> int
  -> unit
(** As {!blit}, from a string. *)


val cat : bytes -> bytes -> bytes
(** A new sequence.
    @raise Invalid_argument if longer than {!Sys.max_string_length}. *)

val iteri : (int -> char -> unit) -> bytes -> unit

val index_from : bytes -> int -> char -> int
(** [index_from s i c]: the first [c] at or after position [i].
    @raise Invalid_argument if [i] is not a valid position.
    @raise Not_found if there is none. *)

val index_from_opt: bytes -> int -> char -> int option
(** As {!index_from}, [None] where it raises [Not_found]. *)

type t = bytes



(** Unsafe conversions: no copy, so the string can be seen to change.
    Only for a sequence that is not written after ([unsafe_to_string]:
    a string built in a buffer then given away), or a string that is
    only read ([unsafe_of_string]: a literal may be shared). *)

val unsafe_to_string : bytes -> string

val unsafe_of_string : string -> bytes

(** Integers encoded in the bytes. All raise [Invalid_argument] if the
    integer does not fit at index [i]. [le]: the least significant
    byte first; [be]: the most (the network's order). An [int] read is
    zero-extended ([uint]); one written is truncated to its low bytes. *)

val get_uint8 : bytes -> int -> int


val get_uint16_be : bytes -> int -> int

val get_uint16_le : bytes -> int -> int


val get_int32_be : bytes -> int -> int32

val get_int32_le : bytes -> int -> int32

val get_int64_be : bytes -> int -> int64

val get_int64_le : bytes -> int -> int64

val set_uint8 : bytes -> int -> int -> unit

val set_uint16_be : bytes -> int -> int -> unit

val set_uint16_le : bytes -> int -> int -> unit

val set_int32_be : bytes -> int -> int32 -> unit

val set_int32_le : bytes -> int -> int32 -> unit

val set_int64_be : bytes -> int -> int64 -> unit

val set_int64_le : bytes -> int -> int64 -> unit

(**/**)

(* For system use only: no bound check. *)

external unsafe_get : bytes -> int -> char = "%string_unsafe_get"
external unsafe_set : bytes -> int -> char -> unit = "%string_unsafe_set"
