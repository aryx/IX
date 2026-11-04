(* An ML file's functions in SSA form, for the facts of Ssa_facts: for
 * mini-analyze -flow and -dflow: the unit compiled by mini-ml's own way
 * (CLI's parse, classes and lower: Resolve, Typing, Lower), no
 * optimization, then each function through Ssa_build, as mini-ml -ssa
 * would. The facts are those of the code mini-ml compiles, not of a
 * copy of its front end: Alloc's liveness (-dflow) is checked against
 * the rules' on the same SSA form (analyzers/ml/tests/run.sh).
 *
 * Constants are folded at arm64's width (-m 7, the tests'). Was
 * mini-ml -flow and -dflow until 2026-11-02: in mini-ml, each change to
 * the facts relinked the compiler, and every object of ix depends on
 * the compiler's file (mkfiles' MLEXE): every program built again. *)

(* the file's functions in SSA form, for Ssa_facts.func (-flow) and
 * Ssa_facts.own (-dflow); dirs: where the units it names are; the
 * error, file and line. sites: each call named by its application
 * (Lower.sites, Ssa.func's sites), for -bugs *)
val file :
  ?sites:bool -> < CLI.caps; .. > -> Fpath.t list -> Fpath.t -> (Ssa.func list, string) result
