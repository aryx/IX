(* The arm instructions, read back (principia's
 * debuggers/libmach/5db.c). This module gives what acid's i format
 * prints, and where the processor goes after an instruction
 * (machdata's das and foll), for step() and next().
 *
 * The syntax is Plan 9's, that of 5a: the mnemonic, a tab, then the
 * operands, with the source first and the destination last:
 *
 *     MOVW.W   R14,#-0x4(R13)       a store, the base written back
 *     MOVW     $#0x3,R0             a constant ($), in hexadecimal (#)
 *     MOVW     R0,a+0(FP)           a parameter, by its name
 *     MOVW     $buf-SB(SB),R1       a static, from setR12's base
 *     BL       middle(SB)           a branch, to a symbol
 *     MOVM.DB.W [R0-R3,R14],(R13)   registers listed in brackets
 *
 * The condition and the flags are suffixes (.EQ, .S, .P, .W, .IA...).
 * A word is decoded as 5db does, in two steps. First its class is found
 * (armclass gives an index in a table of 128 opcodes: data processing,
 * loads and stores, multiple loads and stores, branches, coprocessors,
 * VFP). Then the opcode's printer takes the fields that its templates
 * use (Rn, Rd, the constant) and expands them (%C is the condition, %I
 * an address...).
 *
 * The numbers are printed as acid prints them, with Plan 9's fmt and
 * the x verb changed to print 0x: #0x10, #-0x4(R13). 5db's oddities
 * are kept:
 *   - a halfword's offset is its two nibbles or'ed together;
 *   - the PC popped by a MOVM is read at an offset of the count of
 *     registers, not four times that count;
 *   - the index register of an LDR is read as a byte;
 *   - only one address is followed (the condition is evaluated, rather
 *     than following both ways).
 *
 * The numbers are int64s, with a word in their low 32 bits, because
 * mini-acid runs on arm, where an int has 31 bits. *)

(* the symbols that 5db names addresses with (libmach's buildtbls): the
 * functions, sorted, each with its parameters and locals; the data
 * symbols; and the static base, which is setR12's address (acid's
 * mach->sb, or 0 when there is no setR12) *)
type table

(* the tables built from a program's symbols, in the table's order *)
val table : Symbols.sym list -> table

(* libmach's symoff: an address as name+0x10, as the name alone, or as
 * 0x... (when there is no symbol, or the symbol found is a data symbol
 * 4096 bytes away or more). With [text_only], only the text's symbols are
 * used (CTEXT); otherwise any symbol is (CANY: the data's symbols after
 * the text's last one). *)
val symoff : table -> bool -> int64 -> string

(* the instruction at an address (printins). [load a] gives the word
 * at a, little-endian, or None outside the map. It returns None when
 * the instruction can't be read. *)
val instruction : table -> (int64 -> int64 option) -> int64 -> string option

(* the address that runs after the instruction at an address
 * (armfoll). [load] reads the process's memory, and [reg name] reads a
 * register by 5db's name (R0..R15, PSR). It returns None when a word
 * can't be read. *)
val follow :
  (int64 -> int64 option) -> (string -> int64) -> int64 -> int64 option
