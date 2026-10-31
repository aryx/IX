(* A sorted index (Index.mli, Relset.mli): the relation again, sorted
 * with some of its columns (the key) first, then the others, in a
 * B-tree (Btree). The tuples with a key's values are a range of it, in
 * the order of their other columns:
 *
 *    assign(P, Q), its index on Q: the tuples as (Q, P), sorted
 *
 *      ... (q7, p2) (q7, p5) (q7, p9) (q8, p1) ...
 *          \___ assign(_, q7): p2, p5, p9 ____/
 *
 * A lookup gives the tuples themselves (a leaf's values, the columns
 * in the index's order: [at] says where each column is), not their
 * numbers in the relation's rows: no second place to read.
 *
 * design:
 * That the other columns come out sorted is what Souffle's speed is
 * made of: in point_to(P, L) :- assign(P, Q), point_to(Q, L), from a
 * new assign(P, Q), Q's point_to(Q, L) come out by L, so the heads
 * point_to(P, L1), point_to(P, L2)... tested one after the other are
 * neighbours in the relation's own sorted set, the same leaf mostly
 * (Btree's hint).
 * The other kind, Hash_index, gives the tuples in the order added,
 * read in the rows (Datalog's): a lookup and the next tuple each a
 * miss of the cache, and the tests after them scattered; but adding a
 * tuple is writing a slot, where a sorted leaf moves the tuples after
 * it.
 *
 * others:
 * Souffle's index selection finds the fewest orders that serve every
 * lookup of the rules (Subotic et al., VLDB 2018): an order (Q, P, R)
 * serves a lookup on Q and one on (Q, P). Here an index is made for
 * each set of columns asked (Datalog_eval's index), at its first
 * lookup. A hash index is what databases call the other kind (hash
 * join, Gamma and Grace, the 1980s); System R's were B-trees. *)

type t

(* the index of a relation of an arity on the columns given (their
 * numbers, in order) *)
val create : int -> int array -> t

(* the tuple whose column c is [value c] added *)
val add : t -> (int -> int) -> unit

(* [f keys base] for each tuple whose key's i-th value is [key i], in
 * order: its column c is keys.(base + (at t).(c)). Not while a tuple
 * is added. *)
val iter : t -> (int -> int) -> (int array -> int -> unit) -> unit

(* is there one? *)
val exists : t -> (int -> int) -> bool

(* each column's place in a tuple that iter gives *)
val at : t -> int array

(* the part of the tuple whose column c is [value c] (Btree's parts:
 * domains add at once the tuples of different parts) *)
val part_of : t -> (int -> int) -> int
