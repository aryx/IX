(* The stack machine on the registers, for arm64 and arm (the simple
 * back end). The slot at depth i is Ri or Fi, depending on whether its
 * value is an integer or a float (R1-R15 and F1-F15 on arm64, R1-R7 and
 * F1-F6 on arm), so an expression deeper than that is refused. Every
 * register is the caller's to save, as in 5c's and 7c's convention: a
 * call spills the slots below its arguments to memory, below the
 * frame's locals, and reloads them afterwards. A value is kept as its
 * type makes it, extended to the register's width, so that a comparison
 * or a division of any width can use the register's instruction; the
 * result of an operation is extended again.
 *
 * What differs between the machines is the [mach] record and the
 * mnemonics (the functions at the top). arm64 has 64-bit registers and
 * SCVTF. arm has MOVW, DIV (which 5l makes a call), MOVWD, and no
 * conversion from an unsigned integer to a float except through a
 * signed one.
 *
 * Ir's example, one instruction at a time (mini-cc -simple -S, on arm):
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
 * That is twelve instructions, where compat, which works 5c's way,
 * writes five for the same function (Emit's header shows them). Each
 * instruction of the stack machine is translated alone, knowing only
 * how deep the stack is. That is the whole method, and that is what it
 * costs. Opti's passes, on the stack code, and Peep, on this output,
 * show how much of the difference a few local rewrites can take back.
 *
 * cs-history:
 * Keeping a stack machine's stack in the registers of a real machine
 * is how Niklaus Wirth's compilers make code in one pass, and it is
 * what his textbook teaches. As it goes, the compiler keeps the number
 * of the next free register, and that number is the stack's height.
 * It needs no analysis and fails only on an expression that is too
 * deep, which nobody writes; here, that is the refusal above. *)

(* how many variables the machine keeps in registers (for Opti's regs),
 * as a count of integer registers and a count of float registers. On
 * arm, these are the stack's registers that a function never reaches
 * when its stack is at most [depth] slots deep. *)
val vregs : depth:int -> int * int

(* writes a function's code, from Lower's code *)
val func : Ir.func -> unit

(* What ssa/'s Ssa_gen uses to write its instructions: the machine and
 * its mnemonics by type; functions that make an instruction (with arm's
 * middle register); a function that extends a register's value to its
 * type (extend); the condition of a relation, and the mnemonic of a
 * branch. *)

type mach = {
  sp : int;
  word : int;
  nregs : int;
  nfregs : int;
  tmp : int;
  ftmp : int;
  ret : string;
  vregs : int list;
  vfregs : int list;
}

val mach : unit -> mach
val a64 : unit -> bool
val ins : string -> Asm.operand option -> Asm.operand option -> Emit.prog
val ins_reg : string -> int -> Asm.operand option -> Asm.operand option -> Emit.prog
val i1 : string -> Asm.operand -> unit
val i2 : string -> Asm.operand -> Asm.operand -> unit
val at : int -> int -> Asm.operand
val mov : unit -> string
val fmov : unit -> string
val load_op : Ir.ty -> string
val store_op : Ir.ty -> string
val extend : Ir.ty -> int -> unit
val int_op : Tree.binop -> string
val float_op : Tree.binop -> Ir.ty -> string
val prec : Ir.ty -> string
val cond : Tree.binop -> fl:bool -> Asm.cond
val branch : Asm.cond -> string
