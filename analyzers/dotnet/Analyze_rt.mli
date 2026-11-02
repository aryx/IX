(* mini-analyze's .NET road (plan_dotnet_languages.md, stage 8): one
 * process, where the native mini-analyze is one process too but its
 * rules interpreted. The entry of a program whose rules mini-datalog
 * -dotnet compiled (-runtime analyze_rt -entry Analyze_rt):
 *
 *     a.c b.c (-Idir...)          the rules' texts, in the program
 *        |                              |
 *    mini-cc's front end (C_front)      |
 *        |  each function's tree        |
 *    Facts: assign(p, q). ...           |
 *        |  each a tuple of symbols     v
 *    Datalog.add --------------->  the rules compiled (IL's loops)
 *                                       |
 *                                  the queries' answers, as
 *                                  mini-datalog prints them
 *
 * compiled by mini-ml -dotnet with mini-cc's front end, Facts,
 * mini-datalog's relations and Datalog_rt (the loops' calls) into
 * analyze_rt.dll: ML's values and Datalog's in one assembly's types,
 * no text between them. The native road it is compared with: the
 * same front end's facts as text (mini-analyze -facts), mini-datalog
 * on them; the author's two roads, for the teaching and the numbers.
 * An ML program's .ml files go through mini-ml's front end into
 * Closure_facts (Ml_front, mini-analyze's), lib_core's units they name
 * with them (-Ldir, lib_core); a file neither .c nor .ml is read as
 * Datalog's text (more facts, or rules' facts). Both front ends in one
 * assembly: mini-cc's units copied with Parser and Lexer renamed
 * (tests/run.sh), as dune's wrapped copy in analyzers/c does it. *)

(* (with no query, the reports mini-analyze prints, C_report's and
 * Ml_report's, or with -dead Dead_report's, with -caps Caps_report's:
 * the program compiled with the rules mini-analyze loads for each) *)

(* the program: the rules' texts (file, text...), the queries, the
 * rules compiled; the files from the command line, -Idir for C and
 * ML, -Ldir lib_core's *)
val main : string array -> string array -> (Datalog.t -> unit) -> unit
