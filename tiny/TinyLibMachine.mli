(* tiny-machine's libmach: what every program that reads or writes the
 * machine's code shares. It plays the role of Plan 9's libmach, which
 * the debuggers and nm share (principia's debuggers/libmach: decoding
 * instructions, the format of executables, the symbol tables). This
 * module has four parts:
 *
 *     the instructions     instr, and their words: encode, decode, and
 *                          their text and listing (tiny-cpu -l, debug)
 *     the lines            line: the assembly that the compilers make
 *                          (TinyC/Machine.ml, TinyML/Machine.ml) and
 *                          that tiny-as parses; print_line gives its
 *                          text (-S)
 *     the objects          the lines once encoded (assemble): what the
 *                          compilers and tiny-as write (to_object) and
 *                          tiny-ld reads (of_object)
 *     the symbols          a program's labels as tiny-ld writes them,
 *                          for tiny-prof and debug
 *
 * Read TinyMachine/TinyMachineCPU.mli first: the machine, the format of
 * its words, and the design. The interpreter of the CPU is not here:
 * it relies on OCaml's 32-bit loads, which make the machine fast.
 * Everything here is compiled by tiny-ml too, so that the toolchain
 * runs on tiny-kernel.
 *
 * In m-ix, encoding and decoding a word are done by two programs with
 * two different types: mini-ld's Arm encodes the opcodes (those of
 * 5.out.h), and mini-5i's Arm32_isa decodes a word into a variant of
 * its own, checked against objdump. Here one type serves both
 * directions, so the law of the listing (stated in TinyMachineCPU: a
 * listing reassembled gives the same words) is a test of this file.
 *)

(*****************************************************************************)
(* The instructions *)
(*****************************************************************************)

(* An immediate is the low 16 bits of a word; encode reports what does
 * not fit. alus and cmps are in the order of their opcodes. *)

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
  | Branch of cmp * reg * reg * int
      (* d, a, offset in words, from pc + 4 *)
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

(* The word of an instruction is an int on purpose: its opcode is under
 * 0x40, so it fits tiny-ml's 31-bit ints. The CPU decodes a word at
 * each step, and an Int32 is boxed in OCaml and is two 16-bit pieces in
 * tiny-ml. Any other 32 bits (an li's number, a .word, an illegal
 * instruction with any opcode) are an Int32, as they may not fit. *)
type instr_word = int
type word = int32

val encode : instr -> instr_word
val decode : instr_word -> instr option

(* zero, sp, lr, or r1 to r13 *)
val reg_name : reg -> string

(* [text i imm]: imm, when given (a label, an address), replaces the
 * immediate or offset. It is the only printer, used for listings and by
 * print_line. *)
val text : instr -> string option -> string

(* A branch's or jal's target is shown as an address. *)
val listing : int -> instr -> string

val sp : reg
val lr : reg
val csr_names : string array          (* by number, for csrr and csrw *)

