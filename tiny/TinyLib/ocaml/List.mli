(* TinyLib: lib_core/collections/List, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [List]: list operations *)

val length : 'a list -> int
val hd : 'a list -> 'a
        (* Raise [Failure "hd"] if the list is empty. *)
val tl : 'a list -> 'a list
        (* Raise [Failure "tl"] if the list is empty. *)
val nth : 'a list -> int -> 'a
        (* Raise [Failure "nth"] if the list is too short. *)
val rev : 'a list -> 'a list
val rev_append : 'a list -> 'a list -> 'a list
        (* [rev_append l1 l2] is [l1] reversed, then [l2]. *)
val concat  : 'a list list -> 'a list
val flatten : 'a list list -> 'a list

(** Iterators *)

val iter : ('a -> unit) -> 'a list -> unit
val map : ('a -> 'b) -> 'a list -> 'b list
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b list -> 'a
        (* [fold_left f a [b1; ...; bn]] is [f (... (f (f a b1) b2) ...) bn]. *)
val fold_right : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
        (* [fold_right f [a1; ...; an] b] is [f a1 (f a2 (... (f an b) ...))]. *)

(** Iterators on two lists: all raise [Invalid_argument] if the two
    lists have different lengths *)

val iter2 : ('a -> 'b -> unit) -> 'a list -> 'b list -> unit
val map2 : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list
val fold_left2 : ('a -> 'b -> 'c -> 'a) -> 'a -> 'b list -> 'c list -> 'a
val fold_right2 : ('a -> 'b -> 'c -> 'c) -> 'a list -> 'b list -> 'c -> 'c

(** List scanning *)

val for_all : ('a -> bool) -> 'a list -> bool
val exists : ('a -> bool) -> 'a list -> bool
val for_all2 : ('a -> 'b -> bool) -> 'a list -> 'b list -> bool
val exists2 : ('a -> 'b -> bool) -> 'a list -> 'b list -> bool
        (* Raise [Invalid_argument] if the two lists have different lengths. *)
val mem : 'a -> 'a list -> bool
val memq : 'a -> 'a list -> bool
        (* As [mem], by physical equality. *)

(** Association lists *)

val assoc : 'a -> ('a * 'b) list -> 'b
        (* Raise [Not_found] if the key has no value. *)
val mem_assoc : 'a -> ('a * 'b) list -> bool
val assq : 'a -> ('a * 'b) list -> 'b
        (* As [assoc], by physical equality. *)

(** Lists of pairs *)

val split : ('a * 'b) list -> 'a list * 'b list
val combine : 'a list -> 'b list -> ('a * 'b) list
        (* Raise [Invalid_argument] if the two lists have different lengths. *)

val merge : ('a -> 'a -> bool) -> 'a list -> 'a list -> 'a list
        (* Two lists merged, by the given predicate. *)

val sort : ('a -> 'a -> int) -> 'a list -> 'a list
(** In increasing order. *)

val filter : ('a -> bool) -> 'a list -> 'a list

val find_all : ('a -> bool) -> 'a list -> 'a list
(** Another name for {!List.filter}. *)

val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
(** The elements that satisfy the predicate, and those that do not. *)

val find : ('a -> bool) -> 'a list -> 'a
(** The first one. Raise [Not_found] if there is none. *)

val filter_map : ('a -> 'b option) -> 'a list -> 'b list

val iteri : (int -> 'a -> unit) -> 'a list -> unit
(** The index counts from 0. *)

val concat_map : ('a -> 'b list) -> 'a list -> 'b list

val find_opt : ('a -> bool) -> 'a list -> 'a option

val assoc_opt : 'a -> ('a * 'b) list -> 'b option

val nth_opt : 'a list -> int -> 'a option
(** Raise [Invalid_argument "List.nth"] if [n] is negative. *)

val find_map : ('a -> 'b option) -> 'a list -> 'b option
(** The first result of the form [Some v], in order. *)

val mapi : (int -> 'a -> 'b) -> 'a list -> 'b list

val init : int -> (int -> 'a) -> 'a list
(** [[f 0; f 1; ...; f (len-1)]], evaluated left to right.
    Raise [Invalid_argument] if [len < 0]. *)

val rev_map : ('a -> 'b) -> 'a list -> 'b list
(** [rev (map f l)], tail-recursive. *)

(* ix: OCaml's later functions, those ix's programs use *)

val to_seq : 'a list -> 'a Seq.t
val of_seq : 'a Seq.t -> 'a list

val filteri : (int -> 'a -> bool) -> 'a list -> 'a list

(* sort, which keeps equal elements in their order; and sorted with one
 * of each group of equal elements *)
val stable_sort : ('a -> 'a -> int) -> 'a list -> 'a list
val sort_uniq : ('a -> 'a -> int) -> 'a list -> 'a list

val assq_opt : 'a -> ('a * 'b) list -> 'b option
(* the list without x's first pair *)
val remove_assoc : 'a -> ('a * 'b) list -> ('a * 'b) list
