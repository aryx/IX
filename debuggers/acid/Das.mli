(* The arm instructions read back (principia's debuggers/libmach/5db.c):
 * what acid's i format prints, and where the processor goes after an
 * instruction (machdata's das and foll), for step() and next().
 *
 * The syntax is Plan 9's, 5a's, the mnemonic, a tab, the operands, the
 * source first, the destination last:
 *
 *     MOVW.W   R14,#-0x4(R13)       a store, the base written back
 *     MOVW     $#0x3,R0             a constant ($), in hexadecimal (#)
 *     MOVW     R0,a+0(FP)           a parameter, by its name
 *     MOVW     $buf-SB(SB),R1       a static, from setR12's base
 *     BL       middle(SB)           a branch, to a symbol
 *     MOVM.DB.W [R0-R3,R14],(R13)   registers listed in brackets
 *
 * The condition and the flags are suffixes (.EQ, .S, .P, .W, .IA...).
 * A word is decoded as 5db does, in two steps: its class (armclass, an
 * index in a table of 128 opcodes: data processing, loads and stores,
 * multiple loads and stores, branches, coprocessors, VFP), then the
 * opcode's printer, which takes the fields its templates use (Rn, Rd,
 * the constant) and expands them (%C the condition, %I an address...).
 *
 * Its words, as acid's, Plan 9's fmt with the x verb flipped to print
 * 0x: #0x10, #-0x4(R13). 5db's oddities are kept: a halfword's offset
 * of its two nibbles or'ed, a MOVM's popped PC read at the count of
 * registers, not four times it, the register an LDR's index from a
 * byte, one address followed (the condition evaluated, not both).
 *
 * The numbers are int64s, a word in their low 32 bits: mini-acid runs
 * on arm, where an int has 31. *)

(* the symbols 5db names addresses with (libmach's buildtbls): the
 * functions sorted, each with its parameters and locals, the data's,
 * and the static base, setR12's address (acid's mach->sb, 0 without) *)
type table

(* the tables from a program's symbols, in the table's order *)
val table : Symbols.sym list -> table

(* libmach's symoff: an address as name+0x10, the name, or 0x...
 * (no symbol, or a data's 4096 bytes away); [text_only] the text's
 * symbols (CTEXT), else any (CANY: the data's after the text's last) *)
val symoff : table -> bool -> int64 -> string

(* the instruction at an address (printins): [load a] the word at a,
 * little-endian, None out of the map; None when the instruction can't
 * be read *)
val instruction : table -> (int64 -> int64 option) -> int64 -> string option

(* the address that runs after the instruction at an address (armfoll):
 * [load] reads the process's memory, [reg name] a register by 5db's
 * name (R0..R15, PSR); None when a word can't be read *)
val follow :
  (int64 -> int64 option) -> (string -> int64) -> int64 -> int64 option
