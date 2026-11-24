(* What tiny-ld linked into a program, read back: the manifest it writes
 * with its map (tiny-ld -map: out.manifest), for mini-analyze to read
 * the program's exact files, as the build linked them, instead of being
 * told them (-L, -own, -I) or guessing them (Unit_finder).
 *
 * The types are TinyLibExecutable's, declared again here: tiny/'s tools
 * use no file outside tiny/, and Marshal knows no type, so both
 * declarations must be the same, constructors in the same order
 * (analyzers/tests/run.sh checks the text). The file is the magic
 * line "tiny-manifest 1" and the marshalled manifest.
 *
 * A manifest's paths are as tiny-ld was given them, relative to the
 * directory it ran in, which is the manifest's in the Buildfile's links.
 * The host's build of t-IX runs in a copy of tiny/
 * (tiny/TinyKernel/_make/src), so [sources] says where they are read
 * instead: tiny/, whose files the reports then name.
 *
 * docs/plans/plan_analyzer_build_manifest.md *)

type taken =
  | Command_line            (* given to tiny-ld *)
  | Archive_member of string  (* a member of this archive *)

type linked = {
  l_object : string;        (* x.o; an archive member's name, List.o *)
  l_source : string option; (* x.ml, x.c or x.s *)
  l_taken : taken;
}

type manifest = {
  m_program : string;       (* the output's name, rc *)
  m_units : linked list;    (* in the link's order *)
}

(* raises Failure on a file that is not a manifest *)
val of_string : string -> manifest

(* What mini-analyze takes from one: its ML files given to tiny-ld, the
 * program's own, in the link's order; the directory of the archive its
 * ML members come from, the standard library (-L's); and each linked
 * ML unit's file, by the unit's name (Ml_front.linked). *)
type program = {
  name : string;
  own : string list;
  library : string option;
  units : (string * string) list;
}

(* [program caps file sources]: file a manifest; its paths read against
 * sources if given, else against the manifest's directory *)
val program : < Cap.open_in; .. > -> string -> string option -> program
