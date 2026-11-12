(* tiny-machine's libmach: what every program that reads or writes the
 * machine's code shares, as Plan 9's libmach is what its debuggers and
 * nm share (principia's debuggers/libmach: the instructions decoded, the
 * executables' format, the symbol tables). Here:
 *
 *     the instructions     instr, and their words: encode, decode,
 *                          text and listing (tiny-cpu -l, debug)
 *     the lines            line: the assembly the compilers make
 *                          (TinyC/Machine.ml, TinyML/Machine.ml)
 *                          and tiny-as reads (its
 *                          parse); print_line its text (-S)
 *     the objects          the lines once encoded (assemble): what the
 *                          compilers and tiny-as write
 *                          (to_object) and tiny-ld reads
 *                          (of_object)
 *     the symbols          a program's labels as tiny-ld writes them,
 *                          for tiny-prof and debug
 *
 * Read TinyMachine/TinyMachineCPU.mli first: the machine, the format of
 * its words, and the design. Its interpreter keeps OCaml's 32-bit
 * loads, which the machine's speed is made of, and is not here: what
 * is here tiny-ml compiles, so that the toolchain runs on tiny-kernel.
 *
 * old: TinyMachine/TinyMachineISA.ml (the instructions, the objects),
 * TinyMachine/TinyMachineAsm.ml (the lines, their parse and print) and
 * TinyLibSymbols.ml, in one file (docs/plans/done/plan_tiny_libmach.md):
 * the toolchain's, not tiny-machine's parts; the objects the lines'
 * type, not an item type of their own with the same constructors;
 * parse tiny-as's, the only program that reads assembly.
 *
 * In m-ix a word's two directions are two programs' and two types:
 * mini-ld's Arm encodes its opcodes (5.out.h's), mini-5i's Arm32_isa
 * decodes a word into a variant of its own, checked against objdump.
 * Here one type serves both directions, so the listing's law
 * (TinyMachineCPU's: a listing reassembled gives the same words) is a
 * test of this file.
 *)

(*****************************************************************************)
(* The instructions *)
(*****************************************************************************)

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

(* The machine's words, of two kinds. An instruction's word, as encode
 * makes it and decode reads it, is an int on purpose: its opcode is
 * under 0x40, so the word is under 2^30 and fits tiny-ml's 31-bit ints
 * as well as OCaml's. tiny-machine's CPU decodes a word at each step,
 * and an int costs nothing there, where an Int32 is boxed on OCaml and
 * two pieces of 16 bits on tiny-ml. Any other 32 bits (a number of
 * li, a .word, an illegal instruction's word, which may have any
 * opcode) is a word, an Int32: on tiny-ml it may not fit an int.
 * (old: an int for both, and an int64 for the lines' numbers) *)
type instr_word = int
type word = int32

val encode : instr -> instr_word
val decode : instr_word -> instr option

(* a register's name: zero, sp, lr, or r1 to r13 *)
val reg_name : reg -> string

(* [text i imm]: an instruction's text, its registers by their names;
 * its immediate, or its offset, imm when there is one (a label's name,
 * an address): the one printer of the instructions, the listings' and
 * the assembly's (print_line) *)
val text : instr -> string option -> string

(* [listing pc i]: an instruction as a listing shows it, at the address
 * pc: a branch's or a jal's target as an address *)
val listing : int -> instr -> string

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

val encode_machine : machine_instr -> instr_word
(* its text, a register of control by its name *)
val machine_text : machine_instr -> string

(* a number in hexadecimal: 0x1f *)
val hex : int -> string


(*****************************************************************************)
(* The lines of assembly *)
(*****************************************************************************)

(* An object's places, by example: where a label's address goes, the
 * linker filling the 0 the assembler left (msg a label the link puts
 * at 0x12345678):
 *
 *     the assembly     the words, the 0s        the place, and its 0 becomes
 *     la r1, msg       lui r1, 0                Hi    0x1234, the high half
 *                      ori r1, r1, 0            Lo    0x5678, the low half
 *     call f           jal lr, 0                Pc    the words from the
 *     beq r1, zero, f  beq r1, zero, 0                next instruction to f
 *     ldw r1, x(r2)    ldw r1, 0(r2)            Abs   x, in the 16 bits of
 *                                                     the immediate
 *     .word msg        0                        Full  0x12345678, all 32
 *                                                     bits of the word
 *
 * (old: Word for Full, the name .word's line has now) *)
type place = Full | Abs | Hi | Lo | Pc

(* what goes there: a label's address, or a number (a branch to an
 * address, its offset from where the link puts the branch) *)
type target = Name of string | Address of int

(* a label *)
type sym = string

(* an offset in a chunk's bytes, its kind, what goes there *)
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
 * An instruction whose operands are known is Instr; one with a label in
 * it, whose address the link chooses, says where (Instr_at, or the
 * pseudo-instructions la, call, j and a branch to a label); li is a
 * number of 32 bits; then the directives.
 *
 * An object is lines too, once encoded: Chunk, the bytes made (an
 * instruction's words, data's bytes), with a reloc where an operand is
 * a label, and the lines the link places by: Label, Align, Space,
 * Piece and the sections. *)
type line =
  | Instr of instr
  | Instr_at of instr * place * target
      (* the instruction with 0 where a label's address, or an
       * address's offset from it (a branch to a number), goes: the
       * link fills it *)
  | Machine of machine_instr
  | Li of reg * word
  | La of reg * sym                   (* a label's address *)
  | Mov of reg * reg                  (* d, a *)
  | Call of sym
  | Jump of sym                       (* j *)
  | Branch_to of cmp * reg * reg * sym
      (* a branch to a label (old: Branch, the instruction's name) *)
  | Ret
  | Label of sym                      (* an address the link chooses *)
  | Align of int                      (* stays a line in the object: what
                                       * it pads depends on the address *)
  | Space of int                      (* zeros *)
  | Bytes of int list
  | Ascii of string                   (* .ascii, .asciz with its 0 *)
  | Word of word                      (* .word a number *)
  | Word_sym of sym                   (* .word a label's address *)
  | Piece
      (* .piece: what follows, up to the next piece, is left out by the
       * link when nothing reaches it (tiny-ml's functions and static
       * blocks) *)
  | SectionCode                       (* .text: what follows is code *)
  | SectionData                       (* .data: what follows is data *)
  | Chunk of string * reloc list
      (* in an object: the bytes, in the memory's order, and the places
       * to fill *)

(* a line's text, with its newline (an instruction or a directive after
 * a tab) *)
val print_line : line -> string

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* A line encoded, the object's: an instruction's words, with 0 where a
 * label's address goes and the place for the link (a branch's, a
 * call's: the words from the next instruction, Pc; la's: its halves, Hi
 * and Lo); data's bytes; or the line itself, one the object keeps (a
 * label, an alignment, which the link does: an address's, not the
 * file's). Error when an operand does not fit its field. *)
val encode_line : line -> line

(* [assemble lines]: their object, each line encoded, after an Align 4:
 * a file starts on a word, whatever the one before ended with (the
 * assembler's, and the compilers', which make lines, not text) *)
val assemble : line list -> line list

(* a word's four bytes, the low first: the memory's order, an object's
 * chunks' and the linker's image's *)
val word_bytes : word -> string

(* the object's bytes, an object's lines marshalled after a magic line,
 * and back (Error when it is not one, or an older one) *)
val to_object : line list -> string
val of_object : string -> line list

(* an archive's bytes, objects kept by name in an order (tiny-ar
 * writes them, tiny-ld links them all in that order: a library),
 * and back; Error when a member is not an object, its name has a
 * blank, or the bytes are not an archive *)
val is_archive : string -> bool
val to_archive : (string * string) list -> string
val of_archive : string -> (string * string) list

(* a line as OCaml writes it, for tiny-ld -debug *)
val show_line : line -> string

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

(* A program's labels, as tiny-ld writes them: "address label" lines,
 * the address in hexadecimal, in a map beside the image (-map: what
 * tiny-prof reads) or after it in an a.out (-s: what debug reads, Plan
 * 9's a.out symbol table). tiny-prof names the function an instruction
 * was counted in, debug the one a stop is in and the one a breakpoint
 * is set at (b main); both by these functions, which were tiny-prof's.
 *
 * A label a compiler makes inside a function (tiny-ml's
 * TinyBrowser.L12, tiny-cc's tm.L51) is not a function, and is left
 * out: an address in it is in the function before it. An assembly
 * loop's labels (row_copy2) are kept, as they say which loop. tiny-ml's
 * functions are named TinyBrowser.f151_browse: shown as browse.
 *
 * m-ix has no twin of it: mini-ld writes no symbol table. Plan 9's 5l
 * writes one in binary after the image (principia's linkers/5l,
 * debugging.c: a symbol a value, a type letter, T text, D data, B bss,
 * and its name; then a table from pcs to source lines), which libmach
 * reads for db and acid. Here a label is a line, as in the map: no
 * kind, no source lines, nothing to decode. *)

(* a label, the linker's; an address, from the image's start; the
 * labels of a program, each with its address, by address (old: string
 * * int, the pairs unnamed) *)
type label = string
type address = int
type symbols = (label * address) array

(* [local name]: whether it is a label a compiler made inside a function *)
val local : label -> bool

(* [clean name]: a function's name as shown (browse for
 * TinyBrowser.f151_browse, but an anonymous one's whole) *)
val clean : label -> string

(* [labels text]: the labels of "address label" lines, but the local
 * ones, by address *)
val labels : string -> symbols

(* [find funcs pc]: the function pc is in (the last label at or before
 * it), its name cleaned, and its address *)
val find : symbols -> address -> (string * address) option

(* [address funcs name]: the address of the function of that name, or
 * cleaned name (main, browse) *)
val address : symbols -> string -> int option
