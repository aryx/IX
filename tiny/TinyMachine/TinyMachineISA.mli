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
 * test of this file. *)

(* The instructions, and their words (an immediate is a word's low 16
 * bits, encode says what does not fit); the ALU's operations and the
 * branches' tests in their opcodes' order, with their names; an
 * immediate form's name *)
type reg = int
type alu =
  | Add | Sub | Mul | Div | Rem | And | Or | Xor | Shl | Shr | Sar | Slt | Sltu
type cmp = Eq | Ne | Lt | Ge | Ltu | Geu
type size = W | B
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
val sp : int
val lr : int
val csr_names : string array

(* what is wrong in a program's text, said to the person *)
exception Error of string
val error : string -> 'a

(* a number in hexadecimal: 0x1f *)
val hex : int -> string

(* An object, tiny-assembler's for tiny-linker: a file's items in its
 * order. A label is an address the link chooses. A chunk is an
 * instruction's words or data's bytes, in the memory's order, with the
 * places in them to fill: an offset in the chunk, the kind of place
 * (word: all 32 bits; abs: the immediate; hi and lo: the immediate,
 * the address's high or low half; pc: the immediate, the words from
 * the next instruction to the target) and the target, a label or an
 * address (a branch to a number). Space is zeros (.space); an
 * alignment stays an item, since what it pads depends on the address;
 * after a piece (.piece), what follows up to the next one is left out
 * by the link when nothing reaches it (tiny-ml's functions and static
 * blocks); a section is the data's (true, .data) or the text's. *)
type place = Word | Abs | Hi | Lo | Pc
type target = Name of string | Address of int
type item =
  | Label of string | Align of int | Space of int
  | Chunk of string * (int * place * target) list | Piece
  | Section of bool

(* an item as OCaml writes it, derived by mini-ml ("NO DERIVING" when
 * OCaml or tiny-ml compiles this file): tiny-linker -v's *)
val show_item : item -> string

(* the object's bytes, marshalled after a magic line, and back (Error
 * when it is not one) *)
val to_object : item list -> string
val of_object : string -> item list
