(* An ML program's analysis said (mini-analyze's report, Analyze.mli):
 * each call through a variable of the program's own units, where, and
 * the functions it may reach (calls.dl's call_edge); the program's
 * functions its toplevel never reaches. The units and files are
 * Ml_front's. Both of mini-analyze's roads use it, as C_report. *)

(* an ML function as said: Use.f, a local Use:go/3 as go, a lambda
 * Use:fun1@11 as "Use:fun at line 11", an external prim:name *)
val ml_function : string -> string

(* the report, on the facts and the rules' answers *)
val ml_report : < Cap.stdout; .. > -> Datalog.t -> unit
