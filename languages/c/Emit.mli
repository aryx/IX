(* The generated code (txt.c, swt.c, list.c, obj.c), whatever the back
 * end. This module holds:
 * - the instructions ([prog]);
 * - their operands, made from addressable trees ([naddr], which gives
 *   the assembler's Asm.operand);
 * - the data of initializers and strings;
 * - at the end, the GLOBLs, the listing (-S) and the object.
 * The registers and the frame's areas belong to each back end (Regs,
 * for compat).
 *
 * The object is mini-asm's Asm.obj, not goken's format: the compiler
 * produces what the assembler would, and mini-ld encodes both. The
 * listing ([listing]) has 5c's and 7c's format, including Plan 9's
 * %.17e for floats; compat's listing is the same as theirs, byte for
 * byte (tests/listing.sh).
 *
 * A function's instructions, as mini-cc -S prints them (with compat,
 * on arm; the NOPs and the RET after the end of the body are left
 * out):
 *
 *     int f(int x, int y) { return x + y * 2; }
 *
 *     TEXT  f+0(SB),0,$0       f, with a frame of 0 bytes
 *     MOVW  R0,x+0(FP)         the first argument comes in R0 and goes
 *     MOVW  y+4(FP),R0         to its slot; the others are in theirs
 *     SLL   $1,R0              y * 2
 *     MOVW  x+0(FP),R4
 *     ADD   R4,R0              the result is in R0
 *     RET
 *
 * Nothing here is an address or an encoding. x+0(FP) is a name and
 * an offset from a register that does not exist. FP stands for where
 * the arguments are, SP for the frame's locals, and SB for the
 * globals. The linker, which alone knows the frame's size and where
 * the data is, makes each an offset from a real register. MOVW is
 * every move of a word: from memory, to memory, or of a constant of
 * any size. RET is whatever returning takes once the frame is known. A
 * branch goes to an instruction, given by its number ([gbranch],
 * [patch]), because its distance in bytes is not known before the
 * linker either.
 *
 * plan9-is-cleaner:
 * There is no assembly text between the compiler and the linker, and
 * there are no relocations in the object. A Unix compiler writes
 * assembly, the assembler encodes it into bytes with holes, and the
 * object lists the holes for the linker to fill (ELF's relocations,
 * with a kind for each shape of hole on each machine). Plan 9's object
 * is the instructions themselves, not yet encoded ("binary forms of
 * assembly language"), and the linker encodes them when every address
 * is known. It can then choose a short form or a long one, and it
 * needs no list of holes. The price is Thompson's own second thought:
 * compiling runs in parallel and loading does not, so work moved to
 * the loader is real time lost.
 *
 * References: Ken Thompson, "Plan 9 C Compilers", section "Structure":
 * combined in the compiler are "the traditional roles of preprocessor,
 * lexical analyzer, parser, code generator, local optimizer, and first
 * half of the assembler"; A. V. Aho, M. S. Lam, R. Sethi and J. D.
 * Ullman, Compilers: Principles, Techniques, and Tools (2nd ed., 2006),
 * section 6.7, "Backpatching", for [gbranch] and [patch]: a branch is
 * emitted before its target is known, its hole is kept in a variable,
 * and the hole is filled once the target exists. *)

(* whether the machine is arm (5c's) rather than arm64; the number of
 * integer registers, after which the float registers are numbered in a
 * Reg node *)
val arm : unit -> bool
val nreg : unit -> int

(* what a pseudo-instruction declares: TEXT's flag, DATA's width *)
type pseudo = Pnone | Ptext of int | Pdata of int | Pglobl

(* from, reg and to are 5c's: the listing prints them in this order *)
type prog = {
  mutable as_ : string;
  mutable cond : string list;         (* .LS, .U, .W: the suffixes *)
  mutable from : Asm.operand option;
  mutable reg : int option;           (* a second source register (F if from is) *)
  mutable to_ : Asm.operand option;     (* Target is a pc until the end *)
  mutable pseudo : pseudo;
  ppc : int;                          (* the next pc, for DATA and GLOBL *)
  line : int;                         (* its statement's line, or its function's *)
}

(* the instructions, the last first; the pc of the next one *)
val progs : prog list ref
val pc : int ref

(* the line of the statement being generated (5c's nearln), set by the
 * compat back end; 0 means the function's line (Declare.fnline) *)
val line : int ref

(* the last instruction; a new one *)
val p : unit -> prog
val nextpc : unit -> prog

(* a constant cut to 32 bits, sign-extended (sx32) or not (mask32); an
 * offset as the machine's Adr holds it (sx: 32 bits on arm) *)
val sx32 : int64 -> int64
val mask32 : int64 -> int64
val sx : int64 -> int64

(* an addressable tree as an operand *)
val naddr : Tree.expr -> Asm.operand
val naddr_opt : Tree.expr option -> Asm.operand option
val add_off : Asm.operand option -> int -> Asm.operand option

(* an instruction from f to t *)
val gins : string -> Tree.expr option -> Tree.expr option -> prog
val ins : string -> Tree.expr -> Tree.expr -> unit

(* a branch, whose target is patched later *)
val gbranch : unit -> prog
val patch : prog -> int -> unit

(* TEXT, DATA, GLOBL of a symbol *)
val gpseudo : string -> Tree.sym -> Tree.expr -> prog

(* constants of type long and double *)
val nodconst : int64 -> Tree.expr
val nodfconst : float -> Tree.expr

(* when > 0, the code generated is thrown away, so no strings are
 * written *)
val suppress : int ref

(* writes n bytes of s in .string, and returns their offset *)
val outstring : string -> int -> int

(* an initializer's data: s at offset o, w bytes wide *)
val gextern : Tree.sym -> Tree.expr -> int -> int -> unit

(* the start of a file; its end, which writes the strings' last DATA
 * and the GLOBLs *)
val init : unit -> unit
val gclean : unit -> unit

(* the program as 5c's -S prints it, and as mini-asm's object *)
val listing : unit -> string
val obj : Fpath.t -> Asm.obj
