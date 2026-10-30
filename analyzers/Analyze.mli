(* mini-analyze: a whole program's calls through pointers, which
 * functions each may reach (docs/plans/plan_dotnet_languages.md, its
 * step 0). One program of three parts that were three commands:
 * mini-cc's front end reads the C files, Facts says each function as
 * the facts of a pointer analysis (mini-cc -facts), and mini-datalog's
 * evaluator runs the author's rules on them (pointer.dl); the answers
 * are read back here, not printed by another program.
 *
 *    a.c b.c ...                   pointer.dl (the rules, read at run time)
 *        |                              |
 *    mini-cc's front end                |
 *    (Pre, Lexer, Parser, Declare)      |
 *        |  each function's tree        |
 *    Facts: assign(p, q).  ...          |
 *        |  their text                  v
 *    Datalog.load ---------------> Datalog_eval.run
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
 * The facts pass as text from Facts to Datalog, as they did between
 * the commands; next, as values (Datalog.add), and then each part in
 * the language that suits it, compiled to .NET's IL: the front end
 * ML, the rules a Datalog module, the report maybe C#. The
 * boundaries are here to be seen first.
 *
 * others:
 * Doop (Yannis Smaragdakis and others, 2009) runs Datalog's pointer
 * analyses on Java's bytecode, its facts made by a separate program
 * (Soot), then Soufflé; CodeQL (Semmle, from .QL, Oege de Moor, 2007)
 * a database of a program's facts queried in a Datalog; Flix
 * (Magnus Madsen, 2016) the rules inside the language that makes the
 * facts. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* a global line of a file read with its #includes: the file and its
 * own line, by the history (the oldest first) *)
val locate : (string option * int) list -> int -> (string * int) option

val main : < caps; .. > -> string array -> int
