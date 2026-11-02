(* mini-datalog -dotnet (plan_dotnet_languages.md, stage 6, decision 5):
 * a program's rules compiled to a .NET assembly, Souffle's way. What
 * the interpreter decides as it runs (Datalog_eval), the compiler
 * decides once: the strata, each rule's plans (its atoms' order, the
 * columns known at each, where each test goes), and writes the joins
 * they say as nested loops in IL:
 *
 *     path(X, Y) :- path(X, Z), edge(Z, Y).    from path's new tuples
 *
 *     for id in path's delta_from .. delta_to:     a scan of a range
 *       X = get(path, id, 0); Z = get(path, id, 1)
 *       for each id' in lookup(edge, mask 1, [Z]):   an index's tuples
 *         Y = get(edge, id', 1)
 *         add(path, [X, Y])
 *
 * and each stratum's rounds: the rules on everything, then while a
 * head has new tuples, each rule again with one of its atoms from them
 * (semi-naive). The relations are not compiled: they are mini-datalog's
 * own (Datalog, Relset, Index), compiled by mini-ml -dotnet into
 * datalog_rt.dll with Datalog_rt, the calls the code makes (get,
 * lookup, add, the rounds' ranges), and the program's entry: it reads
 * the rules' texts (kept in the assembly: their facts, their queries)
 * and the facts files it is given, runs the compiled rules, answers
 * the queries as the interpreter does. Souffle splits it so too: its
 * C++ for the rules, a library for the relations.
 *
 *     mini-datalog -dotnet -o p.dll -q 'call_edge(I, F)' pointer.dl
 *     dotnet p.dll pointers.facts          (datalog_rt.dll beside it)
 *
 * The symbols are the runtime's numbers: a constant of a rule is a
 * field set from its text when the program starts.
 *
 * others: Souffle (2016) compiles to C++ through its RAM, a language
 * of loops, scans and index lookups, Datalog_eval's plan here; the
 * interpreter it later got (2019) runs the same RAM. Here the plan is
 * the interpreter's, the same code choosing it for both. *)

(* the assembly's bytes: its name, the program loaded (its rules, a
 * relation's stratum set by its run), the files' names and texts, the
 * queries asked *)
val assembly : string -> Datalog.t -> (string * string) list -> string list -> string
