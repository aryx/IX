(* mini-datalog: Datalog (docs/plans/plan_prolog.md) on a terminal:
 * files of facts and rules, run to their fixpoint, queries answered.
 * Its usage: [help] in CLI.ml, what mini-datalog -h prints.
 *
 *     edge(a, b). edge(b, c). edge(c, a). edge(c, d).     facts
 *     path(X, Y) :- edge(X, Y).                           rules
 *     path(X, Y) :- path(X, Z), edge(Z, Y).
 *     node(X) :- edge(X, _).   node(Y) :- edge(_, Y).
 *     apart(X, Y) :- node(X), node(Y), \+ path(X, Y).
 *
 *     mini-datalog -q 'path(a, X)' graph.dl
 *         path(a,a). path(a,b). path(a,c). path(a,d).
 *     mini-datalog -q 'apart(d, X)' graph.dl
 *         apart(d,a). apart(d,b). apart(d,c). apart(d,d).
 *
 * The text is a Prolog program's and mini-prolog would read it, and
 * not end: asked path(a, X), its second rule calls path again before
 * anything else, for ever; with that rule turned round it goes round
 * the cycle a b c and gives the same answers again without end.
 * Prolog goes from the question down, one way at a time. Here the
 * question comes last: the facts are put in tables, every rule adds
 * what it can to them until a whole round adds nothing (12 paths,
 * here), and a query is then a look in a table. No
 * term is ever made, only constants moved about, so the tables are
 * finite and it always ends; nothing is found twice; and the order of
 * the rules, or of a body's atoms, changes the time and no answer.
 *
 *     the files                  Prolog_read (mini-prolog's reader)
 *        | Datalog         facts, rules and queries checked (safe?)
 *     Datalog.t            relations: tables of tuples of symbols
 *        | Datalog_eval    the strata, then rounds to the fixpoint
 *     the tables full  --- answers: the tuples a query matches
 *
 * In ix it is the language program analyses are written in. A
 * compiler writes its program out as facts (mini-cc -facts and -flow,
 * mini-ml -facts and -flow), and an analysis is a file of rules
 * (analyses/): Andersen's pointer analysis in 15, liveness in three,
 * the dominators, who calls whom. A dataflow analysis is a fixpoint
 * over a program's graph, which is what a compiler's own pass
 * computes with a worklist (mini-cc's Opti, mini-ml's Alloc): the
 * tests run both and ask, in Datalog, for the tuples one has and the
 * other has not.
 *
 * cs-history:
 * Datalog is Prolog seen from the databases: a fact is a row, a
 * predicate a table, a rule a view, and a rule that names itself the
 * recursive query SQL then lacked (the paths of a graph, the parts
 * of a part). It came of the meetings on logic and data bases that
 * Herve Gallaire and Jack Minker began at Toulouse in 1977. What a
 * program means was settled before: Maarten van Emden and Robert
 * Kowalski (1976) showed that the facts that follow from a set of
 * clauses are the least set closed under the rules, reached by
 * applying them from nothing. Prolog computes that set from the top
 * and may not end; Datalog computes it as it is defined.
 *
 * comeback:
 * The deductive databases of the 1980s found no market, and SQL took
 * the idea in as its recursive queries (WITH RECURSIVE, SQL:1999).
 * Datalog came back from another side in the 2000s: a points-to
 * analysis of a large Java program is a few recursive rules over
 * millions of facts, and saying it as rules, with an engine made for
 * such joins, beat writing it by hand: bddbddb (John Whaley and
 * Monica Lam, 2004), Doop (Martin Bravenboer and Yannis Smaragdakis,
 * 2009), Souffle, and the query language of CodeQL.
 *
 * References: Stefano Ceri, Georg Gottlob and Letizia Tanca, "What
 * You Always Wanted to Know About Datalog (And Never Dared to Ask)"
 * (IEEE Transactions on Knowledge and Data Engineering, 1989): the
 * survey to read first; M. H. van Emden and R. A. Kowalski, "The
 * Semantics of Predicate Logic as a Programming Language" (Journal of
 * the ACM, 1976); Lars Ole Andersen, "Program Analysis and
 * Specialization for the C Programming Language" (DIKU, 1994), the
 * pointer analysis; Martin Bravenboer and Yannis Smaragdakis,
 * "Strictly Declarative Specification of Sophisticated Points-to
 * Analyses" (OOPSLA, 2009). *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
