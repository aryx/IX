(* The one parser for both machines: it turns Plan 9's assembly syntax
 * into Asm's items. The syntax is the same for arm and arm64; only the
 * register names differ (see register, here). So this parser never asks
 * which machine it reads for, except to name a register.
 *
 * Labels and n(PC) become Target, an index into the items. The pc that
 * 5a and 7a count (every item but GLOBL and DATA has one) is turned into
 * the item it names in a second pass, once all the labels are known.
 *
 *     parse Arm "x.s" "loop: SUB $1, R0\n BNE loop\n"
 *       = items [ Ins SUB [$1; R0]; Ins BNE [Target 0] ]
 *
 * There are two passes because a forward branch names a label not seen
 * yet, and because what a pc is worth as an index is not known before
 * the GLOBLs and DATAs in between are. The first pass writes Target
 * with the pc, or with a negative number that stands for "this label,
 * plus that much". The second pass replaces each by the index of the
 * item:
 *
 *                   pc  item        first pass       second pass
 *     TEXT f(SB),$0  0   0
 *     CMP  $0, R0    1   1
 *     BEQ  done      2   2          Target -1        Target 5
 *     GLOBL x(SB),$4 -   3                           (no pc)
 *     B    -2(PC)    3   4          Target 1         Target 1
 *   done:
 *     RET            4   5          done = pc 4
 *
 * A Target is an index and not an address because nothing here knows
 * how many bytes an instruction will take (a MOVW of a large constant
 * is one word or two, and a word of a literal pool). So a branch names
 * an instruction, and the linker, which lays the code out, turns it
 * into a distance (Link.resolve, then Arm.layout).
 *
 * A line is read by hand, by recursive descent. A name before a colon
 * is a label, and a name before an = is a constant. TEXT, GLOBL and DATA
 * have their own shapes. Anything else is an opcode with its dot
 * suffixes and operands, whatever its name, and the linker says whether
 * it exists. (5a's grammar is a yacc one, a.y, with a rule for each
 * shape of instruction. With the machine taken out of the parser, what
 * is left of the grammar is the shape of a line and a dozen operand
 * forms.)
 *
 * The preprocessor is in Lexer_asm, and it is small. It handles #include
 * and the #define of a name, which is what goken's libc and the kernels'
 * l.s use, and any other # line is an error. 5a has C's whole
 * preprocessor built in.
 *
 * References: Rob Pike, "A Manual for the Plan 9 assembler", written
 * for the 68020's 2a, "the prototype" of the others. It writes BRA 2(PC)
 * "to skip one instruction", and a label with no (PC); these are the
 * two spellings of a Target. *)

exception Error of int * string   (* a line number and a message *)

(* [parse caps arch file text] parses [text]; [caps] is for reading the
 * #included files. *)
val parse : < Cap.open_in; .. > -> Asm.arch -> Fpath.t -> string -> Asm.obj
