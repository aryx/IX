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
 * Flat as Tuples: a node's tuples in one array of integers. An index of
 * Datalog's relations is one (Index), measured first against Tuples
 * (plan_ml_multicore.md's Status, tests/btree_bench.ml). What was
 * found:
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
 * road-not-taken:
 * Souffle's insertion hints: a tuple that belongs in the leaf of the
 * insertion before (at or above its first, below the next leaf's
 * first), with room, put there with no descent; and a rule's new
 * tuples sorted before they are inserted, in each index's order, so
 * that they mostly do. Tried (2026-10-31) and not kept: mini-ml and
 * the assembler, all sorted, one core, 105.9 s with the hint against
 * 105.2 without; mini-datalog's own facts 2.04 s, and 2.33 with the
 * batches sorted, against 2.00. The new tuples do not come grouped by
 * leaf here (only the set's, of the hot rule, come by P), the descent
 * saved is a few binary searches in nodes in the cache, and a sort in
 * OCaml (Array.stable_sort, a closure a comparison, its stores through
 * the collector's barrier, being polymorphic) costs more than they.
 * The leaves' moves, the larger part of an insertion, stay either way.
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

(* the tuples of n values each, in 64 parts by their first value's hash
 * (Tuples.parts): a tree each, so that domains add at once the tuples
 * of their own parts, and the tuples that begin with the same value,
 * a range, are in one tree *)
val create : int -> t

val count : t -> int
val width : t -> int             (* the values of a tuple *)

(* the part of the tuple whose first value is [value 0] *)
val part_of : t -> (int -> int) -> int

(* is the tuple whose i-th value is [value i] there? *)
val mem_by : t -> (int -> int) -> bool

(* the same, the hint's leaf tried first, and left at the leaf seen *)
type hint
val hint : t -> hint
val mem_hint : t -> hint -> (int -> int) -> bool

(* mem_hint of the pair (a, b), for a tree of pairs, written out *)
val mem2_hint : t -> hint -> int -> int -> bool

(* false: it was there. Not while a range of the same part is walked
 * (a leaf's tuples move). *)
val add_by : t -> (int -> int) -> bool

(* add_by of the pair (a, b), written out *)
val add2 : t -> int -> int -> bool

(* [f keys base] for each tuple whose first n values are [value 0] to
 * [value (n - 1)], in order: its values keys.(base) to
 * keys.(base + w - 1). n is at least 1. *)
val iter_prefix : t -> int -> (int -> int) -> (int array -> int -> unit) -> unit

(* is there one? *)
val exists_prefix : t -> int -> (int -> int) -> bool
