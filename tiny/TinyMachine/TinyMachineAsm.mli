(* tiny-machine's assembly, as lines: what the compilers make (tiny-c's
 * TinyCMachine) and tiny-assembler reads, its text by print. An
 * instruction whose operands are known is TinyMachineISA's; the others
 * name a label, whose address the link chooses, and are the
 * assembler's pseudo-instructions (la, call, j, a branch to a label),
 * or a number of 32 bits (li); the rest are the directives.
 *
 *     the line                               its text
 *     Label "f"                              f:
 *     Instr (Alui (Add, sp, sp, -8))         addi sp, sp, -8
 *     Instr (Load (W, 1, 1, 0))              ldw r1, 0(r1)
 *     La (1, "f.s1")                         la r1, f.s1
 *     Branch (Eq, 1, 0, "f.L3")              beq r1, zero, f.L3
 *     Call "print"                           call print
 *     Word_sym "f.s1"                        .word f.s1
 *
 * Read TinyMachineISA.mli first: the instructions, and the object the
 * assembler makes of the lines.
 *)

(* a label *)
type sym = string

type line =
  | Instr of TinyMachineISA.instr
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
  | Word of int64                     (* .word a number *)
  | Word_sym of sym                   (* .word a label's address *)
  | Piece                             (* what follows left out by the link
                                       * when nothing reaches it *)
  | SectionCode                       (* .text: what follows is code *)
  | SectionData                       (* .data: what follows is data *)

(* a register's name: zero, sp, lr, or r1 to r13 *)
val reg : TinyMachineISA.reg -> string

(* a number's low 32 bits, signed, in decimal: a word's text *)
val word : int64 -> string

(* a line's text, with its newline (an instruction or a directive after
 * a tab) *)
val print : line -> string
