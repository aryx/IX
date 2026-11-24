(* Finding a program's units in its project, when they are in none of the
 * directories given (-own, -I, the library's), as a person would: by
 * looking around the program for the files of the names it uses.
 *
 * The project is the first directory above the program's first file that
 * has a dune-project; its .ml and .mli files are indexed by unit, once,
 * on the first unit asked for, leaving out the directories whose name
 * starts with . or _ (.git, _build, _mk...). A unit with one file of its
 * name there is that file's. A name several directories have (tiny-ml's
 * Lexer, in tiny/TinyML/ and tiny/TinyC/) is decided by the program as a
 * whole rather than by the unit: the directory already chosen for one of
 * its units first, then the one that has the most of the units its files
 * name (TinyML/ alone has Compile and Link), then the nearest to the file
 * that names it. What is still a tie is warned about. A directory with
 * its own Stdlib is left out: another platform's standard library
 * (tiny/TinyLibCore, whose Sha1 is t-IX's runtime's), the program's being
 * the one given (-L).
 *
 * A platform's choice is not this module's: the implementations of one
 * interface (TinyLibSystem's unix/ and tinykernel/) have the same names,
 * and the program's build says which one it links (-own, -I). *)

type t

(* [create caps file]: for a program whose first file is [file] *)
val create : < Cap.readdir; .. > -> string -> t

(* [mentions t text]: a file of the program read, the module names in its
 * text, the units it may name *)
val mentions : t -> string -> unit

(* [choose t from name exts]: the directory of the unit [name], named by
 * the file [from], among those with its file of one of [exts] (".mli",
 * ".ml"); None if the project has none *)
val choose : t -> string -> string -> string list -> string option

(* [library caps file]: the program's standard library when -L does not
 * say it, the one nearest [file] in the project, then the shallowest:
 * tiny/TinyLibCore for tiny/TinyBuildSystem.ml, lib_core elsewhere in ix
 * (a directory with a Stdlib, or the one above it with a units.txt) *)
val library : < Cap.readdir; .. > -> string -> string option

(* [own t dir]: whether the units of [dir], a directory chosen, are the
 * program's own, reported on: in the project's top directory of the
 * program's first file (tiny/ for tiny/TinyBuildSystem.ml, its TinyML/
 * and TinyKernel/ too); another's (lib_crypto) is a library, read and
 * not reported on, as an -I's is *)
val own : t -> string -> bool

(* [part_dir caps file]: that top directory of the project for [file],
 * as the files are named (tiny for tiny/TinyLibGUI.ml), the project
 * itself for a file at its top; None when there is no project. Where
 * Caller_finder looks for the programs of a unit. *)
val part_dir : < Cap.readdir; .. > -> string -> string option

(* [generated caps t dir name]: whether the unit [name] of the program's
 * directory [dir] is one its build makes, from a .mll (ocamllex's,
 * mini-lex's) or a .mly (ocamlyacc's, menhir's, mini-yacc's) of its
 * name there: None if not; Some (Some d) when d, dune's build directory
 * of [dir] (the project's _build/default/dir), has it; Some None when it
 * is not built yet. Such a unit is never taken from another directory of
 * the project: a Lexer elsewhere is another program's. *)
val generated : < Cap.readdir; .. > -> t -> string -> string -> string option option
