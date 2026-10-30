(* The arm64 instructions read back, a few (principia's libmach 7db.c
 * has them all): where the processor goes after one (machdata's foll),
 * for step() and next(), and what acid's i format prints, for a
 * program on this machine's Linux (plan_debugger.md, stage 8a).
 *
 * follow knows every instruction that changes the pc otherwise than by
 * 4: B and BL (26 bits, a word's offset), B.cond (19), CBZ and CBNZ
 * (19), TBZ and TBNZ (14), BR, BLR and RET (a register); a condition
 * evaluated by the flags (NZCV, the PSR's top bits) or the register,
 * one address, as 5db's foll. The printer knows these, NOP, BRK, ADD
 * and SUB of a constant, MOV, MOVZ, STP and LDP, LDR and STR of an
 * offset, in Plan 9's order (the source first); the others are their
 * word (WORD $0x...).
 *
 * Every instruction is a word of 32 bits, little-endian, at an address
 * a multiple of 4: decoding is masks and fields, no prefix nor length
 * (arm's too; x86's are 1 to 15 bytes). *)

(* the address after the instruction at pc (get reads a word, reg a
 * register by its name: R0..R30, PSR) *)
val follow : (int64 -> int64 option) -> (string -> int64) -> int64 -> int64 option

(* the instruction at pc, text (symoff names an address) *)
val instruction : (int64 -> string) -> (int64 -> int64 option) -> int64 -> string