(* An error in a program's text, reported to the user. *)
exception Error of string
val error : string -> 'a

(* These are run by TinyMachineDevices; the CPU's decode does not know
 * them. *)
type machine_instr =
  | Csrr of reg * int                 (* d, csr *)
  | Csrw of int * reg                 (* csr, a *)
  | Eret
  | Wfi
  | Csrrw of reg * int * reg          (* d, csr, a: both at once *)
  | Amoswap of reg * reg * reg        (* d, a, (b) *)

val encode_machine : machine_instr -> instr_word
val machine_text : machine_instr -> string

val hex : int -> string               (* 0x1f *)


(*****************************************************************************)
(* The lines of assembly *)
(*****************************************************************************)

(* Where the linker fills the 0 the assembler left, with msg a label
 * that the link puts at 0x12345678:
 *
 *     the assembly     the words, with 0s       the place, and its 0
 *     la r1, msg       lui r1, 0                Hi    0x1234, the high half
 *                      ori r1, r1, 0            Lo    0x5678, the low half
 *     call f           jal lr, 0                Pc    the words from the
 *     beq r1, zero, f  beq r1, zero, 0                next instruction to f
 *     ldw r1, x(r2)    ldw r1, 0(r2)            Abs   x, in the 16 bits of
 *                                                     the immediate
 *     .word msg        0                        Full  0x12345678, all 32
 *                                                     bits of the word
 *)
type place = Full | Abs | Hi | Lo | Pc

(* For a branch to an Address, the link writes the offset to it. *)
type target = Name of string | Address of int

type sym = string                     (* a label *)

(* An offset in a chunk's bytes, its kind of place, and what goes
 * there. *)
type reloc = int * place * target

(* A line of assembly, as a compiler makes it or the assembler reads it,
 * and its text:
 *
 *     the line                               its text
 *     Label "f"                              f:
 *     Instr (Alui (Add, sp, sp, -8))         addi sp, sp, -8
 *     Instr (Load (W, 1, 1, 0))              ldw r1, 0(r1)
 *     Instr_at (Load (W, 1, 2, 0), Abs, Name "x")
 *                                            ldw r1, x(r2)
 *     La (1, "f.s1")                         la r1, f.s1
 *     Branch_to (Eq, 1, 0, "f.L3")           beq r1, zero, f.L3
 *     Call "print"                           call print
 *     Machine (Csrr (1, 0))                  csrr r1, status
 *     Word_sym "f.s1"                        .word f.s1
 *
 * An instruction that refers to a label, whose address the link
 * chooses, says where it goes: Instr_at, la, call, j or Branch_to.
 *
 * An object is lines too, once they are encoded: Chunks of bytes, with
 * a reloc where an operand is a label, and the lines by which the link
 * places things (Label, Align, Space, Piece and the sections). *)
type line =
  | Instr of instr
  | Instr_at of instr * place * target  (* with 0 where the link writes *)
  | Machine of machine_instr
  | Li of reg * word
  | La of reg * sym                   (* a label's address *)
  | Mov of reg * reg                  (* d, a *)
  | Call of sym
  | Jump of sym                       (* j *)
  | Branch_to of cmp * reg * reg * sym
  | Ret
  | Label of sym                      (* an address the link chooses *)
  | Align of int                      (* kept in an object: the padding
                                       * depends on the final address *)
  | Space of int                      (* zeros *)
  | Bytes of int list
  | Ascii of string                   (* .ascii, or .asciz with its 0 *)
  | Word of word                      (* .word of a number *)
  | Word_sym of sym                   (* .word of a label's address *)
  | Piece
      (* .piece: the link leaves out what follows, up to the next piece,
       * when nothing reaches it (tiny-ml's functions and static
       * blocks) *)
  | SectionCode                       (* .text *)
  | SectionData                       (* .data *)
  | Chunk of string * reloc list      (* bytes in memory order *)

(* The text of a line, with its newline; an instruction or a directive
 * comes after a tab. *)
val print_line : line -> string

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* A line becomes a Chunk with a reloc where a label's address goes; a
 * label or an alignment stays, as the link does them (an alignment
 * depends on the address, not the place in the file). Raises Error
 * when an operand does not fit its field. *)
val encode_line : line -> line

(* Encodes each line, after an Align 4, so that a file starts on a word
 * whatever the previous one ended with. *)
val assemble : line list -> line list

(* The low byte comes first, as in memory. *)
val word_bytes : word -> string

(* to_object marshals the lines after a magic line; of_object raises
 * Error on bytes that are not an object, or on an object of an older
 * format. *)
val to_object : line list -> string
val of_object : string -> line list

(* An archive is a library: named objects in order, all of which tiny-ld
 * links. Error is raised when a member is not an object, a name has a
 * blank, or the bytes are not an archive. *)
val is_archive : string -> bool
val to_archive : (string * string) list -> string
val of_archive : string -> (string * string) list

val show_line : line -> string        (* as OCaml writes it, for -debug *)

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

(* A program's labels, as tiny-ld writes them: "address label" lines,
 * the address in hexadecimal, in a map next to the image (-map, read by
 * tiny-prof) or after the image in an a.out (-s, read by debug, as in
 * Plan 9's a.out symbol table). tiny-prof names the function where an
 * instruction was counted; debug names where a program stopped and
 * finds where to set a breakpoint (b main).
 *
 * A label that a compiler makes inside a function (tiny-ml's
 * TinyBrowser.L12, tiny-cc's tm.L51) is left out: an address after it
 * belongs to the function before it. The labels of a loop in assembly
 * (row_copy2) are kept, as they tell which loop.
 *
 * mini-ld in m-ix writes no symbol table. Plan 9's 5l writes a binary
 * one (principia's linkers/5l, debugging.c): a value, a type letter (T,
 * D, B) and a name per symbol, then a table from pcs to source lines,
 * which libmach reads for db and acid. Here a label is a line of text,
 * with no kind and no source lines. *)

type label = string
type address = int                    (* from the start of the image *)
type symbols = (label * address) array  (* sorted by address *)

(* Whether a compiler made the label inside a function. *)
val local : label -> bool

(* Gives browse for TinyBrowser.f151_browse; an anonymous function keeps
 * its whole name. *)
val clean : label -> string

(* Reads the "address label" lines, leaving out the local labels. *)
val labels : string -> symbols

(* The function pc is in (the last label at or before it), its name
 * cleaned, and its address. *)
val find : symbols -> address -> (string * address) option

(* A label's address, found by its name or its cleaned name (main,
 * browse). *)
val address : symbols -> string -> int option
