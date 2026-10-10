(* A Datalog program run: every rule applied until no tuple is new, the
 * least fixpoint. It ends on any program (no term is made, so the
 * tuples are finite), and neither the rules' order nor a body's changes
 * what is found.
 *
 * - The strata first: a relation that another negates is computed whole
 *   before it. A negation through a recursion has no such order, and is
 *   refused.
 * - In a stratum, semi-naive: after a first round of every rule, a rule
 *   is run again only with one of its body's atoms taken from the last
 *   round's new tuples (once for each atom of the stratum's relations);
 *   a rule none of whose atoms is new can find nothing new. [naive]
 *   runs every rule on everything each round: the definition, kept to
 *   check the other by.
 * - A body is joined in the order written (the new tuples' atom
 *   first), each atom looked up by the columns already known, in an
 *   index made the first time those columns are asked for. *)

type stats = {
  mutable rounds : int;
  mutable firings : int;      (* a rule's body satisfied once *)
  mutable derived : int;      (* of them, a tuple that was new *)
  mutable lookups : int;
}

(* Datalog.Error: not stratified *)
val run : naive:bool -> Datalog.t -> stats

(* a query's answers: the tuples of its relation that match, as facts,
 * sorted *)
val answers : Datalog.t -> Datalog.query -> string list
