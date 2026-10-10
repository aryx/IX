(* Prolog's machine (docs/plans/plan_prolog.md, decision 2): a goal
 * proved by trying its predicate's clauses in order, the first whose
 * head unifies; what is left to prove and what is left to try are both
 * data, not OCaml's stack.
 *
 * - The continuation ([cont]) is the goals still to prove, each with
 *   the height of the choice points its cut cuts back to.
 * - A choice point is a continuation to go on with when the present one
 *   fails, and the trail's height then: the bindings made since are
 *   undone first.
 * - A clause is kept with its variables numbered (Prolog_db); a call
 *   unifies its arguments with the head as it is kept, and only the
 *   body is copied.
 * - throw looks in the continuation for the catch/3 it is still inside,
 *   so a catch whose goal has ended is not found.
 *
 * It does no input or output of its own: [print], [read_line] and
 * [read_file] are its host's. *)

(* an uncaught throw/1 (the ball, copied), and halt *)
exception Throw of Prolog.term
exception Halt of int

type cont =
  | Done                                  (* an answer *)
  | Failed                                (* no answer, or no other *)
  | Goal of Prolog.term * int * cont      (* a goal, what its cut cuts to, then *)
  | Try of call * Prolog_db.clause list * bool (* a call's clauses left; true: tried again *)
  | Cut of int * cont
  | Native of (unit -> bool) * cont       (* OCaml's: false fails *)
  | Catch of catch * cont                 (* the end of a catch/3's goal *)
and call = { goal : Prolog.term; args : Prolog.term list; next : cont; depth : int }
and catch = { catcher : Prolog.term; recovery : Prolog.term; height : int; trail : int }

(* the trail's size when it was made, and [young] then *)
type choice = { mark : int; alt : cont; before : int }

(* another machine for the same programs (Wam_machine): what [solve], [more],
 * [has_more] and [once] are then *)
type engine = {
  e_solve : Prolog.term -> bool;
  e_more : unit -> bool;
  e_has_more : unit -> bool;
  e_once : Prolog.term -> bool;
}

type t = {
  ops : Prolog.ops;
  procs : (string, proc) Hashtbl.t;       (* by [key] *)
  refs : (int, Prolog_db.pred * Prolog_db.clause) Hashtbl.t; (* the clauses '$clauses' gave out *)
  globals : (string, Prolog.term) Hashtbl.t; (* nb_setval's *)
  mutable cont : cont;
  mutable choices : choice list;
  mutable height : int;                   (* the choices' number *)
  mutable trail : Prolog.var list;        (* the variables bound, the last first *)
  mutable trail_size : int;
  mutable young : int;                    (* a variable made after this one is not trailed *)
  mutable steps : int;
  mutable trace : bool;
  mutable depth : int;                    (* the tracer's *)
  mutable print : string -> unit;
  mutable warn : string -> unit;          (* a consulted text's mistakes *)
  mutable read_line : unit -> string option;
  mutable read_file : string -> string;   (* Failure: no such file *)
  mutable clock : unit -> int;            (* milliseconds *)
  mutable inits : Prolog.term list;       (* initialization/1's goals, for the text's end *)
  mutable loading : (string, unit) Hashtbl.t; (* the predicates the text being consulted defined *)
  mutable errors : int;                   (* the mistakes said by [warn] *)
  mutable engine : engine option;
}
and proc =
  | Control of (t -> Prolog.term array -> int -> cont -> unit) (* sets the continuation itself *)
  | Det of (t -> Prolog.term array -> bool)                    (* one answer or none *)
  | Pred of Prolog_db.pred

(* a machine with the control constructs only: true, fail, the cut, the
 * comma, the semicolon, ->, \+, call/1 to call/8, findall/3, catch/3,
 * throw/1 (Prolog_builtins.create: with the rest) *)
val create : unit -> t

(* a goal's first answer (its variables are then bound), and the next
 * one; false: none. An error not caught is Throw. *)
val solve : t -> Prolog.term -> bool
val more : t -> bool

(* could [more] find another? (no: the answer is known to be the last) *)
val has_more : t -> bool

(* a goal proved once, inside a built-in: the machine's state is kept
 * and found again after *)
val once : t -> Prolog.term -> bool

val unify : t -> Prolog.term -> Prolog.term -> bool

(* would they unify? (nothing is left bound) *)
val unifiable : t -> Prolog.term -> Prolog.term -> bool
val bind : t -> Prolog.var -> Prolog.term -> unit

(* the bindings made since the trail had this size, undone *)
val undo : t -> int -> unit

(* the table's key: name/arity *)
val key : string -> int -> string
val indicator : string -> int -> Prolog.term

val define : t -> string -> int -> (t -> Prolog.term array -> bool) -> unit
val find_pred : t -> string -> int -> Prolog_db.pred option

(* made if it is not there; a built-in's name is a permission error *)
val pred : t -> string -> int -> Prolog_db.pred
val add_clause : t -> front:bool -> Prolog.term -> unit

(* the standard's error(Formal, _), to raise *)
val error : Prolog.term -> exn
val instantiation_error : unit -> exn
val type_error : string -> Prolog.term -> exn

(* call/N's goal: the term with these arguments more *)
val with_args : Prolog.term -> Prolog.term list -> Prolog.term
