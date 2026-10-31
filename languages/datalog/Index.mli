(* A relation's index: the values of some of its columns (the key) to
 * the tuples that have them, the tuples by their number in the
 * relation (Datalog's rows). Flat, as Tuples is: an array of slots by
 * open addressing, a slot the key's values and the number of the last
 * tuple added with that key; and an array by tuple, the number of the
 * one added with the same key before it (-1: none). A lookup walks
 * the slots to the key, then the chain (the slots in Tuples's 64
 * parts, a key's by its hash, so that domains add at once the tuples
 * whose keys are in their own parts):
 *
 *    slots                          next (by tuple)
 *    +--------+------+              0: -1
 *    | key k1 |  7 --+--> 7 -> 4 -> 0 -1      4: 0
 *    +--------+------+              7: 4
 *    | (free) |  -1  |
 *    +--------+------+
 *
 * design:
 * old: OCaml's Hashtbl, the key an array projected from the tuple
 * (made at each lookup and at each tuple added, hashed by the
 * polymorphic hash), to a list of the tuples' arrays. Here nothing is
 * made for a lookup, and an index of 9.5 million tuples is two arrays
 * of integers, not 9.5 million cells and keys for the collector.
 *
 * others:
 * Souffle's indexes are the relation itself sorted again, in the
 * key's columns first (a B-tree each order), a lookup a range; its
 * index selection finds the fewest orders that serve every lookup of
 * the rules (Subotic et al., VLDB 2018). A chained hash, as here, is
 * what databases call a hash index (System R had B-trees; hash join,
 * Gamma and Grace, the 1980s). *)

type t

(* an index on a key of n columns *)
val create : int -> t

(* the tuple numbered [id], whose key's i-th value is [key i], added.
 * The tuples are added in their numbers' order. *)
val add : t -> (int -> int) -> int -> unit

(* the last tuple added with that key, -1 if none *)
val first : t -> (int -> int) -> int

(* the tuple added with the same key before this one, -1 if none *)
val next : t -> int -> int

(* the part of the key whose i-th value is [value i]: [add] of keys of
 * different parts may run at the same time, after [reserve] for the
 * largest number added *)
val part_of : t -> (int -> int) -> int
val reserve : t -> int -> unit
