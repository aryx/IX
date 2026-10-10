(* Passes on the simple back end's stack machine (Lower's code, before
 * Gen), each switchable (mini-cc -simple -O, or -O<name> for one): the
 * same code in, faster code out, the program's behavior unchanged.
 * They were chosen by measuring (mini-5i -s and -t, plan_cc.md's opti
 * amendment) where -simple's code spends instructions compat's does
 * not:
 *
 * - incs: x++ as a statement is ++x (no old value kept, then dropped),
 *   and x++ of a variable as a value keeps the old value by a dup,
 *   not Lower's swap and over;
 * - places: lea m; load is a load from m, and lea m, a value, store is
 *   the value stored to m (x op= y too): no address in a register;
 * - imm: a constant operand is the instruction's immediate, and a
 *   multiplication by a power of 2 a shift;
 * - branch: a comparison and its jump are one compare and branch, no
 *   1 or 0 between;
 * - drops: a stored value thrown away is not kept (put), a conversion
 *   that changes no value is nothing (to its own type, or wider from
 *   a type the wider one holds), and so is a swap before a commutative
 *   operation of integers.
 *
 * - regs: a function's variables in registers (5c's regopt, freely):
 *   the autos and parameters whose address is never taken, chosen by
 *   their uses weighted by loop depth (a jump back makes a loop), less
 *   what saving them costs at the calls they are live across (a
 *   backward liveness dataflow, to its fixpoint): Plan 9 saves no
 *   register across a call, so they go to their slots before one and
 *   come back after. arm64's R19-R25 and F17-F23; arm has none left.
 *
 * Each is a function from the code to the code, most a peephole on the
 * list; places is the one that looks further, by the stack's height
 * (each instruction's slots read and pushed), and gives up at a label
 * or a jump rather than follow the paths. *)

val passes : (string * (Ir.t list -> Ir.t list)) list

(* the passes named, in the order of [passes] *)
val run : string list -> Ir.func -> Ir.func

(* regs' own analysis, for an analysis written elsewhere to be checked
 * against (mini-cc -dflow; facts/Ir_facts): the variables a register
 * may hold, each instruction's successors, and the variables (their
 * numbers in that list) live after each instruction *)
val variables : Ir.t array -> (Ir.mem * Ir.ty) list
val successors : Ir.t array -> int list array
val liveness : Ir.t array -> int list array -> (Ir.mem -> int option) -> int Set_.t array
