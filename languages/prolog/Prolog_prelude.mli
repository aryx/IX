(* What mini-prolog has before a program is read and that is written in
 * Prolog: the lists' predicates (append, member, length...), the ones
 * with several answers over a built-in with one (clause and retract
 * over '$clauses', between, bagof and setof over findall), and the
 * translation of a grammar's rule (-->) into a clause. Its helpers'
 * names begin with $: the tracer does not show them.
 *
 *     greeting --> [hello], name.       a grammar's rules, as written
 *     name --> [world].
 *
 *     greeting(A,B) :- A=[hello|C], name(C,B).     as kept (listing)
 *     name(A,B) :- A=[world|B].
 *
 *     ?- phrase(greeting, [hello, world]).         true
 *
 * A non-terminal is a predicate with two arguments more: the list of
 * words where it starts, and what is left of it after. So a grammar
 * is a program with no parser to write: Prolog's search tries the
 * rules, and backtracking is the grammar's ambiguity.
 *
 * cs-history:
 * This is what Prolog was made for: Colmerauer's group parsed French
 * with such rules before the language had a name. The notation and
 * its translation as above are Fernando Pereira's and David Warren's
 * definite clause grammars (1980). mini-yacc's parsers are the other
 * way to run a grammar: a table made beforehand, one rule decided at
 * each token and never taken back, and so only for the grammars that
 * allow it.
 *
 * References: F. C. N. Pereira and D. H. D. Warren, "Definite Clause
 * Grammars for Language Analysis" (Artificial Intelligence, 1980). *)

val text : string
