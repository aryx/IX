(* mini-prolog: Prolog (docs/plans/plan_prolog.md) on a terminal: files
 * consulted, goals run, a prompt. Its usage: [help] in CLI.ml, what
 * mini-prolog -h prints.
 *
 * A Prolog program is facts and rules, and running it is asking a
 * question: the machine looks for values of the question's variables
 * that make it follow from them, and on demand for the next ones.
 *
 *     app([], L, L).                          appending to [] changes
 *     app([H|T], L, [H|R]) :- app(T, L, R).   nothing; else the head
 *                                             is kept, the tails are
 *                                             appended
 *     ?- app([a], [b], Z).      Z = [a,b]
 *     ?- app(X, Y, [a,b]).      X = [], Y = [a,b]     and, a ; typed
 *                               X = [a], Y = [b]      for each next
 *                               X = [a,b], Y = []     one, two more
 *
 * The same two clauses append two lists and split one in every way:
 * a clause says what is true, not which arguments are given. Two
 * things do it, and no other language of ix has them. Unification
 * (Prolog_machine): a call and a clause's head are made the same term
 * by binding variables on either side, where ML's match binds only
 * the pattern's. Backtracking: when several clauses fit, the first is
 * taken and the others remembered (a choice point); a failure later
 * undoes the bindings made since and takes the next.
 *
 *     a text (a file, -g, the prompt)
 *        | Prolog_read     a clause at a time, by the operators of
 *        |                 the moment
 *     Prolog.term  ------- to_string: write, writeq, an answer
 *        |
 *        |-- a clause      Prolog_db: kept, its variables numbered
 *        '-- a goal        proved by one of two machines
 *
 *     Prolog_machine                   Wam_machine (-wam)
 *       a clause is a term;              a clause is compiled
 *       the goals left and the           (Wam_compile) to Wam's
 *       choice points are data;          instructions; registers,
 *       the four ports (-trace)          environments (-S: the code)
 *                 \                      /
 *         unification and its trail, the database, and the
 *         built-ins: Prolog_builtins (in OCaml), Prolog_prelude
 *         (in Prolog), the same for both
 *
 * It is here for those two machines, beside Pascal's P-machine
 * (Pmachine), Forth's threaded code (Forth) and Smalltalk's
 * bytecode: each language is known by a machine made for it. Its
 * reader also serves mini-datalog, whose text is Prolog's without
 * compound terms, run the other way: from the facts up.
 *
 * cs-history:
 * Prolog (PROgrammation en LOGique) is Alain Colmerauer's and
 * Philippe Roussel's, at Marseille in 1972, made to converse with a
 * computer in French: the rules were a grammar's and the questions
 * sentences. The logic is Alan Robinson's resolution (1965), a single
 * rule of inference fit for a machine, with unification at its
 * centre. Robert Kowalski, at Edinburgh, saw that on clauses with one
 * conclusion it can be read as a procedure call: to prove the head,
 * prove the body's goals from left to right. A logic that was also a
 * programming language, if one fixes the order: the clauses as
 * written, the first that fits, depth first.
 *
 * evolution:
 * Marseille's Prolog was an interpreter. David H. D. Warren's for the
 * DEC-10 (Edinburgh, 1977) compiled the clauses to machine code and
 * ran about as fast as the Lisp of the same machine; its syntax and
 * its built-in predicates, Edinburgh's, are the ones every Prolog
 * since has, and this one. In 1983 he described an abstract machine
 * to compile to, the WAM (Wam). Japan's Fifth Generation project
 * (1982) took logic programming for its base and made the language
 * famous for a decade. The ISO standard is of 1995. Today's free
 * Prolog is SWI-Prolog (Jan Wielemaker, since 1987). What came of it
 * elsewhere: Datalog in the databases and the program analyses, and
 * Erlang, first written in Prolog (Joe Armstrong, 1986), which kept
 * its atoms, its capitals for variables and its full stop.
 *
 * terminology:
 * An atom is a name that stands for itself (tom, []); a variable
 * starts with a capital or _; a compound term is a functor and its
 * arguments, parent(tom, X), said parent/2 by its name and arity. A
 * clause is a fact (a term and a dot) or a rule (Head :- Body); the
 * clauses of one name and arity are a predicate; a goal is a term
 * asked to be proved, a query the goal typed. The same term is data
 * and program by where it stands, as a list is in Lisp.
 *
 * References: Alain Colmerauer and Philippe Roussel, "The Birth of
 * Prolog" (History of Programming Languages II, 1993); Robert
 * Kowalski, "Algorithm = Logic + Control" (Communications of the ACM,
 * 1979); W. F. Clocksin and C. S. Mellish, "Programming in Prolog"
 * (Springer, 1981): the book the language was learnt from; Leon
 * Sterling and Ehud Shapiro, "The Art of Prolog" (MIT Press, 1986);
 * ISO/IEC 13211-1 (1995). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
