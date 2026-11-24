(* ML units through mini-ml's front end into Closure_facts (CLI's
 * parse, Resolve, Typing, without mlpp's classes):
 * the facts of a whole program, its own units and those of the library
 * they name, so that a function given to List.iter is seen called *)

(* the directories of lib_core's units (its units.txt's, and commons/),
 * or the one directory of a library that has its own Stdlib there and
 * no units.txt (tiny/TinyLibCore) *)
val library : < Cap.open_in; .. > -> string -> Fpath.t list

(* the directories a unit is looked up in after the program's: -I's
 * then the library's, or for a library in one directory its own first,
 * the -I's only for what it lacks (t-IX's programs on TinyLibCore, Cap
 * from lib_core/system) *)
val search : < Cap.open_in; .. > -> string -> Fpath.t list -> Fpath.t list

(* the program's files read, then each unit they name found in the
 * directories (the files' own first) and read too, until no new one;
 * the errors of the program's files (a library unit not read is left
 * out) *)
val program : < Cap.open_in; Cap.readdir; .. > -> Fpath.t list -> Fpath.t list -> string list

(* the files alone, their units, not the library units they name: their
 * names resolved by their interfaces, their code not read (-alone, the
 * tests' facts of one unit, which mini-ml -facts gave) *)
val alone : bool ref

(* the directories whose units are the program's own (-own): a unit the
 * program names that is found there is read and reported on as a file
 * given on the command line is, so that a program can be given by its
 * main file alone. A unit found in an -I directory or in the library is
 * read too, but is not reported on. *)
val own_dirs : Fpath.t list ref

(* the units a build linked, each one's .ml, by the unit's name (a
 * manifest's, Tiny_manifest): when it has any, a unit's code is the file
 * linked and nothing else, no directory searched and nothing guessed;
 * its interface is the .mli beside it, else the directories'. *)
val linked : (string, string) Hashtbl.t

(* the units of the program's components, a manifest's (Tiny_manifest):
 * when it has any, -dead reports on them alone, not on the libraries
 * the program links (Dead_report) *)
val components : (string, unit) Hashtbl.t

(* the library units that could not be read, why: what they call looks unused *)
val unread : string list ref

(* a unit's file, by its name (Use: tests/ml/handlers/Use.ml) *)
val files : (string, string) Hashtbl.t

(* the program's own units, not the library's *)
val own : (string, unit) Hashtbl.t

(* An implementation's interface found elsewhere, by the .ml's file:
 * tiny/TinyLibSystem/unix/TinyLibSystem.ml's is tiny/TinyLibSystem.mli,
 * as is tinykernel/'s. These are one unit's variants, each for its
 * platform. An .ml with its .mli beside it is not here. *)
val interfaces : (string, string) Hashtbl.t

(* the printers [@@deriving show] makes in the units read, "Unit.show_x"
 * and "Unit.pp_x" (show and pp for a t): the deriver's code, which
 * -dead does not say dead *)
val derived : (string, unit) Hashtbl.t

(* each unit read, every file of its name in a directory whose units
 * name it (bugs/init.dl's: two, one of them linked silently) *)
val homes : (string, string list) Hashtbl.t
