(* tiny-machine's instructions and their words: what tiny-assembler
 * makes, tiny-linker fills, and TinyMachineCPU runs (its header has
 * the machine, the format and the design). A file of its own so that
 * the assembler and the linker, which need the words and not the
 * interpreter, are compiled by tiny-ml and run on tiny-kernel; the
 * interpreter keeps OCaml's 32-bit loads, which the machine's speed is
 * made of.
 *
 * In m-ix a word's two directions are two programs' and two types:
 * mini-ld's Arm encodes its opcodes (5.out.h's), mini-5i's Arm32_isa
 * decodes a word into a variant of its own, checked against objdump.
 * Here one type serves both directions, in one file, so the listing's law
 * (TinyMachineCPU's: a listing reassembled gives the same words) is a
 * test of this file.
 *)

(* The instructions, and their words (an immediate is a word's low 16
 * bits, encode says what does not fit); the ALU's operations and the
 * branches' tests in their opcodes' order, with their names; an
 * immediate form's name 
 *)

type reg = int

type alu =
  | Add | Sub | Mul | Div | Rem
  | And | Or | Xor
  | Shl | Shr | Sar | Slt | Sltu
type cmp = Eq | Ne | Lt | Ge | Ltu | Geu
type size = W | B

(* op dest, src *)
type instr =
  | Alu of alu * reg * reg * reg          (* d, a, b *)
  | Alui of alu * reg * reg * int
      (* d, a, imm: add and or xor shl shr sar slt sltu *)
  | Lui of reg * int
  | Load of size * reg * reg * int        (* d, a, offset *)
  | Store of size * reg * reg * int       (* the value's register, a, offset *)
  | Branch of cmp * reg * reg * int       (* d, a, offset in words, from pc + 4 *)
  | Jal of reg * int
  | Jalr of reg * reg * int
  | Sys of int

val alus : alu array
val alu_names : string array
val cmps : cmp array
val cmp_names : string array

val index : 'a array -> 'a -> int
val imm_name : alu -> string

val unsigned_imm : alu -> bool
val has_imm : alu -> bool
val sext16 : int -> int

val encode : instr -> int
val decode : int -> instr option

(* an instruction as assembly, given its address *)
val print : int -> instr -> string

(* the stack pointer's register and the link's; the machine's
 * registers of control, by number (csrr's, csrw's) *)
val sp : reg
val lr : reg
val csr_names : string array

(* what is wrong in a program's text, said to the person *)
exception Error of string
val error : string -> 'a

(* the machine's own instructions, which TinyMachineDevices runs, not
 * the CPU (whose decode does not know them): a register of control by
 * its number in csr_names *)
type machine_instr =
  | Csrr of reg * int                 (* d, csr *)
  | Csrw of int * reg                 (* csr, a *)
  | Eret
  | Wfi
  | Csrrw of reg * int * reg          (* d, csr, a: both at once *)
  | Amoswap of reg * reg * reg        (* d, a, (b) *)

val encode_machine : machine_instr -> int

(* a number in hexadecimal: 0x1f *)
val hex : int -> string

(* An object, tiny-assembler's for tiny-linker: a file's items in its
 * order. A chunk is an instruction's words or data's bytes, already
 * made, but where an operand is a label, whose address only the link
 * knows: there the assembler leaves 0, and says what the linker must
 * put in its place.
 *
 * The places, by example (msg a label the link puts at 0x12345678):
 *
 *     the assembly     the words, the 0s        the place, and its 0 becomes
 *     la r1, msg       lui r1, 0                Hi    0x1234, the high half
 *                      ori r1, r1, 0            Lo    0x5678, the low half
 *     call f           jal lr, 0                Pc    the words from the
 *     beq r1, zero, f  beq r1, zero, 0                next instruction to f
 *     ldw r1, x(r2)    ldw r1, 0(r2)            Abs   x, in the 16 bits of
 *                                                     the immediate
 *     .word msg        0                        Word  0x12345678, all 32
 *                                                     bits of the word
 *)
type place = Word | Abs | Hi | Lo | Pc

(* what goes there: a label's address, or a number (a branch to an
 * address, its offset from where the link puts the branch) *)
type target = Name of string | Address of int

type item =
  | Label of string                   (* an address the link chooses *)
  | Align of int                      (* stays an item: what it pads
                                       * depends on the address *)
  | Space of int                      (* zeros, .space *)
  | Chunk of string * (int * place * target) list
      (* the bytes, in the memory's order, and the places to fill: an
       * offset in the bytes, its kind, what goes there *)
  | Piece
      (* .piece: what follows, up to the next piece, is left out by the
       * link when nothing reaches it (tiny-ml's functions and static
       * blocks) *)
  | SectionCode                       (* .text: what follows is code *)
  | SectionData                       (* .data: what follows is data *)

(* for tiny-linker -debug's *)
val show_item : item -> string

(* the object's bytes, marshalled after a magic line, and back (Error
 * when it is not one) *)
val to_object : item list -> string
val of_object : string -> item list
