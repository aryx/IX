(* The one parser, for both machines: Plan 9's assembly syntax to
 * Asm's items. The syntax is the same for arm and arm64; what differs
 * is the register names (register, here), so this parser never asks
 * which machine it reads for, but to name a register.
 *
 * Labels and n(PC) become Target, an index into the items: the pc that
 * 5a and 7a count (every item but GLOBL and DATA) is turned into the
 * item it names, in a second pass, once all the labels are known.
 *
 *     parse Arm "x.s" "loop: SUB $1, R0\n BNE loop\n"
 *       = items [ Ins SUB [$1; R0]; Ins BNE [Target 0] ]
 *
 * Why two passes: a branch forward names a label not seen yet, and
 * what a pc is worth as an index is not known before the GLOBLs and
 * DATAs between are. The first pass writes Target with the pc, or
 * with a negative number that stands for "this label, plus that
 * much"; the second replaces each by the index of the item:
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
 * An index and not an address: nothing here knows how many bytes an
 * instruction will take (MOVW of a large constant is one word or
 * two, and a word of a literal pool), so a branch names an
 * instruction, and the linker, which lays the code out, turns it
 * into a distance (Link.resolve, then Arm.layout).
 *
 * A line is read by hand, by recursive descent: a name before a colon
 * is a label, a name before an = a constant, TEXT, GLOBL and DATA
 * have their shapes, and anything else is an opcode with its dot
 * suffixes and operands, whatever its name: the linker says if it
 * exists. (5a's grammar is yacc's, a.y, with a rule for each shape of
 * instruction; with the machine out of the parser the grammar left
 * is a line's, and a dozen operand forms.)
 *
 * The preprocessor is Lexer_asm's, and small: #include and #define
 * of a name, which is what goken's libc and the kernels' l.s use; any
 * other # line is an error. 5a has C's whole preprocessor built in.
 *
 * References: Rob Pike, "A Manual for the Plan 9 assembler", written
 * for the 68020's 2a, "the prototype" of the others: BRA 2(PC) "to
 * skip one instruction", and a label written with no (PC) -- the two
 * spellings of a Target. *)

exception Error of int * string   (* a line, a message *)

(* [parse caps arch file text]; caps to read the #included files *)
val parse : < Cap.open_in; .. > -> Asm.arch -> Fpath.t -> string -> Asm.obj
