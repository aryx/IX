(* A stack walked, frame by frame, from where a program stopped
 * (principia's debuggers/libmach, machdata.c's risctrace for arm;
 * plan_debugger.md, stage 3): its functions, the innermost first, each
 * with the address it is at and its file and line.
 *
 * On arm the caller's address is in the link register, R14, at the
 * call; a function that calls another saves it on the stack first.
 * 5l's prologue does it in one instruction, and its frame's size is in
 * the symbol table (.frame), so a function's frame is
 *
 *     sp ->  | the return address |  0(SP)
 *            | its locals         |
 *            | ...                |  .frame bytes in all
 *     the caller's sp ->
 *
 * and the walk is: the return address at 0(SP) (the link register for
 * a leaf, which saves nothing, or before the prologue has run), the
 * caller's sp .frame bytes higher, and again from the call, until the
 * program's _main.
 *
 * mini-ml's functions have the same frame, made by themselves (TEXT
 * $-4 to the linker: no frame of 5l's, so the table says L, a leaf,
 * and .frame 0): their first instructions,
 *
 *     SUB   $n, R13          (or a constant loaded into R11, then
 *     MOVW  R14, 0(R13)       SUB R11, R13 for a large n)
 *
 * are read from the text, the frame's size n from them: gdb's way, a
 * prologue analysed (ours; libmach has the table only).
 *
 * References: principia's debuggers/libmach (machdata.c, 5db.c); gdb's
 * "frame unwinders" (prologue analysis, before DWARF's call frame
 * information). *)

type frame = {
  pc : int;                         (* an address in the function: the fault's, then each call's *)
  func : string;
  offset : int;                     (* from the function's start *)
  line : (string * int) option;     (* its file and line *)
}

(* [walk t ~load ~pc ~sp ~lr]: the frames from the registers of a stopped
 * program; [load] a word of its memory (None: not mapped). 40 at most *)
val walk : Symbols.t -> load:(int -> int option) -> pc:int -> sp:int -> lr:int -> frame list

(* the frames as a line, the innermost first: f+0x10 a.c:12 < g+0x2c a.c:30 *)
val show : frame list -> string
