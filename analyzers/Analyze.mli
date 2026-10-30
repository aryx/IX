(* mini-analyze: a whole program's calls through pointers, which
 * functions each may reach, and the bugs the same answers show (a
 * free of what no allocator gave, a function returning its frame's
 * address: bugs.dl) (docs/plans/plan_dotnet_languages.md, its step 0). One program of three parts that were three commands:
 * mini-cc's front end reads the C files, Facts says each function as
 * the facts of a pointer analysis (mini-cc -facts), and mini-datalog's
 * evaluator runs the author's rules on them (pointer.dl); the answers
 * are read back here, not printed by another program.
 *
 *    a.c b.c ...                   pointer.dl, bugs.dl (the rules, read at run time)
 *        |                              |
 *    mini-cc's front end                |
 *    (Pre, Lexer, Parser, Declare)      |
 *        |  each function's tree        |
 *    Facts: assign(p, q).  ...          |
 *        |  each a tuple, as found      v
 *    Datalog.add ----------------> Datalog_eval.run
 *                                       |  call_edge(I, F), point_to(V, M)
 *                                  the report: a.c:12: in walk, through f: hide, show
 *
 *     mini-analyze -r languages/datalog/analyses prog/*.c
 *
 * A call's site is Facts's name, the function and the global line
 * (_in_walk_line_56_1); the line is found back in its file by the
 * #includes' history (Pre.history, 5c's), as the linker does.
 *
 * design:
 * The facts pass from Facts to Datalog as values (Facts.added, a
 * tuple of symbols each), where they were text between the commands;
 * next, each part in the language that suits it, compiled to .NET's
 * IL: the front end ML, the rules a Datalog module, the report maybe
 * C#. The boundaries are here to be seen first. mini-cc's front end
 * is compiled a second time, wrapped (c/): mini-ml's and mini-cc's
 * units share names (Lexer, Parser, Emit) in OCaml's one namespace,
 * which .NET's assemblies and namespaces would keep apart.
 * Where the time goes, Plan 9's rc (goken's, 30 files, 215
 * functions): the front end 0.3 s for 7,850 facts, the rules 7 s
 * (29 rounds, 20 million lookups for 44,000 tuples): the evaluator,
 * which a Datalog compiled (Soufflé's way, the plan's decision 5)
 * is for.
 *
 * others:
 * Doop (Martin Bravenboer, Yannis Smaragdakis, OOPSLA 2009) runs
 * Datalog's pointer analyses on Java's bytecode, its facts made by a
 * separate program (Soot), first on LogicBlox's engine, then Soufflé's;
 * there the analyses of twenty years (Andersen's, k-CFA, object and
 * type sensitivity) are each a choice of contexts in the same rules,
 * which is where pointer.dl would grow: a context a column more
 * (calls.dl says how). CodeQL (Semmle, from .QL, Oege de Moor, 2007)
 * a database of a program's facts queried in a Datalog with classes;
 * Flix (Magnus Madsen, 2016) the rules inside the language that makes
 * the facts.
 *
 * References: Martin Bravenboer, Yannis Smaragdakis, "Strictly
 * declarative specification of sophisticated points-to analyses"
 * (OOPSLA 2009); Yannis Smaragdakis, George Balatsouras, "Pointer
 * Analysis" (Foundations and Trends in Programming Languages, 2015). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* a global line of a file read with its #includes: the file and its
 * own line, by the history (the oldest first) *)
val locate : (string option * int) list -> int -> (string * int) option

val main : < caps; .. > -> string array -> int
