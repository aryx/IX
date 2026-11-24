(* mini-analyze -dead's report: what dead.dl finds of a C or ML
 * program, each with where it is written (Analyze.mli says the
 * analysis). Both of mini-analyze's roads use it, as C_report. *)

(* How a report of several programs is kept, when they are merged
 * (datalog/dead_all.dl): a dead function where every program that has
 * its file says it (another program may call it); a [@@for_testing]
 * function a program calls where one program says it. *)
type kept = Every_program | One_program

(* The report, on the facts and the rules' answers; ML's program or C's.
 * It returns the lines printed, as their file, line (0 when there is
 * none), what is dead (its kind and name: "dead Http.asked", "never built
 * Leaf"; a statement's by its place), message, and how it is kept:
 * mini-analyze -summary's report facts, merged by what is dead, whatever
 * the reason given. *)
val dead_report : < Cap.stdout; .. > -> Datalog.t -> bool -> (string * int * string * string * kept) list
