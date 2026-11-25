(* dune's programs' manifests: what dune links into each executable, in
 * tiny-ld's format (Tiny_manifest), so that mini-analyze reads a program
 * built by OCaml as it reads one built by t-IX, its exact files, its
 * platform's among them, nothing told (-L, -own, -I) or guessed.
 *
 * dune says it in two answers, which mini-analyze asks it for (run),
 * given dune's executables (an .exe) or a directory of them
 * (executables, by its links, dune rules @dir/all):
 *
 *     dune describe workspace     each library's modules and each
 *                                 executables stanza's, with their
 *                                 sources; but not which implementation
 *                                 of a virtual library a program links
 *                                 (TinyLibSystem's unix/, the platform)
 *     dune rules X.exe ...        each executable's link, ocamlopt's
 *                                 command line: its libraries (.cmxa)
 *                                 and its own modules (.cmx), in order,
 *                                 the implementation among them
 *
 * From the link, each local library's modules (describe's, by the
 * library's name) are its archive's members, and each of the program's
 * own .cmx (dune__exe__TinyShell.cmx) the module of its stanza
 * (describe's, by the stanza's .eobjs directory), given; opam's
 * libraries, with no source here, are left out, and dune's alias module
 * (dune__exe); a copy dune made (copy_files#) its original, by its
 * first line. A path is the project's file, from its root (describe's
 * root: tiny/TinyShell.ml, mini-analyze -sources the root), or, for a
 * file the build made (a lexer, lib_core's Parallel chosen by OCaml's
 * version), _build/default's, which dune build makes, else the build
 * context's that describe ran in.
 *
 * Like Coverity's capture of a build or clang's compile_commands.json,
 * but of the link, which a whole-program analysis needs
 * (docs/plans/plan_analyzer_build_manifest.md). *)

(* [of_dune caps describe rules]: the two answers' texts; the project's
 * root, and each executable's manifest by its path from the root
 * (tiny/TinyShell.exe), the paths in it from the root too *)
val of_dune :
  < Cap.open_in; .. > -> string -> string -> string * (string * Tiny_manifest.manifest) list

(* [run caps exes]: dune asked, from the current directory, about the
 * executables exes (tiny/TinyShell.exe, or _build/default/tiny/
 * TinyShell.exe), in a build directory of its own in the temporary
 * directory, one per project and kept (the next run 0.5 s, not 2.5 s;
 * not _build, which another dune may hold); of_dune's answer, its root
 * "." when it is the current directory. Raises Failure when dune fails
 * (an executable it does not know). *)
val run :
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. > ->
  string list -> string * (string * Tiny_manifest.manifest) list

(* [write caps exes]: run's manifests, each a file of a temporary
 * directory, in tiny-ld's format, for the runs of mini-analyze a merge
 * makes to read: the root, each executable with its file, and what
 * removes them *)
val write :
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. > ->
  string list -> string * (string * string) list * (unit -> unit)

(* [executables caps dirs]: the executables dune builds under dirs
 * (tiny), from the project's root: those dune rules @dir/all links (an
 * .exe, not tiny-machine-web's .bc.js), those of a tests' directory
 * left out (tests/, *_tests/) *)
val executables :
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. > ->
  string list -> string list
