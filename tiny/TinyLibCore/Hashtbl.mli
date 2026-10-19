(* Hashtbl, OCaml's subset (see Stdlib.mli): an array of buckets, a
 * key's by its hash (core.c's ml_hash: its integers, its strings'
 * bytes, its blocks' tags and fields, ten values at most), twice as
 * many when there are twice as many bindings as buckets (old: a list
 * of pairs) *)
type ('a, 'b) t
val create : int -> ('a, 'b) t
val length : ('a, 'b) t -> int
val find_opt : ('a, 'b) t -> 'a -> 'b option
val find : ('a, 'b) t -> 'a -> 'b
val mem : ('a, 'b) t -> 'a -> bool
val remove : ('a, 'b) t -> 'a -> unit
val add : ('a, 'b) t -> 'a -> 'b -> unit
val replace : ('a, 'b) t -> 'a -> 'b -> unit
val fold : ('a -> 'b -> 'c -> 'c) -> ('a, 'b) t -> 'c -> 'c
val iter : ('a -> 'b -> unit) -> ('a, 'b) t -> unit
