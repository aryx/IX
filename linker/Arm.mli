(* The arm machine (5l): the rewriting of frames, returns and
 * divisions, the layout of the code with its literal pools, and the
 * encoding of each instruction by the form its opcode and its
 * operands' classes select, in the order of 5l's rules.
 *
 * {b A word.} Every ARM instruction is 32 bits, and the common ones,
 * the data-processing ones, are laid out so:
 *
 *     31  28 27 26 25 24  21 20 19  16 15  12 11                0
 *     | cond | 0  0 | I| opcode| S|  Rn  |  Rd  |    operand 2    |
 *
 *     ADD R3<<2, R2, R3          R3 = R2 + (R3 << 2)
 *     1110   0  0   0   0100   0   0010   0011   00010 00 0 0011
 *     always        reg  ADD       R2     R3     by 2  << .  R3
 *     = 0xe0823103
 *
 * Plan 9 writes the destination last and the first source in the
 * middle; ARM's own syntax is add r3, r2, r3, lsl #2 (what mini-5i
 * -t prints for that word: Arm32.mli has the fields' meanings). An
 * instruction's dot suffixes are bits of the same word: a condition
 * (MOVW.EQ) is the top four, .S is bit 20, .P and .W the post- and
 * pre-indexing of a load or store.
 *
 * {b Classes.} MOVW is not an instruction of the machine: it is one
 * name for a dozen, and which one depends on what its operands are.
 * Each operand is given a class by what it is and how large
 * ([aclass]), and the pair of classes selects the form ([select]):
 *
 *     MOVW R1, R2            REG, REG     a mov
 *     MOVW $255, R2          RCON, REG    a mov of an immediate
 *     MOVW $0x12345, R2      LCON, REG    a load from the literal pool
 *     MOVW 8(R1), R2         SOREG, REG   a load, 12 bits of offset
 *     MOVW 8192(R1), R2      LOREG, REG   the offset from the pool
 *                                         into R11, then a load
 *     MOVW x(SB), R2         SEXT or LEXT: by how far x is from R12
 *     MOVW R2, n-4(SP)       REG, SAUTO   a store in the frame
 *
 * A class may stand for a smaller one (an LCON form takes an RCON:
 * [cmp]), and the forms are tried smallest first, so each
 * instruction gets the shortest encoding that holds its operands.
 * R11 is the linker's: a program may not keep a value in it.
 *
 * {b Literal pools.} An instruction is 32 bits and so is an address:
 * a constant that does not fit the 12 bits of operand 2 cannot be in
 * the instruction. It is put in a word nearby, among the code, and
 * loaded by its distance from the pc:
 *
 *         MOVW $0x12345, R2    ->    MOVW n(R15), R2    n: from here
 *         ...                        ...                to the word
 *                                    WORD $0x12345      <- the pool
 *
 * [layout] collects the constants as it goes (the same one once) and
 * puts the pool out in one of three places: after an unconditional B
 * or a return, where the flow cannot fall into it, once the pool's
 * first load is 2 KB behind; behind a branch around it, when the
 * next instruction would put that load beyond the 4 KB an offset
 * reaches; and at the end of the program.
 *
 * {b Frames} ([rewrite]). A function is written with the size of
 * its locals and a RET; the linker writes what they mean:
 *
 *     TEXT f(SB), $8      ->     MOVW.W R14, -12(R13)     push the
 *       ...                        ...                    return address
 *       RET                        MOVW.P 12(R13), R15    pop it into pc
 *
 * 12 is the 8 and the 4 bytes of the return address, kept at the
 * frame's bottom; one instruction makes the frame and saves R14,
 * another returns and frees it. A function that calls nothing and
 * has no locals (a leaf) gets neither: its RET is a B to (R14). And
 * DIV and MOD become calls to _div and _mod, the ARM of the Pi 1
 * having no divide instruction.
 *
 * What is ours: 5l chooses a form by a table of rules (an opcode,
 * three classes, a case number), sorted, and encodes in a switch on
 * the case numbers, far from the table. Here one match on the
 * opcode tries the forms in the table's order with each form's
 * words beside it; the output is the same, and written so, four of
 * 5l's cases showed as never reached (Arm.ml says which). [rotate]
 * is the other difference: goken's 5l, run on a 64-bit host, only
 * finds the immediates 0 to 255 and puts 0x400 in the pool, and
 * mini-ld does the same unless told.
 *
 * design:
 * The barrel shifter in the encoding. Operand 2 is 12 bits for a
 * 32-bit constant: ARM does not take the low 12, it takes 8 bits
 * and rotates them right by twice the other 4, since its data path
 * has a shifter in front of the adder anyway. So 0xff, 0xff00,
 * 0xf000000f and 0x3fc are immediates, and 0x101 or 0x12345 are not
 * ([immrot]). The constants programs use, small numbers, masks and
 * powers of two, mostly fit; a compiler for ARM never assumes one
 * does, and here it does not have to know: the linker chooses.
 *
 * road-not-taken:
 * T. G. Szymanski, "Assembling Code for Machines with
 * Span-dependent Instructions" (CACM, 1978): when
 * an instruction's size depends on the distance it spans, sizes and
 * addresses depend on each other, and the layout is redone until no
 * branch grows. Thompson's "Plan 9 C Compilers" cites it for the
 * 68020's loader, and says of the MIPS that "all instructions are one
 * size. A single pass over the instructions will determine the
 * locations" -- arm's case too, so [layout] is one pass, a literal
 * pool being put out before its first load would be out of reach.
 *
 * cs-history:
 * David Wheeler, "The use of sub-routines in programmes" (ACM National
 * Meeting, 1952), EDSAC's call: the return address arrives in a
 * register, as BL leaves it in R14, which a leaf keeps there; but the
 * subroutine planted it in its own last order, so it could not call
 * itself. Edsger Dijkstra, "Recursive programming" (Numerische
 * Mathematik, 1960), the stack instead of fixed cells: where
 * [rewrite]'s prologue pushes R14, below the frame, for a non-leaf.
 *
 * References: the three papers above, each for the idea named; ARM
 * Architecture Reference Manual (ARM DDI 0100; from memory), part A,
 * for the encodings; principia's linkers/5l (optab in optab.c,
 * asmout, dotext, noops) and its book; 5.out.h for the opcodes. *)

(* the machine's opcodes (5.out.h) *)
type op

(* an opcode from its name, and back *)
val decode : string -> op option
val show : op -> string

(* immediates as a real ARM rotation, not goken's 64-bit one *)
val rotate : bool ref

(* the names the program needs besides its own (_div... for DIV) *)
val needs : op Program.prog list -> string list

(* B.NE as BNE; float constants into the data (5a's outcode, 5l's
 * ldobj) *)
val prepare : op Program.t -> unit

(* what ends the flow, for 5l's follow (Follow) *)
val ends : op Program.prog -> bool

(* prologues, RET, DIV and MOD, negative ADD and SUB (5l's noops, and
 * ldobj's part; xix's Rewrite5) *)
val rewrite : op Program.t -> unit

(* each instruction's pc, the literal pools, t.text_size, t.data_start
 * (5l's dotext; xix's Layout5) *)
val layout : op Program.t -> unit

(* the text's bytes (5l's asmout; xix's Codegen5) *)
val encode : op Program.t -> Bytes.t
