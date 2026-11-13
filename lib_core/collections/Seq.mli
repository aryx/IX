(* Sequences are lists computed as they are read: each holds a function
 * to call for the next element. They serve for the rows of a query, or
 * the commits of a walk. This is the part of OCaml 4.14's Seq that ix's
 * programs use.
 *
 *   Seq.take 2 (Seq.map succ (List.to_seq [ 1; 2; 3 ]))   2, 3 (4 not computed)
 *
 * A list's cell holds its tail; a sequence's holds a function that
 * will make it. map, filter and take build no element: each wraps
 * the function, and the work is done one element at a time, when
 * iter or fold_left at the end of the chain asks. So a chain over a
 * million rows keeps one row in memory, and one that stops early
 * (take) never computes the rest.
 *
 * Nothing is kept: a sequence read twice is computed twice, and the
 * effects of its functions happen twice (it is a function, not
 * OCaml's lazy value, which remembers). *)

type 'a node =
  | Nil
  | Cons of 'a * 'a t

(* A sequence is a function which, when called, gives its first element
 * and the rest, or Nil. *)
and 'a t = unit -> 'a node

val empty : 'a t
val append : 'a t -> 'a t -> 'a t

(* The sequence of f 0 to f (n - 1). *)
val init : int -> (int -> 'a) -> 'a t

val map : ('a -> 'b) -> 'a t -> 'b t
val filter : ('a -> bool) -> 'a t -> 'a t
val filter_map : ('a -> 'b option) -> 'a t -> 'b t

(* The sequences of the elements, one after the other. *)
val flat_map : ('a -> 'b t) -> 'a t -> 'b t
val concat_map : ('a -> 'b t) -> 'a t -> 'b t

(* take gives the first n elements, take_while the first elements that
 * satisfy p, and drop_while what follows them. *)
val take : int -> 'a t -> 'a t
val take_while : ('a -> bool) -> 'a t -> 'a t
val drop_while : ('a -> bool) -> 'a t -> 'a t

(* These read the whole sequence. *)
val iter : ('a -> unit) -> 'a t -> unit
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a

(* the sequence of one element *)
val return : 'a -> 'a t
