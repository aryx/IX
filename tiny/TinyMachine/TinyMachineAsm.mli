(* tiny-machine's assembly, as lines: what the compilers make (tiny-c's
 * TinyCMachine, tiny-ml's TinyMLMachine), print's text, and what
 * tiny-assembler reads, parse's lines, then encodes. An instruction
 * whose operands are known is TinyMachineISA's; one with a label in it,
 * whose address the link chooses, says where (Instr_at, or the
 * pseudo-instructions la, call, j and a branch to a label); li is a
 * number of 32 bits; the rest are the directives.
 *
 *     the line                               its text
 *     Label "f"                              f:
 *     Instr (Alui (Add, sp, sp, -8))         addi sp, sp, -8
 *     Instr (Load (W, 1, 1, 0))              ldw r1, 0(r1)
 *     Instr_at (Load (W, 1, 2, 0), Abs, Name "x")
 *                                            ldw r1, x(r2)
 *     La (1, "f.s1")                         la r1, f.s1
 *     Branch (Eq, 1, 0, "f.L3")              beq r1, zero, f.L3
 *     Call "print"                           call print
 *     Machine (Csrr (1, 0))                  csrr r1, status
 *     Word_sym "f.s1"                        .word f.s1
 *
 * Read TinyMachineISA.mli first: the instructions, the places a label's
 * address goes, and the object the assembler makes of the lines.
 *)

(* a label *)
type sym = string

type line =
  | Instr of TinyMachineISA.instr
  | Instr_at of TinyMachineISA.instr * TinyMachineISA.place
                * TinyMachineISA.target
      (* the instruction with 0 where a label's address, or an
       * address's offset from it (a branch to a number), goes: the
       * link fills it *)
  | Machine of TinyMachineISA.machine_instr
  | Li of TinyMachineISA.reg * int64  (* a number, its low 32 bits *)
  | La of TinyMachineISA.reg * sym    (* a label's address *)
  | Mov of TinyMachineISA.reg * TinyMachineISA.reg   (* d, a *)
  | Call of sym
  | Jump of sym                       (* j *)
  | Branch of TinyMachineISA.cmp * TinyMachineISA.reg * TinyMachineISA.reg
              * sym
  | Ret
  | Label of sym
  | Align of int
  | Space of int                      (* zeros *)
  | Bytes of int list
  | Ascii of string                   (* .ascii, .asciz with its 0 *)
  | Word of int64                     (* .word a number *)
  | Word_sym of sym                   (* .word a label's address *)
  | Piece                             (* what follows left out by the link
                                       * when nothing reaches it *)
  | SectionCode                       (* .text: what follows is code *)
  | SectionData                       (* .data: what follows is data *)

(* a line's text, with its newline (an instruction or a directive after
 * a tab) *)
val print : line -> string

(* a line of text's lines: its labels, then its instruction or its
 * directive (.word a, b: a Word each); ; starts a comment. Raises
 * TinyMachineISA.Error, what is wrong in it *)
val parse : string -> line list
