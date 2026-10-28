(* A computation made twice made once (plan_ml_speed.md, stage 3): in
 * a function's SSA form, an instruction of the same operation and
 * operands as one in a block that dominates it, or before it in its
 * own block, is that one's value, and goes. Its uses read the first.
 * Only the pure instructions: the integers' and the doubles'
 * operations, a tag, a float's double, a global the function does not
 * set; not a field, an array's element or a byte (a store between
 * may change it), nor an allocation or a call.
 *
 *     let f a i = a.(i * 4 + 1) + a.(i * 4 + 2)
 *
 * computes i * 4 once, where the stack code made it twice. A constant
 * is numbered too: each 4 is a value of its own, and the two products'
 * operands are then one.
 *
 * Not, for now, a great optimizer in practice: alone, mini-doom's and
 * mini-quake's frames 0.996 and 0.995, mini-ml compiling 0.999, the
 * programs 0.5% smaller (with Licm 0.990 and 0.991); ix's code
 * computes few things twice where this sees them, and what a loop does
 * at each turn again is mostly memory's (a field, an element: not
 * taken) or the registers' (arm's five). Kept as the classic pass it
 * is, and for the code later passes may give it (inlining, a load no
 * store changes). bench/matrix.ml shows it at work: c's index once for
 * its read and its write, 0.870 alone, 0.793 with Licm.
 *
 * others:
 * The walk of the dominator tree with a table of the expressions
 * seen, each removed on the way back, is the classic dominator-based
 * value numbering (Briggs, Cooper and Simpson, 1997). ocamlopt's CSE
 * (asmcomp/CSEgen.ml, since 4.03) is per extended basic block, on Mach
 * code, and also knows which loads no store has changed. LLVM's GVN
 * and GCC's FRE number values across the whole function, through
 * memory too.
 *
 * References: P. Briggs, K. Cooper and L. T. Simpson, "Value
 * Numbering" (Software: Practice and Experience 27(6), 1997). *)

(* on, unless mini-ml -no-cse *)
val on : bool ref

(* an instruction whose value its operands alone give (set: a global
 * the function sets, read again after); Licm's too *)
val pure : set:(string -> bool) -> Ssa.ins -> bool

(* the function has a handler (a try); the globals it sets (Init) *)
val handler : Ssa.func -> bool
val sets : Ssa.func -> string -> bool

(* the function with its computations made twice removed, in place *)
val func : Ssa.func -> Ssa.func
