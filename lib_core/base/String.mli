(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* Module [String]: string operations *)

external length : string -> int = "%string_length"
        (* Return the length (number of characters) of the given string. *)

external get : string -> int -> char = "%string_safe_get"
        (* [String.get s n] returns character number [n] in string [s].
           Raise [Invalid_argument] if [n] is ouside the range 0 to
           [(String.length s - 1)]. *)
external set : string -> int -> char -> unit = "%string_safe_set"
        (* [String.set s n c] modifies string [s] in place, replacing the
           character number [n] by [c]. Raise [Invalid_argument] if [n] is
           ouside the range 0 to [(String.length s - 1)]. *)

external create : int -> string = "create_string"
        (* [String.create n] returns a fresh string of length [n]. *)
val make : int -> char -> string
        (* [String.make n c] returns a fresh string of length [n], filled
           with the character [c]. *)
val copy : string -> string
        (* Return a copy of the given string. *)
val sub : string -> int -> int -> string
        (* [String.sub s start len] returns a fresh string of length [len],
           containing the characters number [start] to [start + len - 1] of
           string [s]. Raise [Invalid_argument] if [start] and [len] do not
           designate a valid substring of [s]; that is, if [start < 0], or
           [len < 0], or [start + len > String.length s]. *)
val fill : string -> int -> int -> char -> unit
        (* [String.fill s start len c] modifies string [s] in place,
           replacing the characters number [start] to [start + len - 1] by
           [c]. Raise [Invalid_argument] if [start] and [len] do not
           designate a valid substring of [s]. *)
val blit : string -> int -> string -> int -> int -> unit
        (* [String.blit src srcoff dst dstoff len] copies [len] characters
           from string [src], starting at character number [srcoff], to
           string [dst], starting at character number [dstoff]. Raise
           [Invalid_argument] if [srcoff] and [len] do not designate a valid
           substring of [src], or if [dstoff] and [len] do not designate a
           valid substring of [dst]. *)

val concat : string -> string list -> string
        (* [String.concat sep sl] catenates the list of strings [sl],
           inserting the separator string [sep] between each. *)

val trim : string -> string
(** Return a copy of the argument, without leading and trailing whitespace. *)

val escaped: string -> string
        (* Return a copy of the argument, with special characters
           represented by escape sequences, following the lexical
           conventions of Objective Caml. *)

val index: string -> char -> int
        (* [index s c] returns the position of the leftmost occurrence of
           character [c] in string [s]. Raise [Not_found] if [c] does not
           occur in [s]. *)
val rindex: string -> char -> int
        (* [rindex s c] returns the position of the rightmost occurrence of
           character [c] in string [s]. Raise [Not_found] if [c] does not
           occur in [s]. *)
val index_from: string -> int -> char -> int
val rindex_from: string -> int -> char -> int
        (* Same as [index] and [rindex], but start searching at the
           character position given as second argument. *)

val uppercase: string -> string
        (* Return a copy of the argument, with all lowercase letters
           translated to uppercase, including accented letters of the ISO
           Latin-1 (8859-1) character set. *)
val lowercase: string -> string
        (* Return a copy of the argument, with all uppercase letters
           translated to lowercase, including accented letters of the ISO
           Latin-1 (8859-1) character set. *)
val capitalize: string -> string
        (* Return a copy of the argument, with the first letter set to
           uppercase. *)
val uncapitalize: string -> string
        (* Return a copy of the argument, with the first letter set to
           lowercase. *)

(*--*)

external unsafe_get : string -> int -> char = "%string_unsafe_get"
external unsafe_set : string -> int -> char -> unit = "%string_unsafe_set"
external unsafe_blit : string -> int -> string -> int -> int -> unit
                     = "blit_string" "noalloc"
external unsafe_fill : string -> int -> int -> char -> unit
                     = "fill_string" "noalloc"

val uppercase_ascii : string -> string
(** [uppercase_ascii s] is [s] with all lowercase letters translated to
    uppercase, using the US-ASCII character set. *)

val lowercase_ascii : string -> string
(** [lowercase_ascii s] is [s] with all uppercase letters translated to
    lowercase, using the US-ASCII character set. *)


val capitalize_ascii : string -> string
(** [capitalize_ascii s] is [s] with the first character set to uppercase,
    using the US-ASCII character set. *)

val uncapitalize_ascii : string -> string
(** [uncapitalize_ascii s] is [s] with the first character set to lowercase,
    using the US-ASCII character set. *)

val map : (char -> char) -> string -> string
(** [map f s] is the string resulting from applying [f] to all the
    characters of [s] in increasing order. *)

(* the same, the function given each character's index too *)
val mapi : (int -> char -> char) -> string -> string


type t = string

val equal : t -> t -> bool
(** [equal s0 s1] is [true] if and only if [s0] and [s1] are character-wise
    equal. *)

val compare : t -> t -> int
(** [compare s0 s1] sorts [s0] and [s1] in lexicographical order. *)

val starts_with :
  prefix:string -> string -> bool
(** [starts_with ][~prefix s] is [true] if and only if [s] starts with
    [prefix]. *)

val ends_with :
  suffix:string -> string -> bool
(** [ends_with ][~suffix s] is [true] if and only if [s] ends with [suffix]. *)

val split_on_char : char -> string -> string list
(** [split_on_char sep s] returns the list of all (possibly empty)
    substrings of [s] that are delimited by the [sep] character. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* whether c is in s; the character's first, last, or first from i
 * index, or None (index, rindex and index_from raise Not_found) *)
val contains : string -> char -> bool
val index_opt : string -> char -> int option
val rindex_opt : string -> char -> int option
val index_from_opt : string -> int -> char -> int option
val rindex_from_opt : string -> int -> char -> int option

val iter : (char -> unit) -> string -> unit
val iteri : (int -> char -> unit) -> string -> unit
(* [fold_left f x s] is f (... (f (f x s.[0]) s.[1]) ...) s.[n-1] *)
val fold_left : ('a -> char -> 'a) -> 'a -> string -> 'a
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

(* the UTF-8 character at i, decoded (Uchar.utf_decode_...) *)
val get_utf_8_uchar : string -> int -> Uchar.utf_decode
