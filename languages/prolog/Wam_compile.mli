(* Prolog's clauses compiled to the WAM's instructions (Wam): a clause's
 * code, a predicate's index over its clauses, and the listing.
 *
 * - A variable is permanent (Yn, in the environment) when it is in more
 *   than one chunk: a chunk ends at a call, the head is in the first.
 *   The others are temporary (Xn). A built-in in OCaml is run in line
 *   and ends no chunk.
 * - The temporaries are above every argument register the clause uses,
 *   so loading a goal's arguments cannot spoil one: simple, and a move
 *   more than Warren's allocation for an argument that stays in place.
 * - A structure inside a structure has a temporary of its own: in the
 *   head it is matched after its parent (unify_variable Xn, then
 *   get_structure f/n, Xn), in the body it is built before it.
 * - (A ; B), (C -> T ; E), (C -> T) and \+ G are a call to a predicate
 *   made for them, of the variables they have; a cut in them, and one
 *   after a call, cut to the level get_level kept. *)

type ctx = {
  m : Prolog_machine.t;                    (* for its built-ins: which calls are in line *)
  preds : (string, Wam.pred) Hashtbl.t;    (* by Prolog_machine.key: one record a predicate *)
  mutable xneed : int;                     (* the X registers the code made so far needs *)
  mutable aux : int;                       (* the '$aux' made *)
}

val create : Prolog_machine.t -> ctx

(* the predicate's record, made if it is not there *)
val intern : ctx -> string -> int -> Wam.pred

val clause : ctx -> Prolog_db.clause -> Wam.instr array

(* the predicate's entry made for these clauses (a clause compiled
 * before is not compiled again) *)
val link : ctx -> Wam.pred -> Prolog_db.clause list -> unit

val fail_addr : Wam.addr

(* a predicate's code as a text: its index, each clause's instructions,
 * then the predicates the compiler made for it *)
val listing : Prolog.ops -> Wam.pred -> string
