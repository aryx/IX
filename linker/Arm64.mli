(* The arm64 machine (7l). It rewrites frames and returns, lays the code
 * out with its literal pool, and encodes each instruction by the form
 * that its opcode and its operands' classes select, in the order of
 * 7l's rules.
 *
 * The passes are the same as Arm's, and Arm.mli explains them (the
 * classes, the pool, the frames). What is said here is what arm64
 * changes.
 *
 * {b Constants.} A word is still 32 bits but a register is now 64, so
 * less of a constant fits. Where arm has one immediate form, arm64 has
 * three, each for its own instructions, and a constant's class says
 * which ones it could be ([aclass]):
 *
 *     ADD $4096, R1            ADDCON: 12 bits, or 12 bits shifted
 *                              left by 12
 *     AND $0xff00ff00ff00ff00, R1
 *                              BITCON: a logical immediate (below)
 *     MOV $0x12340000, R1      MOVCON: all its bits are in one 16-bit
 *                              lane of the four, so a MOVZ (or a MOVN
 *                              of its complement)
 *     MOV $0x123456789, R1     LCON, none of them: a load from the
 *                              literal pool
 *
 * A logical immediate is a pattern, not a number: a run of ones (8 of
 * them here), rotated, in an element of 2, 4, 8, 16 (here), 32 or 64
 * bits, repeated to fill the register. 13 bits give the element's size,
 * the run's length and the rotation, and there are 5,334 such values
 * of 64 bits; the masks that a program ANDs with are nearly all among
 * them. Finding the three numbers from a value is the hard direction,
 * so the table is built the easy way: each pattern is generated and
 * kept by its value ([bitmasks], 7l's bits.c).
 *
 * {b The pool} is a single one, and it can be far away: a load reaches
 * a megabyte from the pc, where arm's reaches 4 KB. So the pool is put
 * out when its first load is nearly that far behind, and otherwise
 * once, at the end of the program.
 *
 * {b Frames.} The stack pointer must stay a multiple of 16, so a frame
 * is rounded up to it, with the return address (R30, 8 bytes) at its
 * bottom. For a function that calls another:
 *
 *     TEXT f(SB), $24     ->     MOV.W R30, -32(RSP)     24 + 8 = 32
 *       ...                        ...
 *       RETURN                     MOV.P 32(RSP), R30
 *                                  RET (R30)
 *
 * It takes two instructions to return, where arm takes one, because
 * arm64's pc is not a register and nothing can be popped into it. A
 * frame larger than 240 bytes, the most that a pre-indexed store moves,
 * takes a SUB first. And there is no _div to call, because arm64
 * divides.
 *
 * others:
 * arm64 took away what made arm's encoder interesting, and gave other
 * things. There is no condition on every instruction (instead, a few
 * conditional ones like CSEL), and no pc among the registers. There are
 * 31 registers of 64 bits, and a register 31 that is either zero or
 * the stack pointer, depending on the instruction. Here R28 is the
 * static base, where arm has R12, and R17 is the linker's own.
 *
 * References: as in Arm.mli, for the one-pass layout (Szymanski's
 * problem does not arise, since every instruction is 4 bytes) and for
 * the frames; the Arm Architecture Reference Manual for A-profile,
 * whose DecodeBitMasks pseudocode defines the logical immediates (a run
 * of ones, rotated, in an element of 2 to 64 bits, repeated), the 5,334
 * values that the encoder tabulates, as 7l's bits.c does. *)

(* the machine's opcodes (7.out.h) *)
type op

(* an opcode from its name, and back *)
val decode : string -> op option
val show : op -> string

(* Rounds the frames, rewrites negative ADD and SUB, and puts float
 * constants into the data (7l's ldobj). *)
val prepare : op Program.t -> unit

(* what ends the flow, for 7l's follow (Follow) *)
val ends : op Program.prog -> bool

(* Rewrites the prologues and RETURN (7l's noops; xix's Rewrite7). *)
val rewrite : op Program.t -> unit

(* Sets each instruction's pc, the literal pool, t.text_size and
 * t.data_start (7l's span; xix's Layout7). *)
val layout : op Program.t -> unit

(* the text's bytes (7l's asmout; xix's Codegen7) *)
val encode : op Program.t -> Bytes.t
