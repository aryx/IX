(* What mini-prolog has before a program is read and that is written in
 * Prolog: the lists' predicates (append, member, length...), the ones
 * with several answers over a built-in with one (clause and retract
 * over '$clauses', between, bagof and setof over findall), and the
 * translation of a grammar's rule (-->) into a clause. Its helpers'
 * names begin with $: the tracer does not show them. *)

val text : string
