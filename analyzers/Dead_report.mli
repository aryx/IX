(* mini-analyze -dead's report: what dead.dl finds of a C or ML
 * program, each with where it is written (Analyze.mli says the
 * analysis). Both of mini-analyze's roads use it, as C_report. *)

(* the report, on the facts and the rules' answers; ML's program or C's *)
val dead_report : < Cap.stdout; .. > -> Datalog.t -> bool -> unit
