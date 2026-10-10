(* A function's typed tree to a stack machine's code (the simple back
 * end whose contract is the behavior: plan_cc.md, decision 8).
 *
 * The machine is Ir's: its values, its operations, each taking its
 * operands from the top of the stack. The front end's trees are used as they are: no
 * addressability, no 5c's rewrites (acom): an expression is its
 * operands, then its operator; of a binary operator's operands the one
 * that needs more of the stack goes first (Ershov's number, then a
 * Swap), unless one calls, and a call's value is computed before the
 * address it is stored to (nothing is live across x = setjmp(b)). A condition is jumps (&&, ||, !,
 * ?:), a relation's value 1 or 0.
 *
 * Calls: the arguments that call are computed first, into temporaries,
 * so that the others are stored straight into the outgoing area (at
 * their offsets, Declare's Aarg1 and Aarg2, as 7c's), the first one
 * also in R0 when it is a word; a structure's result goes to a
 * temporary whose address is the hidden first argument. This is 5c's
 * and 7c's convention, so that what simple compiles calls libc, and is
 * called by it.
 *
 * The frame: Declare's autos, then the temporaries (the arguments'
 * values, the results' structures, a switch's value), freed after each
 * statement; Gen adds the stack's spills and the outgoing area.
 *
 * A statement, to see the conditions and the addresses (mini-cc
 * -simple -dir, shortened: p for Lea p+0(FP) and so on):
 *
 *     for(i = 0; i < n; i++) s += p[i];
 *
 *         i; Int 0; Store; Drop              i = 0
 *     L1: i; Load; n; Load; Op Lt; Jz L3     the test, a 1 or a 0 popped
 *         s; Dup; Load                       s's address kept under its
 *         i; Load; Int 4; Op Mul             value; p + i * 4, Check's
 *         p; Load; Swap; Op Add; Load        scaling; its content
 *         Op Add; Store; Drop                added, stored through the
 *     L2: i; Dup; Load; ...; Store; Drop     address kept; i++
 *         Jmp L1
 *     L3:
 *
 * The tree is walked once and each node writes its part, as cgen
 * does in compat; what is not done is to look at a node's
 * neighbours first. So i < n makes a 1 or a 0 that the jump tests
 * at once, s += is an address, a Dup and a Load where the machine
 * has an instruction for it, and it is Opti that sees those pairs
 * afterwards (branch, places).
 *
 * design:
 * Two passes that do little against one that does much. compat's
 * Cgen decides everything as it walks the tree: which register,
 * which side first, whether a constant fits the instruction, a
 * dozen special cases an operator; it is 950 lines and each line
 * knows 5c's choices. Here the walk knows the language only, Gen
 * the machine only, and the stack code between them is where a
 * third party can stand: the optimizer, the dump, the Datalog facts
 * (Ir_facts). It is the argument for an intermediate language, on
 * the smallest example that has both ways side by side.
 *
 * References: plan_cc.md, "Amendment: two back ends" and decision 8;
 * A. P. Ershov, "On programming of arithmetic operations"
 * (Communications of the ACM 1(8), 1958, from memory), for the
 * number that orders two operands. *)

val func : Tree.sym -> Tree.stmt -> Ir.func

(* an instruction, and a function, as mini-cc -dir prints them *)
val show_func : Ir.func -> string

(* the front end's hook (Check.xcom): on arm, a vlong's operations as
 * calls to libc (Com64), bottom up; on arm64 the tree as it is *)
val calls64 : Tree.expr -> Tree.expr
