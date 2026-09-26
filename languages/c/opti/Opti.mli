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
 * Each is a function from the code to the code, most a peephole on the
 * list; places is the one that looks further, by the stack's height
 * (each instruction's slots read and pushed), and gives up at a label
 * or a jump rather than follow the paths. *)

val passes : (string * (Lower.ir list -> Lower.ir list)) list

(* the passes named, in the order of [passes] *)
val run : string list -> Lower.func -> Lower.func
