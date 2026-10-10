(* A predicate's clauses as they are kept: a clause's variables
 * numbered (Prolog.Local), so that a call makes its own copy of the
 * body by filling an array, with no table to look a variable up in.
 *
 *     app([H|T], L, [H|R]) :- app(T, L, R).       as read
 *
 *     head  app('.'(#0, #1), #2, '.'(#0, #3))     as kept: #k is
 *     body  app(#1, #2, #3)                       Local k, nvars = 4
 *
 * Each call needs the clause with variables of its own (a recursive
 * predicate has many calls alive at once, each with its H and T): the
 * renaming of resolution. A call takes an array of 4 slots; the head
 * is unified with the arguments as it is kept, a #k met for the first
 * time taking the argument's term in its slot, with no variable made;
 * then the body alone is copied, each #k replaced by its slot, a slot
 * still empty by a new variable ([instantiate]).
 *
 * First-argument indexing is [may_match]: before a clause is tried,
 * its head's first argument is looked at against the call's. Calling
 * app([a], Y, Z), the first clause, whose first argument is [], is
 * not tried, and the second is then the last: no choice point is
 * left, and the recursion runs as a loop does. With the list unknown,
 * app(X, Y, [a]), both may match and a choice point stays: that is
 * the several answers. The WAM does the same by a switch compiled
 * for the predicate (Wam's switch_on_term).
 *
 * design:
 * The database is the program and the program's memory: assert adds
 * a clause while the program runs, retract erases one, and in the
 * standard's Prolog nothing else keeps a value through backtracking.
 * So the clauses are a list in order, added at either end, and a
 * clause erased is also marked, for the calls that still hold the
 * list they started with and must skip it. *)

type clause = {
  head : Prolog.term;
  body : Prolog.term;       (* true for a fact *)
  nvars : int;
  id : int;                 (* '$clause''s reference: what retract erases *)
  mutable erased : bool;
}

type pred = {
  name : string;
  arity : int;
  mutable clauses : clause list;
  mutable added : clause list; (* those put at the end since [clauses] was last asked, the last first *)
  mutable dynamic : bool;   (* declared, or made by assert: a call with no clause fails *)
}

(* its clauses, in order (read them by this: a clause added at the end
 * is kept apart until then, so that a file of facts is not copied once
 * for each of them) *)
val clauses : pred -> clause list

(* asserta (front), assertz *)
val add : pred -> front:bool -> clause -> unit

val erase : pred -> clause -> unit

(* a term's head and body (H :- B, or a fact), its variables numbered *)
val clause : Prolog.term -> clause

(* a head's name and arity; None: a number or a variable *)
val functor_of : Prolog.term -> (string * int) option

(* a kept term with the array's terms for its variables. A slot still
 * [unset] gets a new variable. *)
val unset : Prolog.term
val instantiate : Prolog.term array -> Prolog.term -> Prolog.term

(* could the clause's first argument unify with this one? (the clauses
 * that cannot are not tried, and leave no choice point) *)
val may_match : clause -> Prolog.term -> bool
