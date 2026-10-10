(* The WAM (Wam's instructions) run: the argument registers, the
 * environments, the choice points, the trail.
 *
 * - The registers X (the first are a call's arguments A1...) are one
 *   array; P is an array of instructions and an index in it; CP is the
 *   address a clause returns to.
 * - An environment has the permanent variables, the one before it and
 *   the CP of its clause: the continuation is the chain of them.
 * - A choice point has the arguments, the environment, the CP, the
 *   trail's height, and the address to go on at: backtracking puts
 *   them back and goes there.
 * - The trail, the bindings, unification and the built-ins are the
 *   first machine's (Prolog_machine): this one is put in it as its
 *   engine, and the clauses stay Prolog_db's, compiled when a predicate
 *   is first called and when its clauses have changed since.
 * - call/N of a conjunction, a disjunction... compiles a clause for it,
 *   its goals the clause's arguments; of anything else, loads the
 *   arguments and jumps.
 * - catch/3 marks its environment; throw looks for a mark along the
 *   chain of environments, so a catch whose goal has ended is not
 *   found. findall/3 is two clauses over a bag in OCaml.
 * No tracer: the four ports are the first machine's. *)

type t

(* the machine [m] runs its goals by, from now on: Prolog_machine.solve,
 * more and once are this one's; m.steps counts the calls *)
val install : Prolog_machine.t -> t

(* a predicate's code, compiled now if it was not (Wam_compile.listing);
 * None: no such predicate, or one in OCaml *)
val listing : t -> string -> int -> string option
