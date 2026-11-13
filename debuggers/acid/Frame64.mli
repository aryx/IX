(* arm64's frames, to find a frame's parameters and locals
 * (plan_debugger.md, stage 8a). The builtin strace and f:v use them,
 * as they use Proc.walk on arm. port.acid's stk walks the frames in
 * acid (arm64.acid finds the frames by each function's prologue). Here
 * the same walk gives each frame's base, its CFA (DWARF's Canonical
 * Frame Address, which is the caller's SP at the call); both tables
 * count a variable's place from it:
 *
 *              | caller's frame |
 *     CFA ->   +----------------+  a parameter of 7c's at CFA+8+off
 *              | this frame     |  (Plan 9's p, the FP pseudo-register
 *              |                |  8 above), a local at CFA-off (a);
 *     SP  ->   +----------------+  gcc's at CFA+off (DW_OP_fbreg, its
 *                                  frame base DW_OP_call_frame_cfa)
 *
 * The CFA is found from the prologue, the function's first
 * instructions, read in the program's file:
 *
 *     STP.W (R29, R30), -n(RSP); MOV RSP, R29        gcc's: CFA = R29+n
 *     SUB $N, RSP; STP (R29, R30), m(RSP); ADD $m, RSP, R29
 *                                                    CFA = R29-m+N
 *     MOVD.W R30, -n(RSP)                            7c's: CFA = SP+n
 *     SUB $n, RSP; MOVD R30, 0(RSP)                  mini-ml's: SP+n
 *     SUB $n, RSP                                    gcc's leaf: SP+n
 *     (nothing)                                      a leaf: SP
 *
 * gcc's .eh_frame says exactly the same, for every instruction
 * (plan9port's dwarfcfa.c reads it); the prologue is what the acid
 * walk reads too. A frame of gcc -O2 is not read, because its prologue
 * is none of these (such a frame then ends the walk). *)

type frame = {
  start : int64;            (* the start of its function *)
  pc : int64;
  cfa : int64;
  ret : int64;              (* where it returns to *)
}

(* the frames found from the registers (pc, sp, the link R30, the frame
 * pointer R29), the innermost first, up to the function that isstart
 * says ends the stack. read8 reads an 8-byte word of the process,
 * read4 an instruction of the file, and start gives the function
 * around an address. *)
val walk :
  (int64 -> int64 option) -> (int64 -> int64 option) -> (int64 -> int64 option) -> (int64 -> bool) ->
  int64 -> int64 -> int64 -> int64 -> frame list

(* a variable of a frame: a parameter or a local, its address and its
 * size in bytes *)
type var = { vname : string; param : bool; addr : int64; size : int }

(* a function's variables, from Plan 9's table: the entries (p, a)
 * after its symbol *)
val plan9 : Symbols.sym list -> int64 -> var list

(* a function's variables, from DWARF: those of the subprogram at start
 * (the file's address, before a PIE's bias), with its parameters and
 * variables located relative to the CFA (DW_OP_fbreg). There are none
 * if its frame base is something else. *)
val dwarf : Dwarf_info.die list -> int -> int64 -> var list
