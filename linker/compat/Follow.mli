(* 5l's and 7l's follow (xfol): the code in the order its flow goes,
 * a conditional branch inverted when that makes its target the next
 * instruction, a short run that ends the flow copied instead of a
 * branch to it, and the dead code dropped. It is how 5l and 7l lay the
 * code out, so mini-ld's executables are goken's byte for byte with it
 * (the default); it changes no program's behavior, and mini-ld
 * -nofollow keeps the code in the objects' order. [ends]: the
 * machine's, what ends the flow (a B, a RET).
 *
 * An if with an else, as a compiler writes it, and after:
 *
 *         CMP  $0, R0                  CMP  $0, R0
 *         BEQ  else                    BEQ  else
 *         MOVW $1, R1                  MOVW $1, R1
 *         B    end                     RET             <- a copy
 *     else:                        else:
 *         MOVW $2, R1                  MOVW $2, R1
 *     end:                             RET
 *         RET
 *
 * The walk starts at the first instruction and goes where the
 * processor would: straight on, and at an unconditional B, to its
 * target, the B itself not written (the then branch runs into the
 * RET). At a conditional branch it goes on first, and comes back for
 * the target after (else:). Arriving at code already written, as the
 * else branch does at end:, it must jump there, unless the next four
 * instructions or fewer end the flow: those are written again, a
 * RET costing no more than the B to it. An instruction the walk
 * never reaches (after a RET, with no label on it) is not written
 * at all.
 *
 * design:
 * This is a compiler's pass put in the linker, for the same reason
 * as the encoding: here it is written once for the assembler's code
 * and the compiler's, and the compiler may write its loops and its
 * ifs in the simplest way, a B wherever one is easy, knowing they
 * will be straightened. A compiler today does it itself, on its
 * graph of basic blocks, with the branches' probabilities.
 *
 * References: Ken Thompson, "Plan 9 C Compilers", section "The
 * loader": code "reordered to remove unconditional branch
 * instructions", conditional branches inverted, and a few instructions
 * copied instead of a branch. *)

val follow : 'm Program.t -> ends:('m Program.prog -> bool) -> unit
