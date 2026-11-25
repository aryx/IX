(* Programs given by their build, which knows their files: the linkers'
 * manifests, mini-ld's and tiny-ld's (-map; Tiny_manifest reads both),
 * dune's executables (Dune_manifest), or directories of either; each
 * read as linked, its platform's files among them, nothing told by -L,
 * -I, -own (docs/plans/done/plan_analyzer_build_manifest.md).
 *
 *     mini-analyze -caps _mk/7          ix's build, every program
 *     mini-analyze -dead tiny/TinyShell.exe
 *     mini-analyze -dead -project tiny tiny/TinyLibGUI.ml tix/src/*.manifest
 *
 * history:
 * Before the manifests (2026-11-23), a program was told: check.sh tiny's
 * table of about 30 programs, each with its main file and flags (-L,
 * -own, -I), and check.sh ix's 44 programs read from their mkfiles by
 * shell (mk_units.sh, generated.sh, sweep.sh, triage.sh): 607 lines of
 * scripts, a copy of what the build files already said. What the
 * manifests bought (2026-11-25), for about 1,100 lines of the analyzer
 * and 250 of the linkers', and 380 of those scripts gone:
 * - coverage: m-ix's 163 programs as ix builds them, not the 44 with a
 *   mkfile's SRC, a program's library code in its part of the tree (all
 *   of version_control's) its own, not -I's; t-IX's 55, each on its
 *   real platform (tiny-kernel's TinyLibSystem, not unix's), the kernel
 *   among them;
 * - precision: nothing guessed by a name nor copied from a build file;
 *   gone, the misreadings the copies hid: KRaw read from tiny-kernel's
 *   file for the host's (11 functions dead that were not), the SDL
 *   programs on unix's TinyLibSystem, TinyMachineWindow in no table;
 * - bugs found: three programs that no longer linked (mini-singml, and
 *   oberon's and squeak's kernels, docs/plans/bugs/ix.md), the mkfile
 *   route reading their sources without building them; a dead global
 *   said of what a toplevel read; about 850 new reports to read;
 * - no drift: a new program, unit or library analyzed once built, no
 *   table to keep;
 * - one command, from anywhere, its answer the checks' (no filtering
 *   before or after it in a script).
 * mini-9pi's kernel too, since (mkkernel's link writes its manifest;
 * kernel.sh, which read its mkfile, gone). C programs too, since: each
 * C file read with its compile's flags, -I and -D, which mini-cc and
 * tiny-cc record in the object and the linkers in the manifest (hello-c
 * with libc's members, tiny-cc's 7, the C kernels); found, libc's
 * functions no program calls. And -bugs reads an ML program's C with
 * it, its runtime's (the C given to the linker): bugs/raises.dl checks
 * each external's [@@raise] against what its C raises, both languages'
 * facts in one analysis. *)

(* the directories given: the manifests under each, every one, or with
 * none the executables dune builds under it, each named by its path from
 * the directory; a directory of dune's build, _build/default/tiny, the
 * executables alone (tiny/ may hold t-IX's manifests, built beside its
 * sources); true when one could not be read, said *)
val expand_dirs : < Analyze_flags.caps; .. > -> Analyze_flags.t -> bool

(* one program, its manifest's or its executable's: its files, standard
 * library and linked units given to the analysis (flags' files, lib,
 * Ml_front's tables); -dead alone, its components; true on a failure,
 * said *)
val read : < Analyze_flags.caps; .. > -> Analyze_flags.t -> bool

(* -dead on one .ml file and programs: the file a library's or a part of
 * a program's, its programs those given that link it, each run as
 * linked, merged (Analyze_merge), its -project found if not given *)
val library : < Analyze_flags.caps; .. > -> Analyze_flags.t -> int

(* several programs: each run as linked, merged; a manifest of no ML
 * unit (tiny-cc's) left out, said; -project given to each run *)
val several : < Analyze_flags.caps; .. > -> Analyze_flags.t -> int
