(* A set of tuples of integers kept sorted (lexicographically, the
 * first value first), as a B+tree: the tuples in leaves of at most 64,
 * each leaf sorted and linked to the next; above them inner nodes of
 * separators, each saying where a child's tuples start. A lookup goes
 * down from the root, a binary search in each node, to the one leaf
 * where the tuple is or would be:
 *
 *                       [ (5,2) | (9,0) ]                  inner
 *                      /        |        \
 *     [(1,1) (3,4) (4,0)] -> [(5,2) (7,7)] -> [(9,0) (9,3)]   leaves
 *
 * What sorting gives that a hash does not:
 * - A range: the tuples that begin with some values are side by side
 *   (iter_from), so one tree sorted with an index's columns first is
 *   that index; no other structure.
 * - Locality: tuples near in the order are in the same leaf. A caller
 *   that asks for tuples in increasing order, as a join does when it
 *   goes through sorted relations, finds most of them in the leaf of
 *   the one before. The hint is that leaf, remembered: a tuple between
 *   its first and its last is in it or nowhere, with no walk from the
 *   root. A hint is the caller's (a domain's own), not the tree's.
 *
 * design:
 * Flat as Tuples: a node's tuples in one array of integers. Not yet
 * the engine's: measured first against Tuples (plan_ml_multicore.md's
 * Status, tests/btree_bench.ml). What was found:
 * - The order of the set is the one that makes the head tests
 *   neighbours. Rule 81 of pointer.dl, point_to(P, L) :- assign(P, Q),
 *   point_to(Q, L), fires mostly from a new assign(P, Q), then Q's
 *   point_to in order: tests (P, L1), (P, L2)... With its lookups
 *   sorted, a set sorted (P, L) had 87% of 381 million tests in the
 *   hint's leaf; sorted (L, P), 8%.
 * - Generic code loses: a value asked of a closure, six comparisons a
 *   search; tests/btree_bench.ml, rule 81's pattern, ns a lookup on a
 *   domain, on 1, 8 and 32 domains:
 *
 *     Tuples.mem_by     213   283   521     (the engine's today)
 *     Tuples.mem2       172   222   395     written out for pairs
 *     Btree.mem_hint    301   378   698
 *     Btree.mem2_hint   117   149   206     written out for pairs
 *
 * - Written out for pairs, the tree with its hint wins: 32% less than
 *   the hash written out too on one domain, 48% less on 32. A hash's
 *   test is a miss of the cache, and 32 cores' misses queue for the
 *   memory; the hint's leaf is in the cache.
 * So the engine's change is Souffle's whole: the indexes trees too
 * (their tuples come out sorted, which makes the tests neighbours),
 * the arities used written out, and the trees' adding on several
 * domains (Tuples's parts by hash would scatter a P's tuples; by a
 * hash of the first column they stay together).
 *
 * cs-history:
 * Rudolf Bayer and Edward McCreight's B-trees (1970, at Boeing; Acta
 * Informatica 1972), made for disks: a node a page, so a lookup reads
 * few pages; the B+tree, every tuple in a leaf and the leaves linked
 * for a range, is in Douglas Comer's survey "The Ubiquitous B-Tree"
 * (1979), already the index of every database. Caches made the same
 * argument for memory: a node a few lines of cache.
 *
 * modern:
 * Souffle's relations are B-trees specialized for Datalog (Herbert
 * Jordan, Pavle Subotic, David Zhao, Bernhard Scholz, "A specialized
 * B-tree for concurrent Datalog evaluation", PPoPP 2019): no deletion,
 * insertion by many threads at once (optimistic locks, a version a
 * node), and operation hints, the last leaf of each operation per
 * thread, which they measured as the larger part of their speed.
 * Tries of columns (its "brie") for dense relations. *)

type t

(* the tuples of n values each *)
val create : int -> t

val count : t -> int

(* is the tuple whose i-th value is [value i] there? *)
val mem_by : t -> (int -> int) -> bool

(* the same, the hint's leaf tried first, and left at the leaf seen *)
type hint
val hint : t -> hint
val mem_hint : t -> hint -> (int -> int) -> bool

(* mem_hint of the pair (a, b), for a tree of pairs, written out *)
val mem2_hint : t -> hint -> int -> int -> bool

(* false: it was there *)
val add_by : t -> (int -> int) -> bool

(* [f keys base] for each tuple at or above the values, in order (its
 * values keys.(base) to keys.(base + n - 1)), until [f] says false *)
val iter_from : t -> (int -> int) -> (int array -> int -> bool) -> unit
