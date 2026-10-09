(* TinyLib: lib_core/base/Option, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

(** Option values: the presence or the absence of a value. *)

type 'a t = 'a option = None | Some of 'a

val none : 'a option

val some : 'a -> 'a option

val value : 'a option -> (*default:*)'a -> 'a
(** [value o default] is [v] if [o] is [Some v], [default] otherwise
    (no label here). *)

val get : 'a option -> 'a
(** @raise Invalid_argument if [None]. *)

val bind : 'a option -> ('a -> 'b option) -> 'b option
(** [bind o f] is [f v] if [o] is [Some v], [None] otherwise. *)

val map : ('a -> 'b) -> 'a option -> 'b option

val iter : ('a -> unit) -> 'a option -> unit

val is_some : 'a option -> bool

val to_list : 'a option -> 'a list
(** [[]] or [[v]]. *)
