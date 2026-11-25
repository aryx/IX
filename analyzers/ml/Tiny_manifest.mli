(* What tiny-ld or mini-ld linked into a program, read back: the
 * manifest each writes with its map (-map: out.manifest), for
 * mini-analyze to read the program's exact files, as the build linked
 * them, instead of being told them (-L, -own, -I) or guessing them
 * (Module_finder).
 *
 * The types are mini-ld's (lib_executable/Manifest), the same as tiny-ld's
 * (TinyLibExecutable), declared again there: tiny/'s tools use no file
 * outside tiny/, and Marshal knows no type, so both declarations must be
 * the same, constructors in the same order (analyzers/tests/run.sh
 * checks the text). The file is the magic line "tiny-manifest 2" and
 * the marshalled manifest.
 *
 * A source is a project path, read against the project's top: -project,
 * else the first directory up from the manifest with a dune-project, as
 * git finds its root, else the current directory. Both linkers' are
 * project paths (their -project; mini-ld's -build too); t-IX's build
 * runs in a copy of tiny/, which -project tiny names.
 *
 * docs/plans/plan_analyzer_build_manifest.md *)

type taken = Manifest.taken =
  | Command_line            (* given to the linker *)
  | Archive_member of string  (* a member of this archive *)

type ppath = Manifest.ppath = Ppath of string

type linked = Manifest.linked = {
  l_object : string;        (* x.o as the linker was given it; a member's name *)
  l_source : ppath option;  (* x.ml, x.c or x.s *)
  l_taken : taken;
}

type manifest = Manifest.manifest = {
  m_program : string;       (* the output's name, rc *)
  m_units : linked list;    (* in the link's order *)
}

(* raises Failure on a file that is not a manifest *)
val of_string : string -> manifest

(* the file's bytes: what tiny-ld writes, for the manifests of the
 * builds that are not tiny-ld's (Dune_manifest, dune's programs) *)
val to_string : manifest -> string

(* What mini-analyze takes from one:
 * - the program's own files, read and reported on: the ML files given
 *   to the linker, in the link's order;
 * - the directories of an archive's members that are in the program's
 *   part of the project (Module_finder.part_dir) and not the standard
 *   library's (Ml_front.own_dirs, -own's): their units reported on when
 *   the program names them, tiny/TinyLibSystem/unix and tiny/'s
 *   TinyLib*.ml libraries for a host program of tiny/, as -own and
 *   Module_finder had them. Not read up front: OCaml links an archive's
 *   modules that the program names, not all of them as tiny-ld does
 *   (tiny-shell's dune link has tiny_lib_regex.cmxa, which it does not
 *   name). Another part's library (lib_crypto) is read when named, not
 *   reported on;
 * - the standard library (-L's): the first directory, from an archive
 *   member's up, with a units.txt (lib_core) or its own Stdlib.mli
 *   (tiny/TinyLibCore);
 * - the program's components: the files given that no other program of
 *   the build links (tiny/TinyBuildSystem.ml for build, not
 *   TinyLibSystem/tinykernel's, which every program links), what -dead
 *   reports on when the program is analyzed alone (Ml_front.components):
 *   a library's function one program does not call is not dead, its
 *   dead code is the merge's (mini-analyze -dead lib.ml, tiny_check.sh);
 *   another program, for tiny-ld's, is a manifest beside this one;
 * - each linked ML unit's file, by the unit's name (Ml_front.linked). *)
type program = {
  name : string;
  own : string list;
  components : string list;
  own_dirs : string list;
  library : string option;
  units : (string * string) list;
}

(* [of_manifest caps m others root]: its paths read against root; others
 * the build's other programs (their files the shared ones) *)
val of_manifest :
  < Cap.open_in; Cap.readdir; .. > -> manifest -> manifest list -> string ->
  program

(* [program caps file project]: file a manifest; its paths read against
 * project if given, else the project found above the manifest *)
val program :
  < Cap.open_in; Cap.readdir; .. > -> string -> string option -> program

(* [root caps file project]: the project a manifest's paths are from:
 * project if given, else the first directory up from the manifest with
 * a dune-project, as git finds its root, else the current directory *)
val root : < Cap.readdir; .. > -> string -> string option -> string

(* [linking m root file]: whether the manifest links file (a library's,
 * tiny/TinyLibGUI.ml), its paths read against root *)
val linking : manifest -> string -> string -> bool
