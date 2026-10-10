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
 * its body (_ in a negation: any value). *)

type arg = Const of int | Slot of int | Any

type relation = {
  name : string;
  arity : int;
  set : (int array, unit) Hashtbl.t;      (* its tuples, each once *)
  mutable all : int array list;           (* the same, the last added first *)
  mutable count : int;
  (* by the columns that are known (a bit each): their values to the tuples *)
  mutable indexes : (int * (int array, int array list ref) Hashtbl.t) list;
  mutable delta : int array list;         (* Datalog_eval's: the last round's new tuples *)
  mutable fresh : int array list;         (* this round's *)
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

(* the values of the columns whose bit is in the mask *)
val project : int -> int array -> int array
