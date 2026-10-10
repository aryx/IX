(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Plan 9's assembly language, for arm and arm64: the instructions
 * mini-asm reads and writes, unencoded, into an object file, and that
 * mini-ld lays out and encodes.
 *
 *     TEXT  strchr(SB), $8           a function, the size of its frame
 *     MOVW  c+4(FP), R6              an argument: FP is the caller's frame
 *     MOVW  $table(SB), R1           an address: SB is the static base
 *     MOVW.EQ R1, R2                 a condition, as a suffix (arm)
 *     BNE   2(PC)                    a branch, counted in instructions
 *     DATA  msg+0(SB)/8, $"Hello, w" initialized data
 *     GLOBL msg(SB), $14             its size
 *
 * {b Why the assembler only parses, and the linker encodes.} This is
 * Plan 9's design (Thompson's and Pike's toolchain), the one xix
 * follows, and the one ix keeps, because it is the smallest:
 *
 * - {b No relocations.} The linker encodes after it has laid out the
 *   whole program, so every address is known when a word is made:
 *   objects carry no relocation records, and the linker has no
 *   relocation machinery, most of a Unix linker's complexity.
 * - {b One encoder per machine.} The C compiler will write these same
 *   instruction lists into an object, as 5c does, without printing
 *   assembly; the encoder is written once, in the linker, shared by
 *   both paths, instead of in the assembler and again in the compiler.
 * - {b Decisions made once, with everything known}: which form a branch
 *   takes, where literal pools go, how a large constant is built (an
 *   immediate where the machine has a form that holds it, else a load
 *   from a literal pool, on arm and on arm64), what a function's
 *   prologue is. With the encoding in the assembler, each needs a guess
 *   now and a fixup later.
 * - {b The machine is in one place.} This module and the parser are the
 *   same for both targets but for a table of register names; which
 *   instructions exist, with which operands, is decided by the linker's
 *   module for each machine (linker/Arm, linker/Arm64), which is where
 *   having two targets forces the code to say what is general.
 *
 * The costs don't matter here: an object is not machine code, so it
 * can only be listed, not disassembled; and the linker redoes the
 * encoding at each link, which is why Go moved it back into its
 * compiler and assembler in Go 1.3 (2014), for Google's large
 * programs.
 *
 * evolution:
 * This toolchain has had three lives. Thompson wrote it for Plan 9
 * (his paper of 1990 has the MIPS and the 68020 for its examples),
 * and a machine after another was added to it. Go started from
 * those sources: its first releases had Plan 9's 6a, 6c and 6l in
 * them, the Go compiler beside them writing the same objects, and
 * Go's assembler is still this language, pseudo-registers and all;
 * its linker gave the encoding back to the compiler in Go 1.3 (the
 * paragraph above). And 9front keeps the original, with a 7 for
 * arm64 where Plan 9's 7 was the Alpha.
 *
 * {b One instruction type for both machines} (xix has a typed tree per
 * machine): an opcode, its dot suffixes, and operands from one set.
 * The linker's classifier rejects what a machine can't encode.
 *
 * Where it stands: this file is the contract between four programs.
 * Parser_asm makes these items from a .s, mini-cc and mini-ml make
 * them from C and ML; mini-ar keeps objects in a library; Link reads
 * them into Program's instructions, which are these with what
 * linking adds (an address, a branch's target). The object file is
 * the value marshalled with a version number in front, so a program
 * of another day's types says so and does not crash.
 *
 * terminology:
 * The four pseudo-registers. SB, FP, SP and PC in an operand are not
 * registers of the machine but four ways of naming a place, which
 * the linker turns into a real register and an offset once it knows
 * the layout. name(SB), the static base: a global, by its name.
 * name+4(FP), the frame pointer: an argument, from the caller's
 * side of the frame; the name is a comment. name-4(SP): a local, from
 * the top of the frame. 2(PC): an instruction, counted from this
 * one. A function can so be written without knowing the size of its
 * own frame, which is on its TEXT line, and nothing changes in its
 * body when that size does. (On arm the real SB is R12, set once to
 * the data's start; SP is R13.)
 *
 * terminology:
 * TEXT, DATA, GLOBL are the three segments' names, kept from the
 * a.out of the first Unix (Exe.mli draws them): the text is the
 * code, read-only and shared; the data is what has an initial value
 * in the file; the bss, what a GLOBL with no DATA makes, is only a
 * size, zeroed when the program starts.
 *
 * others:
 * The operands go left to right, the destination last, on every
 * machine: MOVW $1, R0 puts 1 in R0. That is the order of the PDP-11's
 * assembler and of AT&T's syntax for the 386; ARM's own manuals, and
 * Intel's, put the destination first (mov r0, #1). The opcodes are
 * Plan 9's too, the same on all its machines where it can be (MOVW
 * is a load, a store or a move by its operands, where ARM has ldr,
 * str and mov), which is what lets one compiler's back end be
 * ported by changing little.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (Summer 1990 UKUUG
 * Conference, London), the design paper of this split: its loader
 * "combines the roles of second half of the assembler, global
 * optimizer, and loader", with the MIPS and the 68020 as examples;
 * Rob Pike, "A Manual for the Plan 9 assembler", for the syntax, the
 * pseudo-registers FP and SB, and the remark that the assemblers "are
 * really just variations of a single program" -- which one instruction
 * type makes literal; Russ Cox, "Go 1.3 Linker Overhaul" (2013), for
 * the move back, the encoding done once per package by the compiler
 * and the assembler because linking large programs redid it. *)

(* (No Asm.mli: the module is its types, and what goes with them.) *)

type arch = Arm | Arm64

(* a global name; [static] for name<>(SB), local to its file *)
type name = { sym : string; static : bool }

(* what a memory reference is relative to *)
type base = R of int | SB | FP | SP | PC

(* << >> -> @> *)
type shift_kind = Lsl | Lsr | Asr | Ror
(* old: an int, 0 to 3, the one the machines encode, indexing a table
 * of the arrows to print *)

(* a shift's count: a constant, or a register's *)
type shift_by = By_imm of int | By_reg of int
type shift = { reg : int; kind : shift_kind; by : shift_by }

type mem = {
  base : base;
  name : name option;        (* sym+off(SB) (and BL f(SB) is a call), or a
                                comment in name+off(FP) *)
  off : int64;
  index : shift option;      (* (R1)(R2), R2<<2(R1) *)
}

type operand =
  | Reg of int               (* R3; on arm64 31 is ZR or RSP, by context *)
  | FReg of int              (* F3 *)
  | Special of string        (* CPSR, FPCR, ...: registers without a number *)
  | Spr of int64             (* SPR(0x182000): a system register of arm64's, by its bits in MRS and MSR *)
  | Imm of int64             (* $42 *)
  | Fimm of float            (* $1.5 *)
  | Str of string            (* $"text" *)
  | Mem of mem               (* 8(R1), x+4(SB), c+4(FP), s-4(SP) *)
  | Addr of mem              (* $x(SB), $s-4(SP): the address itself *)
  | Shifted of shift         (* R1<<2 *)
  | Regs of int list         (* [R0-R3] *)
  | Pair of int * int        (* (R1, R2) *)
  | Target of int            (* a branch: an index into the object's items *)

type instr = { op : string; suffixes : string list; args : operand list }

type item =
  | Text of name * int * int64          (* flag, frame size *)
  | Globl of name * int * int64         (* flag, size *)
  | Data of name * int64 * int * operand (* offset, width, value *)
  | Ins of instr

type obj = { arch : arch; file : Fpath.t; items : (item * int) array (* and its line *) }

(* the conditions both machines test, as 5a and 7a name them (CS and
 * CC are HS and LO); shared by the assembler, the linkers and the
 * compiler *)
(* old: strings in each, and in each linker a table inverting them *)
type cond = EQ | NE | HS | LO | MI | PL | VS | VC | HI | LS | GE | LT | GT | LE

(* the opposite condition *)
let invert = function
  | EQ -> NE | NE -> EQ | HS -> LO | LO -> HS | MI -> PL | PL -> MI | VS -> VC | VC -> VS
  | HI -> LS | LS -> HI | GE -> LT | LT -> GE | GT -> LE | LE -> GT

(* the code both machines give it (arm's always is 14) *)
let cond_bits = function
  | EQ -> 0 | NE -> 1 | HS -> 2 | LO -> 3 | MI -> 4 | PL -> 5 | VS -> 6 | VC -> 7
  | HI -> 8 | LS -> 9 | GE -> 10 | LT -> 11 | GT -> 12 | LE -> 13

let string_of_cond = function
  | EQ -> "EQ" | NE -> "NE" | HS -> "HS" | LO -> "LO" | MI -> "MI" | PL -> "PL" | VS -> "VS" | VC -> "VC"
  | HI -> "HI" | LS -> "LS" | GE -> "GE" | LT -> "LT" | GT -> "GT" | LE -> "LE"

let cond_of_string =
  let all = List.map (fun c -> string_of_cond c, c) [ EQ; NE; HS; LO; MI; PL; VS; VC; HI; LS; GE; LT; GT; LE ] in
  function "CS" -> Some HS | "CC" -> Some LO | s -> List.assoc_opt s all

(* the objects: marshalled, with a version, as xix's; 4: a shift's
 * count By_imm or By_reg, not a polymorphic variant;
 * 5: an operand may be a system register (Spr) *)
let version = 5

(* the files through the capabilities *)
let save caps file (o : obj) = FS.write caps file (Marshal.to_string (version, o) [])

let load caps file : obj =
  let v, (o : obj) = Marshal.from_string (FS.read caps file) 0 in
  if v <> version then failwith (Fpath.to_string file ^ ": an object of another version");
  o

(* (an item as text, the linker's messages and listing: Show_asm) *)
