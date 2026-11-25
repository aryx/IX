(* What mini-ld linked into a program, for the tools that read a program
 * whole, mini-analyze first (docs/plans/plan_analyzer_build_manifest.md):
 * the objects it took, in their order, and the source of each, so that a
 * reader knows the exact files of the program, its libraries' and its
 * generated ones among them (a lexer in _mk/7), without being told them
 * by a mkfile. mini-ld writes it with its map (-map: out.manifest).
 *
 * A source is a project path (osemgrep's Ppath, without its module): from
 * the project's top, the same wherever the tree and the build are, read
 * by a tool paired with the project's top, as a path from a git root.
 *
 * The format is tiny-ld's, tiny/TinyLibExecutable's types: tiny/'s
 * tools use no file outside tiny/, so the types are declared there
 * again, the same text (analyzers/tests/run.sh checks it), and
 * mini-analyze reads both builds' manifests as one. *)

type taken =
  | Command_line            (* given to the linker *)
  | Archive_member of string  (* a member of this archive *)

(* a path in the project, from its top (assembler/Asm.ml), or absolute
 * for a file outside it (a lexer a build made elsewhere) *)
type ppath = Ppath of string

type linked = {
  l_object : string;        (* x.o as the linker was given it; a member's name *)
  l_source : ppath option;  (* x.ml, x.c or x.s *)
  l_flags : string list;    (* what reading it needs: a C file's -I, -D *)
  l_taken : taken;
}

type manifest = {
  m_program : string;       (* the output's name, rc *)
  m_units : linked list;    (* in the link's order *)
}

(* the file's bytes: "tiny-manifest 3" and the manifest marshalled, by
 * Marshal_ (the same bytes whatever OCaml built the linker) *)
val to_string : manifest -> string

(* raises Failure on a file that is not a manifest *)
val of_string : string -> manifest
