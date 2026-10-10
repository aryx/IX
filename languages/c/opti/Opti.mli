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
 * or a jump rather than follow the paths.
 *
 * All of them on Lower's example, for(i = 0; i < n; i++) s += p[i],
 * on arm64 (mini-cc -m 7 -simple -O -S, the NOPs Peep leaves taken
 * out; regs gave i R19, s R20, n R21 and p R22):
 *
 *     CMP   R21,R19            i < n?               (branch)
 *     BGE   out
 *     LSL   $2,R19,R2          i * 4                (imm)
 *     ADD   R22,R2,R2          p + i * 4
 *     MOVW  0(R2),R2           its content
 *     ADD   R2,R20,R1          s +, and s again     (places, drops)
 *     SXTW  R1,R20
 *     ADD   $1,R19,R1          i++                  (incs, imm)
 *     SXTW  R1,R19
 *     B     the test
 *
 * No load and no store but p[i]'s, where the code without -O has
 * some forty instructions a turn, and compat's, 7c's at -O0 with
 * every variable in memory, eighteen.
 *
 * cs-history:
 * regs is, in small, the pass Ken Thompson calls registerization:
 * his compilers first make code with every variable in memory, and
 * a later pass over the instructions is "to reintroduce registers for
 * heavily used variables", by the dataflow of where each is set
 * and used, a cost for each life of a variable in which "the costs
 * are multiplied by three for every level of loop nesting", and
 * the registers given to the most costly first. It is the reverse
 * of the usual order (everything in virtual registers, then spill
 * what does not fit: Chaitin's, mini-ml's Alloc has that story),
 * and what makes -O0 easy: turn the pass off.
 *
 * design:
 * The caller saves. Plan 9's convention keeps no register across a
 * call, where most others (the ARM's own among them) split the
 * registers into the caller's and the callee's. Thompson gives the
 * argument that settles it for him: "with caller-saves, the
 * decision to registerize a variable can include the cost of
 * saving the register across calls". regs does exactly that sum, a
 * use's gain against a call's cost; and longjmp and the debugger
 * have no saved registers to look for in other frames, his other
 * reasons. mini-ml's collector relies on the same rule: no value is
 * in a register across a call.
 *
 * References: Ken Thompson, "Plan 9 C Compilers", sections
 * "Registerization" and "Register saving"; plan_cc.md, "Later:
 * opti/", the measurements each pass answers; mini-ml's Opti, the
 * same idea on its own stack machine. *)

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
