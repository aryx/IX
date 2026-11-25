(* Programs given by their build, which knows their files: tiny-ld's
 * manifests (Tiny_manifest), dune's executables (Dune_manifest), or
 * directories of either; each read as linked, its platform's files
 * among them, nothing told by -L, -I, -own
 * (docs/plans/plan_analyzer_build_manifest.md). *)

(* the directories given: the manifests under each, every one, or with
 * none the executables dune builds under it, each named by its path from
 * the directory; true when one could not be read, said *)
val expand_dirs : < Analyze_flags.caps; .. > -> Analyze_flags.t -> bool

(* one program, its manifest's or its executable's: its files, standard
 * library and linked units given to the analysis (flags' files, lib,
 * Ml_front's tables); -dead alone, its components; true on a failure,
 * said *)
val read : < Analyze_flags.caps; .. > -> Analyze_flags.t -> bool

(* -dead on one .ml file and programs: the file a library's or a part of
 * a program's, its programs those given that link it, each run as
 * linked, merged (Analyze_merge), its -sources found if not given *)
val library : < Analyze_flags.caps; .. > -> Analyze_flags.t -> int

(* several programs: each run as linked, merged; a manifest of no ML
 * unit (tiny-cc's) left out, said; each manifest's -sources, the
 * shallowest manifest's directory's -sources, a deeper one's below it *)
val several : < Analyze_flags.caps; .. > -> Analyze_flags.t -> int
