(* The stack machine on the registers, for arm64 and arm (the simple
 * back end): the
 * slot at depth i is Ri or Fi as its value is an integer or a float
 * (R1-R15 and F1-F15 on arm64, R1-R7 and F1-F6 on arm), so an
 * expression deeper than that is refused. Every register is the
 * caller's to save, as in 5c's and 7c's convention: a call spills the
 * slots below its arguments, below the frame's locals, and reloads
 * them. Values are kept as their type makes them, extended to the
 * register's width, so that a comparison or a division of any width is
 * the register's; an operation's result is extended again.
 *
 * What differs between the machines is the [mach] record and the
 * mnemonics (the functions at the top): arm64's 64-bit registers,
 * SCVTF; arm's MOVW, DIV (5l makes it a call), MOVWD, and no unsigned
 * conversion to a float but through a signed one.
 *
 * Ir's example, an instruction at a time (mini-cc -simple -S, arm):
 *
 *     Lea y+4(FP)          MOVW $y+4(FP),R1      depth 1 is R1
 *     Load int             MOVW 0(R1),R1
 *     Int 2                MOVW $2,R2            depth 2 is R2
 *     Op (Mul, int)        MUL  R2,R1,R1
 *     Lea x+0(FP); Load    MOVW $x+0(FP),R2;  MOVW 0(R2),R2
 *     Swap                 MOVW R1,R8;  MOVW R2,R1;  MOVW R8,R2
 *     Op (Add, int)        ADD  R2,R1,R1
 *     Ret                  MOVW R1,R0;  RET
 *
 * Twelve instructions where compat, 5c's way, writes five for the
 * same function (Emit's header has them): each instruction of the
 * stack machine is translated alone, knowing only how deep the
 * stack is. That is the whole method, and what it costs; Opti's
 * passes, on the stack code, and Peep, on this output, are how much
 * of the difference a few local rewrites take back.
 *
 * cs-history:
 * A stack machine's stack kept in the registers of a real one is
 * how Niklaus Wirth's compilers make code in one pass, and what his
 * textbook teaches: the compiler keeps, as it goes, the number of
 * the next free register, and that number is the stack's height.
 * It needs no analysis and fails only on an expression too deep,
 * which nobody writes; here that is the refusal above. *)

(* how many variables the machine keeps in registers (Opti's regs):
 * integers, floats *)
val vregs : unit -> int * int

(* a function's code, from Lower's *)
val func : Ir.func -> unit
