(* A few of the arm64 instructions, read back (principia's libmach
 * 7db.c has them all), for a program on this machine's Linux
 * (plan_debugger.md, stage 8a). It says where the processor goes after
 * an instruction (machdata's foll), for step() and next(), and what
 * acid's i format prints.
 *
 * follow knows every instruction that changes the pc in another way
 * than adding 4: B and BL (26 bits, an offset in words), B.cond (19
 * bits), CBZ and CBNZ (19), TBZ and TBNZ (14), and BR, BLR and RET
 * (which go to a register). A condition is evaluated from the flags
 * (NZCV, the top bits of the PSR) or from the register, so only one
 * address is followed, as in 5db's foll. The printer knows these
 * instructions, and also NOP, BRK, SVC, LDR of a literal, ADD and SUB
 * of a constant, MOV, MOVZ, STP and LDP, and LDR and STR with an
 * offset, in Plan 9's order (the source first). The other instructions
 * are printed as their word (WORD $0x...).
 *
 * Every instruction is a word of 32 bits, little-endian, at an address
 * that is a multiple of 4. Decoding is thus only masks and fields, with
 * no prefix and no length to find (this is true of arm too, while
 * x86's instructions are 1 to 15 bytes long). *)

(* the address after the instruction at pc (get reads a word, and reg
 * reads a register by its name: R0..R30, PSR) *)
val follow : (int64 -> int64 option) -> (string -> int64) -> int64 -> int64 option

(* the instruction at pc, as text (symoff names an address) *)
val instruction : (int64 -> string) -> (int64 -> int64 option) -> int64 -> string
