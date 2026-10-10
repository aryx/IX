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
 * No tracer: the four ports are the first machine's.
 *
 *     the registers             the environments     the choice points
 *     X1 X2 X3 ...              (the calls' chain)   (the youngest first)
 *      = A1 A2 A3, a call's      Y1 Y2 ...            A1 ... An, saved
 *        arguments               CP: where its        the environment
 *     P   the instruction          clause returns     CP
 *     CP  where proceed goes     the one before       the trail's height
 *                                                     the next clause
 *
 * A call is: load the Ai (put), set CP to the next instruction, jump.
 * A clause that calls more than once saves CP in an environment
 * (allocate), since its own calls will set it again, and takes it
 * back (deallocate) before its last call, which is then a jump
 * (execute) that returns straight to the clause's caller. A clause
 * that calls nothing ends by proceed: P becomes CP. It is a real
 * processor's calling convention, arguments in registers and a link
 * register saved by the functions that are not leaves: arm's, as
 * mini-cc and mini-ml compile to.
 *
 * What a processor has not is the third column. try saves the
 * arguments, since the clause tried may overwrite them and the next
 * one needs them as they were; a failure anywhere puts back the
 * youngest choice point's registers, unbinds what the trail says and
 * jumps to its next clause; trust, the last clause's, removes it
 * first. The two chains are apart: an environment may be long
 * returned from and still be reached from a choice point, which is
 * why the report keeps both in one stack that a choice point
 * freezes, and why here, OCaml's records, they are simply not freed
 * while something points to them. *)

type t

(* the machine [m] runs its goals by, from now on: Prolog_machine.solve,
 * more and once are this one's; m.steps counts the calls *)
val install : Prolog_machine.t -> t

(* a predicate's code, compiled now if it was not (Wam_compile.listing);
 * None: no such predicate, or one in OCaml *)
val listing : t -> string -> int -> string option
