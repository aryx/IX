(* A cursor, which is a position in a B-tree that moves in key order.
 *
 * chidb's cursor is a snapshot. Opening it reads the whole tree into an
 * array of its entries in key order, and moving it moves along the
 * array (an index's internal entries come between those of their
 * children):
 *
 *      entries:  [ (1, row) (2, row) (3, row) ... ]      pos: -1, then 0 .. n-1
 *
 * Opening a cursor costs a read of the whole tree, and an insertion
 * made after the opening is not seen. chidb's statements never read a
 * tree they write, so this is never visible. The textbook cursor is a
 * stack of (page, cell) positions from the root, moved in place (see
 * the tutorial, §6, and its exercise 1). Seeks are linear, as chidb's
 * are. *)

type entry =
  | Row of { key : int; data : Bytes.t }      (* a table's: primary key, record *)
  | Entry of { key : int; pkey : int }        (* an index's: value, primary key *)

type t

(* the comparisons a seek positions by: on the first entry = k, > k or
 * >= k, or on the last entry < k or <= k *)
type seek = Eq | Gt | Ge | Lt | Le

val open_ : Btree.t -> int -> t

(* the tree's root page *)
val root : t -> int

(* moves to the first entry; returns false (and leaves the cursor
 * unpositioned) if there is none *)
val rewind : t -> bool

(* moves to the next or previous entry; returns false, and does not
 * move, at an end *)
val next : t -> bool
val prev : t -> bool

(* returns false, and does not move, if no entry qualifies *)
val seek : t -> seek -> int -> bool

(* the current entry; raises Invalid_argument if the cursor is
 * unpositioned *)
val current : t -> entry
