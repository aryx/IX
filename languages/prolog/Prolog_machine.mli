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
 * [read_file] are its host's.
 *
 * Unification makes two terms one by binding variables, of either:
 *
 *     f(X, b, g(X)) = f(a, Y, Z)        X = a, Y = b, Z = g(a)
 *     f(X, b) = f(a, c)                 fails (and X is unbound again)
 *     X = f(X)                          succeeds: no occurs check
 *
 * It is a walk down both terms at once: the same atom, the same
 * functor and arity and the arguments in turn; a variable met on
 * either side is bound to what faces it ([bind]). A call is that,
 * between the goal and a clause's head, and it does at once what
 * other languages have several things for: passing an argument,
 * returning a result (through a variable of the caller), taking a
 * structure apart, making one.
 *
 * The machine's state, on a small program:
 *
 *     parent(tom, bob).  parent(bob, ann).  parent(bob, pat).
 *     grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
 *     ?- grandparent(tom, W).
 *
 *     the goals to prove               choice points       trail
 *     grandparent(tom, W)              none                empty
 *     parent(tom, Y), parent(Y, W)     none                empty
 *     parent(bob, W)                   none                empty
 *     none: an answer, W = ann         parent(bob, W)'s    W
 *                                      third clause
 *     another is asked: the choice point is taken, W unbound
 *     none: an answer, W = pat         none                empty
 *
 * For parent(tom, Y) only the first clause may match (Prolog_db's
 * may_match), so no choice point is left and Y = bob is not trailed:
 * nothing could ask to undo it. For parent(bob, W) two may: the
 * second is taken and the third remembered with the trail's height;
 * W, older than that choice point, is trailed when it is bound, and
 * unbound when the choice point is taken. The second answer leaves
 * no choice point: [has_more] is false and the prompt does not ask.
 *
 * The same run seen from outside, by -trace (tests/trace.out; _G874
 * is W). A goal is a box with four ports: entered by Call, left by
 * Exit when proved or by Fail; entered again by Redo when something
 * after it failed and it has another clause, and left again:
 *
 *     Call: grandparent(tom,_G874)
 *       Call: parent(tom,_G875)
 *       Exit: parent(tom,bob)
 *       Call: parent(bob,_G874)
 *       Exit: parent(bob,ann)
 *     Exit: grandparent(tom,ann)
 *       Redo: parent(bob,_G874)         (another answer is asked)
 *       Exit: parent(bob,pat)
 *     Exit: grandparent(tom,pat)
 *
 * The cut (!) is the one thing that removes choice points: those
 * made since the clause it is in was called, the clause's other
 * clauses with them. That is why a goal carries a height: the
 * number of choice points there were then, to cut back to.
 *
 * design:
 * The continuation as data. An interpreter in OCaml would by nature
 * prove a body by a recursive function, a goal's proof inside the
 * proof of the clause that called it; but then a failure deep inside
 * must come back to a choice made far above and since returned from,
 * and OCaml's stack cannot go back there. So what is left to do is a
 * value, as in mini-scheme's machine, where call/cc asks the same,
 * and in Talk, where a program waits for a line: a step takes the
 * first goal, a choice point is a copy of the pointer, and a
 * recursion 20,000 calls deep is a list in the heap.
 *
 * cs-history:
 * Unification is Alan Robinson's (1965): the step that let a machine
 * do logic without trying every instance of a formula, by computing
 * the most general way two of them can be made equal. His algorithm
 * refuses to bind a variable to a term that holds it (the occurs
 * check): X = f(X) has no finite solution. Prolog left the check out,
 * since it makes every binding cost the size of a term and app's
 * linear time quadratic; the logic is unsound for it, in programs
 * nobody writes by accident, and Colmerauer's Prolog II made the
 * infinite term a meaning instead. The four ports are Lawrence
 * Byrd's (Edinburgh, 1980), and every Prolog's debugger since.
 *
 * modern:
 * The trail and the choice points are the WAM's ideas, kept here
 * with the terms as terms: the binding trailed only when a choice
 * point is younger than the variable, the clauses that cannot match
 * left out. What the WAM adds is compiling the clause (Wam_compile);
 * this machine copies its body at each call.
 *
 * References: J. A. Robinson, "A Machine-Oriented Logic Based on the
 * Resolution Principle" (Journal of the ACM, 1965); Lawrence Byrd,
 * "Understanding the Control Flow of Prolog Programs" (Logic
 * Programming Workshop, 1980); Sterling and Shapiro, "The Art of
 * Prolog" (1986), the chapters on the computation model and on the
 * cut. *)

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
