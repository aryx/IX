(* TinyLib: lib_core/collections/Seq, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Sequences: lists computed as they are read, a function to call for
 * the next element; a query's rows, a walk's commits. OCaml 4.14's Seq,
 * the part ix's programs use.
 *
 *   Seq.take 2 (Seq.map succ (List.to_seq [ 1; 2; 3 ]))    2, 3: 4 not computed *)

type 'a node =
  | Nil
  | Cons of 'a * 'a t

(* a sequence: called, its first element and the rest, or Nil *)
and 'a t = unit -> 'a node

val empty : 'a t
val append : 'a t -> 'a t -> 'a t

(* 0 to n - 1, by f *)
val init : int -> (int -> 'a) -> 'a t

val map : ('a -> 'b) -> 'a t -> 'b t
val filter : ('a -> bool) -> 'a t -> 'a t
val filter_map : ('a -> 'b option) -> 'a t -> 'b t

(* each element's sequence, one after the other *)
val flat_map : ('a -> 'b t) -> 'a t -> 'b t
val concat_map : ('a -> 'b t) -> 'a t -> 'b t

(* the first n; the first that satisfy p; what follows them *)
val take : int -> 'a t -> 'a t
val take_while : ('a -> bool) -> 'a t -> 'a t
val drop_while : ('a -> bool) -> 'a t -> 'a t

(* the whole sequence read *)
val iter : ('a -> unit) -> 'a t -> unit
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a

(* the sequence of one element *)
val return : 'a -> 'a t
