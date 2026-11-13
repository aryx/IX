(* This module walks a stack, frame by frame, from where a program
 * stopped (principia's debuggers/libmach, machdata.c's risctrace for
 * arm; plan_debugger.md, stage 3). It gives the stack's functions, the
 * innermost first, each with the address it is at and its file and
 * line.
 *
 * On arm, at a call, the caller's address is in the link register,
 * R14. A function that calls another one saves it on the stack first.
 * 5l's prologue does it in one instruction, and the frame's size is in
 * the symbol table (.frame), so a function's frame is
 *
 *     sp ->  | the return address |  0(SP)
 *            | its locals         |
 *            | ...                |  .frame bytes in all
 *     the caller's sp ->
 *
 * The walk takes the return address at 0(SP) (or the link register,
 * for a leaf, which saves nothing, or before the prologue has run).
 * The caller's sp is .frame bytes higher. Then it starts again from
 * the call, until it reaches the program's _main.
 *
 * mini-ml's functions have the same frame, but they make it
 * themselves. They give TEXT $-4 to the linker, so 5l makes no frame,
 * and the table says L, a leaf, with .frame 0. Their first
 * instructions,
 *
 *     SUB   $n, R13          (or a constant loaded into R11, then
 *     MOVW  R14, 0(R13)       SUB R11, R13 for a large n)
 *
 * are read from the text, and the frame's size n is taken from them.
 * This is gdb's way, the analysis of a prologue; it is ours, since
 * libmach has only the table.
 *
 * References: principia's debuggers/libmach (machdata.c, 5db.c); gdb's
 * "frame unwinders" (prologue analysis, before DWARF's call frame
 * information). *)

type frame = {
  pc : int;                         (* the fault's address, then each call's *)
  func : string;
  offset : int;                     (* from the function's start *)
  line : (string * int) option;     (* its file and line *)
}

(* [walk t load (pc, sp, lr)] gives the frames from the registers of a
 * stopped program, 40 at most. [load] reads a word of its memory,
 * including its text (for a prologue), as two halves of 16 bits, the
 * high one first, since an int has 31 bits on arm and an instruction
 * 32. It gives None when the word is not mapped. (The arguments have
 * no labels, because ocaml-light, mini-9pi's compiler, has none.) *)
val walk : Symbols.t -> (int -> (int * int) option) -> int * int * int -> frame list

(* the frames as a line, the innermost first: f+0x10 a.c:12 < g+0x2c a.c:30 *)
val show : frame list -> string
