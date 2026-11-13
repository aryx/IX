(* Lower turns a function's typed tree into code for a stack machine.
 * It is the simple back end, whose contract is the behavior (plan_cc.md,
 * decision 8).
 *
 * The machine is Ir's: it has values and operations, and each operation
 * takes its operands from the top of the stack. The front end's trees
 * are used as they are, with no addressability and none of 5c's
 * rewrites (acom). An expression is its operands, then its operator.
 * Of a binary operator's two operands, the one that needs more of the
 * stack goes first (by Ershov's number, followed by a Swap), unless one
 * of them contains a call. A call's value is computed before the
 * address it is stored to, so that nothing is live across
 * x = setjmp(b). A condition becomes jumps (&&, ||, !, ?:), and the
 * value of a relation is 1 or 0.
 *
 * Calls: the arguments that contain calls are computed first, into
 * temporaries, so that the others can be stored straight into the
 * outgoing area, at their offsets (Declare's Aarg1 and Aarg2, as in
 * 7c). The first argument is also put in R0 when it is a word. A
 * structure's result goes to a temporary whose address is the hidden
 * first argument. This is 5c's and 7c's convention, so that what
 * simple compiles can call libc, and be called by it.
 *
 * The frame holds Declare's autos, then the temporaries (the values of
 * arguments, the structures of results, the value of a switch), which
 * are freed after each statement. Gen adds the stack's spills and the
 * outgoing area.
 *
 * A statement, to show the conditions and the addresses (from mini-cc
 * -simple -dir, shortened: p stands for Lea p+0(FP), and so on):
 *
 *     for(i = 0; i < n; i++) s += p[i];
 *
 *         i; Int 0; Store; Drop              i = 0
 *     L1: i; Load; n; Load; Op Lt; Jz L3     the test: a 1 or a 0, popped
 *         s; Dup; Load                       s's address, kept under its
 *         i; Load; Int 4; Op Mul             value; i * 4, Check's scaling;
 *         p; Load; Swap; Op Add; Load        p + i * 4, then its content,
 *         Op Add; Store; Drop                added, and stored through the
 *     L2: i; Dup; Load; ...; Store; Drop     kept address; i++
 *         Jmp L1
 *     L3:
 *
 * The tree is walked once, and each node writes its part, as cgen does
 * in compat; what is not done is to look at a node's neighbours first.
 * So i < n makes a 1 or a 0 that the jump tests at once, and s +=
 * becomes an address, a Dup and a Load, where the machine has an
 * instruction for it. It is Opti that sees those pairs afterwards (its
 * passes branch and places).
 *
 * design:
 * Two passes that each do little, against one pass that does much.
 * compat's Cgen decides everything as it walks the tree: which
 * register to use, which side goes first, whether a constant fits the
 * instruction, and a dozen special cases for each operator. It is 950
 * lines, and each line knows 5c's choices. Here the walk knows only
 * the language and Gen knows only the machine, and the stack code
 * between them is where a third party can stand: the optimizer, the
 * dump, or the Datalog facts (Ir_facts). This is the argument for an
 * intermediate language, on the smallest example that has both ways
 * side by side.
 *
 * References: plan_cc.md, "Amendment: two back ends" and decision 8;
 * A. P. Ershov, "On programming of arithmetic operations"
 * (Communications of the ACM 1(8), 1958), for the
 * number that orders two operands. *)

val func : Tree.sym -> Tree.stmt -> Ir.func

(* an instruction, and a function, as mini-cc -dir prints them *)
val show_func : Ir.func -> string

(* the front end's hook (Check.xcom). On arm, it rewrites a vlong's
 * operations as calls to libc (Com64), bottom up; on arm64, it returns
 * the tree as it is. *)
val calls64 : Tree.expr -> Tree.expr
