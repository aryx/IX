(* Seq: a subset of OCaml's module (see Stdlib.mli). A sequence is read
 * as it is pulled, and each element is made when it is asked for. For
 * example, tiny-db's rows come from a tree, and the tree stops being
 * read at a take. *)
type 'a t = unit -> 'a node
and 'a node = Nil | Cons of 'a * 'a t

val empty : 'a t
val init : int -> (int -> 'a) -> 'a t
val map : ('a -> 'b) -> 'a t -> 'b t
val filter : ('a -> bool) -> 'a t -> 'a t
val filter_map : ('a -> 'b option) -> 'a t -> 'b t
val concat_map : ('a -> 'b t) -> 'a t -> 'b t
val iter : ('a -> unit) -> 'a t -> unit
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
val take : int -> 'a t -> 'a t
val take_while : ('a -> bool) -> 'a t -> 'a t
val drop_while : ('a -> bool) -> 'a t -> 'a t
