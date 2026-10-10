(* A predicate's clauses as they are kept: a clause's variables
 * numbered (Prolog.Local), so that a call makes its own copy of the
 * body by filling an array, with no table to look a variable up in. *)

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
