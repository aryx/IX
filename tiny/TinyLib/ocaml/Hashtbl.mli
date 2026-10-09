(* TinyLib: lib_core/collections/Hashtbl, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Hashtbl]: hash tables, modified in place, and hash functions *)

(*** Generic interface *)

type ('a, 'b) t

val create : int -> ('a,'b) t
        (* [create n]: empty, of initial size [n]. Raise
           [Invalid_argument "hashtbl__new"] if [n] is less than 1. *)

val copy : ('a, 'b) t -> ('a, 'b) t

val length : ('a, 'b) t -> int
        (* The number of bindings. *)

val add : ('a, 'b) t -> 'a -> 'b -> unit
        (* A binding more: one of [x] before is hidden, not replaced. *)

val find : ('a, 'b) t -> 'a -> 'b
        (* The current binding; raises [Not_found] if there is none. *)

val find_all : ('a, 'b) t -> 'a -> 'b list

val remove : ('a, 'b) t -> 'a -> unit
        (* The current binding of [x] removed, the previous one restored
           if it exists. *)

val iter : ('a -> 'b -> unit) -> ('a, 'b) t -> unit

(*** The polymorphic hash primitive *)

val hash : 'a -> int
        (* A positive integer for any value of any type. *)

external hash_param : int -> int -> 'a -> int = "hash_univ_param" "noalloc"

val mem : ('a, 'b) t -> 'a -> bool
val fold : ('a -> 'b -> 'c -> 'c) -> ('a, 'b) t -> 'c -> 'c
(** [fold f tbl init] is [(f kN dN ... (f k1 d1 init)...)], over all the
    bindings. *)

val replace : ('a, 'b) t -> 'a -> 'b -> unit
(** The current binding of [x] replaced. *)

val find_opt : ('a, 'b) t -> 'a -> 'b option
