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
 *   after a call, cut to the level get_level kept.
 *
 *     len([], 0).
 *     len([_|T], N) :- len(T, M), N is M + 1.
 *
 *     the second clause (mini-prolog -S):
 *         allocate 2                 Y1 and Y2 will be needed after
 *         get_list A1                the call: an environment
 *         unify_void 1               _: nothing kept
 *         unify_variable X4          T, used before the call only
 *         get_variable Y1, A2        N, used after it: permanent
 *         put_value X4, A1
 *         put_variable Y2, A2        M, new: made in the environment
 *         call len/2                 the registers are lost here
 *         put_value Y1, A1           N
 *         put_structure +/2, A2      M + 1, built
 *         unify_value Y2
 *         unify_constant 1
 *         builtin is/2               in line: no call, no chunk ended
 *         deallocate
 *         proceed
 *
 * A call may use every register, so what a clause needs after one
 * cannot stay in them: that is all the difference between Xn and Yn,
 * and the reason a clause with a single goal (Wam's app) has no
 * allocate at all. It is the caller-saved register of a C compiler,
 * decided by the same question, what is alive across a call, and
 * the environment is the frame; mini-cc and mini-ml answer it for a
 * real machine's registers.
 *
 * others:
 * Warren's compiler, and those after it, go further in three places
 * this one does not. Registers are allocated so that an argument
 * already in its place is not moved (here T goes through X4 to A1).
 * The environment is trimmed: its variables are ordered by their
 * last use and it shrinks at each call, so the last call can run in
 * the caller's space. And some index on other arguments than the
 * first, when the calls made show the need (SWI-Prolog). *)

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
