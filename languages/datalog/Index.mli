(* A relation's index on some of its columns (the key): the tuples that
 * have a key's values, of its relation's kind (Relset.mli):
 *
 *   Hash_index: a key to the numbers of its tuples, a chain, the
 *   tuples then read in the relation's rows, in the order added
 *   Tree_index: the relation again, sorted on the key first, the
 *   tuples read in its leaves, in the order of their other columns
 *
 * Either way a lookup gives each tuple as an array, where it starts,
 * and where each column is in it, so that the join reads both alike. *)

type t

(* an index of a relation of an arity on the columns given (their
 * numbers, in order), sorted or hashed *)
val create : sorted:bool -> int -> int array -> t

(* the tuple numbered [id], whose column c is [value c], added. The
 * tuples are added in their numbers' order. *)
val add : t -> (int -> int) -> int -> unit

(* [f keys base] for each tuple whose key's i-th value is [key i]: its
 * column c is keys.(base + (at t).(c)); [rows] are the relation's
 * (Datalog's), of its arity. Not while a tuple is added. *)
val iter : t -> int array -> int -> (int -> int) -> (int array -> int -> unit) -> unit

(* a hashed index's chain, for a caller that walks it (a compiled
 * loop): the number of the last tuple with the key, -1 if none; the
 * one added before it with the same key. Not of a sorted index *)
val first : t -> (int -> int) -> int
val next : t -> int -> int

(* first and exists of a key in an array; a tuple added by its own
 * columns (no closure called for each value) *)
val first_array : t -> int array -> int
val exists_array : t -> int array -> bool
val add_array : t -> int array -> int -> unit

(* is there one? *)
val exists : t -> (int -> int) -> bool

(* each column's place in a tuple that iter gives *)
val at : t -> int array

(* the part of the tuple whose column c is [value c] (Tuples's and
 * Btree's 64): domains add at once the tuples of different parts, after
 * [reserve] for the largest number added *)
val part_of : t -> (int -> int) -> int
val reserve : t -> int -> unit
