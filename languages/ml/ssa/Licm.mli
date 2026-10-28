(* A loop's invariants out of it (plan_ml_speed.md, stage 3): in a
 * function's SSA form, a pure instruction inside a loop whose operands
 * are all made outside it gives the same value at each turn, so it is
 * made once, before the loop. A loop is found by its jump back: to a
 * block (its header) that dominates the block jumping; its blocks are
 * those that reach the jump without passing the header. The
 * instruction goes to the end of the header's immediate dominator,
 * which every way into the loop goes through.
 *
 *     for j = 0 to n - 1 do s := !s + a.(i * n + j) done
 *
 * makes i * n once, where the stack code made it at each turn.
 *
 * Only what cannot fail, since the loop may run no turn: the
 * operations Cse takes but a division (by zero). A constant goes too,
 * for what reads it: it costs nothing where it is (Emit makes it where
 * it is read). An inner loop's invariants moved to the
 * outer loop's body are looked at again, as the outer's.
 *
 * Not, for now, a great optimizer in practice: with Cse, mini-doom's
 * and mini-quake's frames 0.990 and 0.991, mini-ml compiling 0.9995.
 * Their loops mostly had their invariants computed before them, by
 * their authors; what they reload at each turn are values the
 * registers do not hold (arm's five), which a value moved out of a
 * loop adds to. Kept as the classic pass it is, and for the code later
 * passes may give it. bench/matrix.ml shows it at work: i * n out of
 * the inner loops, 0.807 alone, 0.793 with Cse.
 *
 * others:
 * Loop-invariant code motion is from the first optimizing compilers
 * (Fortran's, IBM's in the 1950s and 60s); Frances Allen's and John
 * Cocke's papers of 1971 and 1972 put it with the other classic
 * passes on a program's flow graph. ocamlopt has none before flambda;
 * LLVM's LICM and GCC's loop-im also move loads no store in the loop
 * can change, and stores out of a loop.
 *
 * References: F. Allen and J. Cocke, "A Catalogue of Optimizing
 * Transformations" (1971); A. Aho, M. Lam, R. Sethi and J. Ullman,
 * "Compilers: Principles, Techniques, and Tools" (2nd ed., 2006),
 * section 9.5 (loops) and 9.6 (natural loops). *)

(* on, unless mini-ml -no-licm *)
val on : bool ref

(* the function with its loops' invariants before them, in place *)
val func : Ssa.func -> Ssa.func
