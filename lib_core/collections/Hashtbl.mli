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


(* Module [Hashtbl]: hash tables and hash functions *)

(* Hash tables are hashed association tables, with in-place modification. *)

(*** Generic interface *)

type ('a, 'b) t
        (* The type of hash tables from type ['a] to type ['b]. *)

val create : int -> ('a,'b) t
        (* [Hashtbl.create n] creates a new, empty hash table, with initial
           size [n]. Raise [Invalid_argument "hashtbl__new"] if [n] is less
           than 1. *)

val clear : ('a, 'b) t -> unit
        (* Empty a hash table. *)

val copy : ('a, 'b) t -> ('a, 'b) t
        (* Return a copy of the given hashtable. *)

val length : ('a, 'b) t -> int
        (* [Hashtbl.length tbl] returns the number of bindings in [tbl]. *)

val add : ('a, 'b) t -> 'a -> 'b -> unit
        (* [Hashtbl.add tbl x y] adds a binding of [x] to [y] in table
           [tbl]. *)

val find : ('a, 'b) t -> 'a -> 'b
        (* [Hashtbl.find tbl x] returns the current binding of [x] in [tbl],
           or raises [Not_found] if no such binding exists. *)

val find_all : ('a, 'b) t -> 'a -> 'b list
        (* [Hashtbl.find_all tbl x] returns the list of all data associated
           with [x] in [tbl]. *)

val remove : ('a, 'b) t -> 'a -> unit
        (* [Hashtbl.remove tbl x] removes the current binding of [x] in
           [tbl], restoring the previous binding if it exists. *)

val iter : ('a -> 'b -> unit) -> ('a, 'b) t -> unit
        (* [Hashtbl.iter f tbl] applies [f] to all bindings in table [tbl]. *)


(*** The polymorphic hash primitive *)

val hash : 'a -> int
        (* [Hashtbl.hash x] associates a positive integer to any value of
           any type. *)

external hash_param : int -> int -> 'a -> int = "hash_univ_param" "noalloc"
        (* [Hashtbl.hash_param n m x] computes a hash value for [x], with
           the same properties as for [hash]. *)

(* ported from 3.12 *)
val mem : ('a, 'b) t -> 'a -> bool
(** [Hashtbl.mem tbl x] checks if [x] is bound in [tbl]. *)
val fold : ('a -> 'b -> 'c -> 'c) -> ('a, 'b) t -> 'c -> 'c
(** [Hashtbl.fold f tbl init] computes [(f kN dN ... (f k1 d1 init)...)],
    where [k1 ... kN] are the keys of all bindings in [tbl], and [d1 ... dN]
    are the associated values. *)

val replace : ('a, 'b) t -> 'a -> 'b -> unit
(** [Hashtbl.replace tbl x y] replaces the current binding of [x] in [tbl]
    by a binding of [x] to [y]. *)

val find_opt : ('a, 'b) t -> 'a -> 'b option
(** [Hashtbl.find_opt tbl x] returns the current binding of [x] in [tbl], or
    [None] if no such binding exists. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* clear (OCaml's also shrinks the table to its first size) *)
val reset : ('a, 'b) t -> unit

val filter_map_inplace : ('a -> 'b -> 'b option) -> ('a, 'b) t -> unit
(** [Hashtbl.filter_map_inplace f tbl] applies [f] to all bindings in
    table [tbl] and updates each binding depending on the result of
    [f]. If [f] returns [None], the binding is discarded. If it returns
    [Some new_val], the binding is updated to associate the key to
    [new_val]. *)
