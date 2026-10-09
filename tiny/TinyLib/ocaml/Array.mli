(* TinyLib: lib_core/collections/Array, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Array]: array operations *)

external length : 'a array -> int = "%array_length"
external get: 'a array -> int -> 'a = "%array_safe_get"
        (* Raise [Invalid_argument "Array.get"] if [n] is outside 0 to
           [length a - 1]. *)
external set: 'a array -> int -> 'a -> unit = "%array_safe_set"
        (* Raise [Invalid_argument "Array.set"] likewise. *)
external make: int -> 'a -> 'a array = "make_vect"
(* DEPRECATED; use make *)
external create: int -> 'a -> 'a array = "make_vect"
        (* [make n x]: [n] elements, each [x] (the same value). *)
val init: int -> (int -> 'a) -> 'a array
        (* [init n f]: element [i] is [f i]. *)
val append: 'a array -> 'a array -> 'a array
val concat: 'a array list -> 'a array
val sub: 'a array -> int -> int -> 'a array
        (* [sub a start len]. Raise [Invalid_argument "Array.sub"] if
           [start < 0], [len < 0], or [start + len > length a]. *)
val copy: 'a array -> 'a array
val fill: 'a array -> int -> int -> 'a -> unit
        (* [fill a ofs len x]. Raise [Invalid_argument "Array.fill"] if
           the range is not valid. *)
val to_list: 'a array -> 'a list
val of_list: 'a list -> 'a array
val iter: ('a -> unit) -> 'a array -> unit
val map: ('a -> 'b) -> 'a array -> 'b array
val iteri: (int -> 'a -> unit) -> 'a array -> unit
val fold_left: ('a -> 'b -> 'a) -> 'a -> 'b array -> 'a
(*--*)

external unsafe_get: 'a array -> int -> 'a = "%array_unsafe_get"
external unsafe_set: 'a array -> int -> 'a -> unit = "%array_unsafe_set"

(* ix: OCaml's later functions, those ix's programs use *)

(* an array as a sequence, its elements read when asked *)
val to_seq : 'a array -> 'a Seq.t

val exists : ('a -> bool) -> 'a array -> bool
val mem : 'a -> 'a array -> bool
val find_opt : ('a -> bool) -> 'a array -> 'a option

(* the array sorted in place; both keep equal elements in their order *)
val sort : ('a -> 'a -> int) -> 'a array -> unit
val stable_sort : ('a -> 'a -> int) -> 'a array -> unit
