(* A C file's functions as their stack code's facts (Ir_facts), for
 * mini-analyze -flow and -dflow: the file read by mini-cc's front end
 * (C_front.read), each function lowered by the simple back end (Lower)
 * and through Opti's passes but regs, as mini-cc -simple -O does. The
 * facts are those of the code mini-cc compiles: Opti's own liveness
 * (-dflow) is checked against the rules' (analyzers/c/tests/run.sh).
 *
 * On arm64 (-m 7, the tests'). Was mini-cc -flow and -dflow until
 * 2026-11-02, as ML's (Ml_flow): out of the compilers, so that a
 * change to the facts does not relink them. *)

(* the file's functions' facts, Ir_facts.func's (own: Ir_facts.own's,
 * Opti's liveness); the -D's, the -I's; the error, file and line *)
val file :
  < Cap.open_in; .. > -> own:bool -> string list * Fpath.t list -> Fpath.t ->
  (string, string) result
