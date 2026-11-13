(* dc, the desk calculator: dc.c's machine. It has a stack of numbers
 * and strings, 256 registers that are each a stack, and strings that
 * are run as macros.
 *
 * A number is an integer of any size and a scale, which is how many of
 * its decimal digits are after the point; a string is its bytes. The C
 * has one type for both, a block of bytes (for a number, its digits in
 * base 100, then its scale), and what the C does when it takes one for
 * the other is kept here: a string none of whose bytes is over 99
 * prints as a number, and a number that is run has its bytes run as
 * commands.
 *
 * A loop is a macro that runs itself. dc has no while: a string is
 * put in a register, and a comparison runs a register's string when
 * the comparison holds. Here is how to count from 1 to 5:
 *
 *     [la 1 + d sa p 5 >x] sx     the string, saved in register x
 *     0 sa                        a = 0
 *     lx x                        load x and run it:
 *
 *         la 1 +     a + 1
 *         d sa p     keep it in a, print it
 *         5 >x       5 > a? then run x again: the loop
 *
 * reframe:
 * A program is a string, and a string is a value on the stack: it
 * can be built, saved, duplicated and run. With registers that are
 * themselves stacks (Sx pushes and Lx pops, which gives a function its
 * local variables), that is enough for bc's functions, its recursion
 * and its loops. dc is a small stack machine whose machine code is
 * text, and bc's compiler writes that text.
 *
 * others:
 * Forth (Charles Moore, about 1970) and PostScript (Adobe, 1984) are
 * the two other languages of that family one still meets. They have a
 * stack, the operator last, and code that is data ([...] here,
 * { ... } in PostScript). languages/forth has the first, and
 * lib_graphics/pdf reads the descendant of the second.
 *
 * References: dc(1), the commands; principia's dc.c. *)

type caps = < Cap.stdin; Cap.stdout; Cap.open_in; Cap.fork; Cap.exec; Cap.wait >

(* dc's exit: the q command at the top level, or the end of its input *)
exception Quit

(* runs the commands of a text, to its end (bc uses it for what it
 * compiles of a statement); the stack, the registers and the bases
 * stay as they are *)
val feed : < caps; .. > -> string -> unit

(* runs the commands of a file if one is given, then those of the
 * standard input, to its end or a q: this is dc itself *)
val run : < caps; .. > -> string option -> unit
