(* TinyLib: lib_core/base/Buffer, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Pierre Weis and Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1999 INRIA. GNU Library General Public License, with the linking exception of OCaml's LICENSE. *)

(** Extensible string buffers: strings accumulated in quasi-linear time
    (quadratic when concatenated pairwise). *)

type t

val create : int -> t
(** Empty; [n] is its first size. *)

val contents : t -> string
(** A copy. *)

val to_bytes : t -> bytes
(** A copy. *)



val nth : t -> int -> char
(** Raise [Invalid_argument] if the index is out of bounds. *)

val length : t -> int

val clear : t -> unit


val add_char : t -> char -> unit

val add_string : t -> string -> unit

val add_substring : t -> string -> int -> int -> unit
(** [add_substring b s ofs len] *)

val add_subbytes : t -> bytes -> int -> int -> unit
(** @raise Invalid_argument if [ofs] and [len] are not a valid range. *)





(* ix: OCaml's later functions, those ix's programs use *)

val add_bytes : t -> bytes -> unit

(* an integer's bytes added, the low one first *)
val add_uint8 : t -> int -> unit
val add_uint16_le : t -> int -> unit
val add_int32_le : t -> int32 -> unit
val add_int64_le : t -> int64 -> unit
