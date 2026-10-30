(* arm64's frames for a frame's parameters and locals (plan_debugger.md,
 * stage 8a): the builtin strace's and f:v's, as Proc.walk is arm's.
 * port.acid's stk walks the frames in acid (arm64.acid's frames, by
 * each function's prologue); here the same walk says each frame's
 * base, its CFA (DWARF's Canonical Frame Address: the caller's SP at
 * the call), where both tables count a variable from:
 *
 *              | caller's frame |
 *     CFA ->   +----------------+  a parameter of 7c's at CFA+8+off
 *              | this frame     |  (Plan 9's p, the FP pseudo-register
 *              |                |  8 above), a local at CFA-off (a);
 *     SP  ->   +----------------+  gcc's at CFA+off (DW_OP_fbreg, its
 *                                  frame base DW_OP_call_frame_cfa)
 *
 * The CFA by the prologue, read in the program's file, its first
 * instructions:
 *
 *     STP.W (R29, R30), -n(RSP); MOV RSP, R29        gcc's: CFA = R29+n
 *     SUB $N, RSP; STP (R29, R30), m(RSP); ADD $m, RSP, R29
 *                                                    CFA = R29-m+N
 *     MOVD.W R30, -n(RSP)                            7c's: CFA = SP+n
 *     SUB $n, RSP; MOVD R30, 0(RSP)                  mini-ml's: SP+n
 *     SUB $n, RSP                                    gcc's leaf: SP+n
 *     (nothing)                                      a leaf: SP
 *
 * gcc's .eh_frame says the same exactly, for every instruction
 * (plan9port's dwarfcfa.c reads it); the prologue is what the acid
 * walk reads too. Not read: a frame of gcc -O2's, whose prologue
 * these are not (its frame then ends the walk). *)

type frame = {
  start : int64;            (* its function's *)
  pc : int64;
  cfa : int64;
  ret : int64;              (* where it returns to *)
}

(* the frames from the registers (pc, sp, the link R30, the frame
 * pointer R29), the innermost first, to the function isstart says
 * ends the stack: read8 an 8-byte word of the process, read4 an
 * instruction of the file, start the function around an address *)
val walk :
  (int64 -> int64 option) -> (int64 -> int64 option) -> (int64 -> int64 option) -> (int64 -> bool) ->
  int64 -> int64 -> int64 -> int64 -> frame list

(* a variable of a frame: a parameter or a local, its address and its
 * size in bytes *)
type var = { vname : string; param : bool; addr : int64; size : int }

(* a function's, by Plan 9's table: the entries after its symbol (p, a) *)
val plan9 : Symbols.sym list -> int64 -> var list

(* a function's, by DWARF: the subprogram at start (the file's address,
 * before a PIE's bias), its parameters and variables located on the
 * CFA (DW_OP_fbreg); none if its frame base is another *)
val dwarf : Dwarf_info.die list -> int -> int64 -> var list
