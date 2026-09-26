(* A peephole on the machine instructions Gen made for a function
 * (mini-cc -simple -Opeep, in -O): copy propagation, as 5c's peep.c
 * copyprop. The stack machine copies a value into its slot's register
 * before using it (MOV R19,R1 for a variable in R19); after such a
 * move, the reads of the copy read the original, until either is
 * written or the block ends (a branch, a call, or an instruction a
 * branch goes to), and the move, once its copy is overwritten, is
 * dead. It becomes a NOP, which mini-ld drops as it drops 5c -O0's,
 * the branches to it moved to the next: no pc renumbered here. Then
 * dead code: an instruction whose only effect is a register that no
 * one reads after it (a backward liveness dataflow over the
 * instructions, as regs's over the variables) is a NOP too, until
 * none is.
 *
 * What an instruction reads and writes is read off its operands, for
 * the instructions Gen makes: the registers of from and reg, a memory
 * operand's base, and the destination too for a two-operand
 * arithmetic (ADD R2,R1) but not for a move, an extension or a
 * conversion. *)

(* the function just generated, the last in Emit's instructions *)
val run : unit -> unit
