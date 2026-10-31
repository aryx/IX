(* A Datalog program (docs/plans/plan_prolog.md, "Datalog"): relations,
 * the facts in them, the rules that add to them, the queries. Its text
 * is Prolog's without compound terms, read by Prolog_read:
 *
 *   assign(p, q).                               a fact
 *   point_to(P, L) :- assign(P, Q), point_to(Q, L).     a rule
 *   live(V, P) :- succ(P, Q), live(V, Q), \+ def(V, P). a negation (or not(...))
 *   other(X, Y) :- node(X), node(Y), X \= Y.    a comparison (= \= < > =< >=)
 *   ?- point_to(p, L).                          a query; or, on a line, point_to(p, L)?
 *
 * A constant is an atom or an integer, kept as a number (a symbol); a
 * tuple is an array of them. A rule must be safe: a variable of its
 * head, of a negation or of a comparison is also in a positive atom of
 * its body (_ in a negation: any value).
 *
 * Safety is what keeps the tables finite. big(X) :- \+ small(X) asks
 * for everything that is not small: of what? A variable gets its
 * values from a table, and a negation or a comparison only refuses
 * some of them; "the variable X of a negation is in no positive atom
 * of the body" is the message.
 *
 * The same thing by the database's words (mini-chidb is ix's): a
 * relation is a table, a tuple a row, a fact an INSERT; a rule is a
 * view, its body a join of tables on the variables they share, its
 * head the SELECT's columns; and [indexes] are a database's, one for
 * each set of columns a join comes with already known:
 *
 *     path(X, Y) :- path(X, Z), edge(Z, Y).
 *
 *     for each path tuple (X, Z): edge is asked for its tuples whose
 *     first column is that Z: an index of edge by column 0 (the
 *     mask 1), from a value to the tuples that have it there
 *
 * design:
 * A constant is a small integer and a tuple an array of them: the
 * atom's text is looked up once, when the fact is read ([symbol]),
 * and after that a join compares and hashes integers. It is the
 * interning of a compiler's symbol table and of Lisp's atoms, and
 * most of what makes a million tuples affordable. *)

type arg = Const of int | Slot of int | Any

type relation = {
  name : string;
  arity : int;
  set : Tuples.t;                         (* its tuples, each once *)
  (* the same, numbered in the order added: tuple i is rows.(i * arity)
   * to rows.(i * arity + arity - 1) *)
  mutable rows : int array;
  mutable count : int;
  (* by the columns that are known (a bit each, and their numbers): their
   * values to the tuples *)
  mutable indexes : (int * int array * Index.t) list;
  (* Datalog_eval's: the last round's new tuples are those numbered from
   * delta_from to delta_to - 1; this round's, from delta_to on *)
  mutable delta_from : int;
  mutable delta_to : int;
  mutable stratum : int;
  mutable given : int;                    (* its facts in the text *)
  mutable rules : int;                    (* the rules with it as head *)
}

type atom = { rel : relation; args : arg array }
type literal = Pos of atom | Neg of atom | Cmp of string * arg * arg
type rule = { head : atom; body : literal list; slots : int; at : string (* file:line *) }
type query = { goal : atom; names : string array (* a slot's variable *) }

type t = {
  symbols : (string, int) Hashtbl.t;
  mutable terms : Prolog.term array;      (* a symbol's atom or integer *)
  mutable nsymbols : int;
  relations : (string, relation) Hashtbl.t; (* by name/arity *)
  mutable rule_list : rule list;          (* in the text's order *)
  mutable queries : query list;
}

(* a text's mistake: the message, where (file:line) *)
exception Error of string * string

val create : unit -> t

(* a text's facts, rules and queries added; its name, for a mistake's place *)
val load : t -> from:string -> string -> unit

(* one query, as -q gives it: p(X, a) *)
val query : t -> string -> query

val symbol : t -> Prolog.term -> int
val relation : t -> string -> int -> relation

(* a tuple as a fact: name(a,b). *)
val show : t -> relation -> int array -> string

(* a tuple added; false: it was there *)
val add : relation -> int array -> bool

(* a tuple's row added, not to the set or the indexes (the caller
 * adds them: Datalog_eval's on several domains); its number *)
val append : relation -> int array -> int

(* the numbers of the mask's columns, in order, for an arity *)
val columns : int -> int -> int array

(* the i-th tuple's j-th value *)
val get : relation -> int -> int -> int

(* every tuple, the last added first *)
val tuples : relation -> int array list
