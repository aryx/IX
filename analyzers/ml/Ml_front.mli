(* ML units through mini-ml's front end into Closure_facts (CLI's
 * parse, Resolve, Typing, without mlpp's classes):
 * the facts of a whole program, its own units and those of the library
 * they name, so that a function given to List.iter is seen called *)

(* the directories of lib_core's units (its units.txt's, and commons/) *)
val library : < Cap.open_in; .. > -> string -> Fpath.t list

(* the program's files read, then each unit they name found in the
 * directories (the files' own first) and read too, until no new one;
 * the errors of the program's files (a library unit not read is left
 * out) *)
val program : < Cap.open_in; .. > -> Fpath.t list -> Fpath.t list -> string list

(* the files alone, their units, not the library units they name: their
 * names resolved by their interfaces, their code not read (-alone, the
 * tests' facts of one unit, which mini-ml -facts gave) *)
val alone : bool ref

(* the library units that could not be read, why: what they call looks unused *)
val unread : string list ref

(* a unit's file, by its name (Use: tests/ml/handlers/Use.ml) *)
val files : (string, string) Hashtbl.t

(* the program's own units, not the library's *)
val own : (string, unit) Hashtbl.t
