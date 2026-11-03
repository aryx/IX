(* mini-analyze -exn's report: the exceptions an ML program's toplevels
 * may let escape (lib_code/datalog/exceptions.dl), each with where it
 * may be raised; a function C calls, back to C; a try catching all
 * whose handler raises (exceptions.dl's from_c, ends_in). Both of
 * mini-analyze's roads use it, as Ml_report.
 *
 *   Main.ml: the toplevel may let Empty escape, raised at Main.ml:11 (Main.first)
 *   Main.ml: Main.trap, called from C, may let Failure escape, raised at ...
 *   Main.ml:67: the try in Main.guard, its handler raising, may be reached by Not_found, ...
 *
 * cs-history: Xavier Leroy and François Pessaux's ocamlexc (2000) found
 * the same by types; here it is the call graph's closure (pointer.dl's
 * call_edge) and a subtraction at each try. *)

(* a name's unit: Main of Main:init, Main.trap, Main:try2@67 *)
val unit_of : string -> string

(* a try's line: 67 of Main:try2@67 *)
val try_line : string -> string

(* the report, on the facts and the rules' answers *)
val exn_report : < Cap.stdout; .. > -> Datalog.t -> unit
