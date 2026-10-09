(* TinyLib: lib_core/base/String, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [String]: string operations *)

external length : string -> int = "%string_length"

external get : string -> int -> char = "%string_safe_get"
        (* Raise [Invalid_argument] if [n] is outside 0 to [length s - 1]. *)

(* ix: no set, create or fill, as OCaml's since 4.06: a string is not
 * written. What is written is bytes, with module Bytes: Bytes.create,
 * Bytes.set, then Bytes.to_string for a string (a copy;
 * Bytes.unsafe_to_string is none, for bytes no one writes again). *)
val make : int -> char -> string
val copy : string -> string
val sub : string -> int -> int -> string
        (* [sub s start len]. Raise [Invalid_argument] if [start < 0],
           [len < 0], or [start + len > length s]. *)
val blit : string -> int -> bytes -> int -> int -> unit
        (* [blit src srcoff dst dstoff len]. Raise [Invalid_argument]
           if a range is not valid. *)

val concat : string -> string list -> string
        (* [concat sep sl]: [sep] between each. *)

val trim : string -> string
(** Without leading and trailing whitespace. *)

val escaped: string -> string
        (* Special characters as escape sequences, OCaml's lexical
           conventions. *)

val index: string -> char -> int
        (* The leftmost. Raise [Not_found] if there is none. *)
val rindex: string -> char -> int
        (* The rightmost. Raise [Not_found] if there is none. *)
val index_from: string -> int -> char -> int

val uppercase: string -> string
val lowercase: string -> string
        (* With the accented letters of ISO Latin-1 (8859-1). *)

(*--*)

external unsafe_get : string -> int -> char = "%string_unsafe_get"
external unsafe_blit : string -> int -> bytes -> int -> int -> unit
                     = "blit_string" "noalloc"

val uppercase_ascii : string -> string
val lowercase_ascii : string -> string
(** US-ASCII's letters only. *)

val map : (char -> char) -> string -> string

type t = string

val equal : t -> t -> bool

val compare : t -> t -> int
(** Lexicographical order. *)

val starts_with :
  prefix:string -> string -> bool

val ends_with :
  suffix:string -> string -> bool

val split_on_char : char -> string -> string list
(** All the substrings between [sep]s, the empty ones too. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* the character's first, last, or first from i index, or None (index,
 * rindex and index_from raise Not_found) *)
val contains : string -> char -> bool
val index_opt : string -> char -> int option
val rindex_opt : string -> char -> int option
val index_from_opt : string -> int -> char -> int option
val rindex_from_opt : string -> int -> char -> int option

val iter : (char -> unit) -> string -> unit
val iteri : (int -> char -> unit) -> string -> unit
val for_all : (char -> bool) -> string -> bool
val exists : (char -> bool) -> string -> bool

(* a string of n characters, the i-th f i *)
val init : int -> (int -> char) -> string

(* an integer in s at i, of 16, 32 or 64 bits, its low byte first (le)
 * or last (be): a binary format's field *)
val get_uint16_le : string -> int -> int
val get_uint16_be : string -> int -> int
val get_int32_le : string -> int -> int32
val get_int32_be : string -> int -> int32
val get_int64_le : string -> int -> int64
val get_int64_be : string -> int -> int64
