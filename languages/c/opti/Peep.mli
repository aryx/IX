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
 * conversion.
 *
 * On x + y * 2 with x in R19 (mini-cc -m 7 -simple -S, Opti's passes
 * without this one, then with it):
 *
 *     MOV   R19,R2           NOP                  the copy's one reader
 *     ADD   R2,R1,R1         ADD   R19,R1,R1      reads the original
 *     SXTW  R1,R1            SXTW  R1,R0          and a result is made
 *     MOV   R1,R0            NOP                  where it is wanted
 *
 * It is the pass that mends what the method before it made on
 * purpose: Gen translates an instruction of the stack machine alone,
 * so a variable in a register is first copied to the stack's
 * register, and only a look at two instructions together shows the
 * copy was for nothing. Thompson says the same of his own compilers:
 * the moves his peephole removes, "ironically", were mostly put
 * there by the pass before.
 *
 * cs-history:
 * The peephole is W. M. McKeeman's (1965): slide a window of a few
 * instructions over the code a simple compiler made, and replace
 * the sequences known to be silly by better ones. It let a
 * compiler stay simple and its code be decent, and it has never
 * left: gcc and LLVM still end with one, however much they did
 * before it.
 *
 * References: W. M. McKeeman, "Peephole optimization"
 * (Communications of the ACM 8(7), 1965); Ken Thompson, "Plan 9 C
 * Compilers", section "Machine code optimization", whose first
 * pattern this is (a move removed by renaming its destination's
 * uses to its source). *)

(* the function just generated, the last in Emit's instructions *)
val run : unit -> unit
