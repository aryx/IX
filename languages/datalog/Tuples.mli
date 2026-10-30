(* A relation's tuples as a set: each tuple once, asked for by its
 * values. An array of slots (open addressing): a tuple is put at the
 * slot its hash says, or the next free one after it; a lookup walks
 * from that slot to the tuple or to a free slot. Half the slots at most
 * are used, so a walk is short. A slot is the tuple's values, in one
 * array of integers for all the slots: no pointer to follow.
 *
 * design:
 * Most of a pointer analysis's firings find a tuple that is there
 * already (mini-ml's own code by pointer.dl: 372 million firings of
 * point_to(P, L) :- assign(P, Q), point_to(Q, L) for 6.6 million new
 * tuples), so the test of a tuple that is there is the engine's
 * inner loop. Here it is asked from the values themselves, column by
 * column ([mem_by]), with no array made for a tuple that is then
 * dropped; the hash mixes integers, the comparison compares integers,
 * and they are where the slot is: with millions of tuples a lookup is
 * a miss of the cache, two when the slot points to an array (the rule
 * above: 147 s by Hashtbl, 104 s by slots of arrays, 81 s flat).
 * old: OCaml's Hashtbl of int arrays: the tuple made first, hashed by
 * the polymorphic hash (which walks any value), compared by the
 * polymorphic compare.
 *
 * others:
 * Souffle keeps a relation in a B-tree (sorted: a range of it is an
 * index's lookup too) or in a trie of its columns (its "brie", for
 * dense relations); databases since System R in B-trees; Python's
 * dict and Lua's tables are open addressing, as this is. *)

type t

(* the tuples of an arity *)
val create : int -> t

val count : t -> int
val mem : t -> int array -> bool

(* is there the tuple whose i-th value is [value i]? *)
val mem_by : t -> (int -> int) -> bool

(* false: it was there *)
val add : t -> int array -> bool
