(* mini-analyze -dead's report: what dead.dl finds of a C or ML
 * program, each with where it is written (Analyze.mli says the
 * analysis). Both of mini-analyze's roads use it, as C_report. *)

(* The report, on the facts and the rules' answers; ML's program or C's.
 * It returns the lines printed, as their file, line (0 when there is none)
 * and message: mini-analyze -summary's report facts. *)
val dead_report : < Cap.stdout; .. > -> Datalog.t -> bool -> (string * int * string) list
