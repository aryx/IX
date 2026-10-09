(* TinyLib: lib_core/collections/Array, the part the tiny programs call (tiny/TinyLib/README.md) *)
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


(* Module [Array]: array operations *)

external length : 'a array -> int = "%array_length"
        (* Return the length (number of elements) of the given array. *)
external get: 'a array -> int -> 'a = "%array_safe_get"
        (* [Array.get a n] returns the element number [n] of array [a].
           Raise [Invalid_argument "Array.get"] if [n] is outside the range
           0 to [(Array.length a - 1)]. *)
external set: 'a array -> int -> 'a -> unit = "%array_safe_set"
        (* [Array.set a n x] modifies array [a] in place, replacing element
           number [n] with [x]. Raise [Invalid_argument "Array.set"] if [n]
           is outside the range 0 to [Array.length a - 1]. *)
external make: int -> 'a -> 'a array = "make_vect"
(* DEPRECATED; use make *)
external create: int -> 'a -> 'a array = "make_vect"
        (* [Array.make n x] returns a fresh array of length [n], initialized
           with [x]. *)
val init: int -> (int -> 'a) -> 'a array
        (* [Array.init n f] returns a fresh array of length [n], with
           element number [i] equal to [f i]. *)
val append: 'a array -> 'a array -> 'a array
        (* [Array.append v1 v2] returns a fresh array containing the
           concatenation of arrays [v1] and [v2]. *)
val concat: 'a array list -> 'a array
        (* Same as [Array.append], but catenates a list of arrays. *)
val sub: 'a array -> int -> int -> 'a array
        (* [Array.sub a start len] returns a fresh array of length [len],
           containing the elements number [start] to [start + len - 1] of
           array [a]. Raise [Invalid_argument "Array.sub"] if [start] and
           [len] do not designate a valid subarray of [a]; that is, if
           [start < 0], or [len < 0], or [start + len > Array.length a]. *)
val copy: 'a array -> 'a array
        (* [Array.copy a] returns a copy of [a], that is, a fresh array
           containing the same elements as [a]. *)
val fill: 'a array -> int -> int -> 'a -> unit
        (* [Array.fill a ofs len x] modifies the array [a] in place, storing
           [x] in elements number [ofs] to [ofs + len - 1]. Raise
           [Invalid_argument "Array.fill"] if [ofs] and [len] do not
           designate a valid subarray of [a]. *)
val to_list: 'a array -> 'a list
        (* [Array.to_list a] returns the list of all the elements of [a]. *)
val of_list: 'a list -> 'a array
        (* [Array.of_list l] returns a fresh array containing the elements
           of [l]. *)
val iter: ('a -> unit) -> 'a array -> unit
        (* [Array.iter f a] applies function [f] in turn to all the elements
           of [a]. *)
val map: ('a -> 'b) -> 'a array -> 'b array
        (* [Array.map f a] applies function [f] to all the elements of [a],
           and builds an array with the results returned by [f]: [[| f
           a.(0); f a.(1); ...; f a.(Array.length a - 1) |]]. *)
val iteri: (int -> 'a -> unit) -> 'a array -> unit
val fold_left: ('a -> 'b -> 'a) -> 'a -> 'b array -> 'a
        (* [Array.fold_left f x a] computes [f (... (f (f x a.(0)) a.(1))
           ...) a.(n-1)], where [n] is the length of the array [a]. *)
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

(* ix: no program of ix called these, taken out (to restore from ocaml-light's array.ml):
 * create_matrix. *)
