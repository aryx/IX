(* A relation's set of tuples, of one of two kinds, chosen for each
 * relation (mini-datalog -btree):
 *
 *   hashed (Tuples)                  sorted (Btree)
 *   ------------------------------   ---------------------------------
 *   a tuple's slot by its hash:      a tuple's leaf by its order: the
 *   one probe, a miss of the cache   tuples near it in the same leaf;
 *   whoever asked before             a test after one of a neighbour
 *                                    is in the cache (the hint)
 *   adding: a slot written           adding: the leaf's tuples after
 *                                    it moved right
 *   its indexes: Hash_index          its indexes: Tree_index
 *
 * Which wins depends on the order the rules ask in, which is why it is
 * a relation's choice: the tests of a rule's head that come out sorted
 * (Tree_index's lookups give their tuples in order) are neighbours in
 * a sorted set; a relation mostly added to, or asked at random, is
 * better hashed (languages/datalog/README.md's numbers).
 *
 * others:
 * Souffle declares a relation's representation: .decl r(x, y) btree
 * (its default), brie (a trie of the columns, for dense relations),
 * eqrel (an equivalence relation, kept as its classes, union-find).
 * Databases choose an index's kind per table and per column too: a
 * hash for equality, a B-tree for ranges and order. *)

type t

(* a set of tuples of n values, sorted or hashed *)
val create : sorted:bool -> int -> t

val sorted : t -> bool

(* is the tuple whose i-th value is [value i] there? *)
val mem_by : t -> (int -> int) -> bool
(* the same, the tuple an array (a hashed set's: no closure) *)
val mem_array : t -> int array -> bool

(* the same for a rule's heads, one after the other: a sorted set
 * tries the leaf of the one before first (Btree's hint), a pair's test
 * written out *)
type hint
val hint : t -> hint
val mem_hint : t -> hint -> (int -> int) -> bool

(* false: it was there *)
val add : t -> int array -> bool

(* the part of the tuple (Tuples's and Btree's 64): domains add at once
 * the tuples of different parts *)
val part_of : t -> (int -> int) -> int
