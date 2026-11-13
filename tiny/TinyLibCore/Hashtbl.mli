(* Hashtbl: a subset of OCaml's module (see Stdlib.mli). A table is an
 * array of buckets, and a key's bucket is chosen by its hash. The hash
 * is runtime/ml/ml.c's ml_hash, which looks at the key's integers, its
 * strings' bytes, and its blocks' tags and fields, ten values at most.
 * The number of buckets doubles when there are twice as many bindings
 * as buckets. *)
type ('a, 'b) t
val create : int -> ('a, 'b) t
val length : ('a, 'b) t -> int
val copy : ('a, 'b) t -> ('a, 'b) t
val find_opt : ('a, 'b) t -> 'a -> 'b option
val find : ('a, 'b) t -> 'a -> 'b
val find_all : ('a, 'b) t -> 'a -> 'b list
val mem : ('a, 'b) t -> 'a -> bool
val remove : ('a, 'b) t -> 'a -> unit
val add : ('a, 'b) t -> 'a -> 'b -> unit
val replace : ('a, 'b) t -> 'a -> 'b -> unit
val fold : ('a -> 'b -> 'c -> 'c) -> ('a, 'b) t -> 'c -> 'c
val iter : ('a -> 'b -> unit) -> ('a, 'b) t -> unit
