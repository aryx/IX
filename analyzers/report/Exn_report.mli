(* mini-analyze -exn's report: the exceptions an ML program's toplevels
 * may let escape (lib_code/datalog/exceptions.dl), each with where it
 * may be raised. Both of mini-analyze's roads use it, as Ml_report.
 *
 *   Main.ml: the toplevel may let Empty escape, raised at Main.ml:11 (Main.first)
 *
 * cs-history: Xavier Leroy and François Pessaux's ocamlexc (2000) found
 * the same by types; here it is the call graph's closure (pointer.dl's
 * call_edge) and a subtraction at each try. *)

(* a site, a raise's or a call's, as file and line: Main:11:r6 is Main.ml:11 *)
val site : string -> string

(* the report, on the facts and the rules' answers *)
val exn_report : < Cap.stdout; .. > -> Datalog.t -> unit
