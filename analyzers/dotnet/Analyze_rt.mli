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
 * A file not .c is read as Datalog's text (more facts, or rules'
 * facts). *)

(* the program: the rules' texts (file, text...), the queries, the
 * rules compiled; the files from the command line, -Idir for C *)
val main : string array -> string array -> (Datalog.t -> unit) -> unit
