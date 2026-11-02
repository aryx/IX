(* mini-analyze -caps's report: what capabilities.dl finds of an ML
 * program, a line a function: what it holds, what is missing and by
 * what, what it holds for nothing (Analyze.mli says the analysis).
 * Both of mini-analyze's roads use it, as C_report. *)

(* the report, on the facts and the rules' answers *)
val caps_report : < Cap.stdout; .. > -> Datalog.t -> unit
