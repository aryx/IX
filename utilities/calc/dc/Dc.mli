(* dc, the desk calculator: dc.c's machine, a stack of numbers and
 * strings, 256 registers each a stack, strings run as macros.
 *
 * A number is an integer of any size and a scale, how many of its
 * decimal digits are after the point; a string is its bytes. The C has
 * one type for both, a block of bytes (a number's are its digits in
 * base 100 then its scale), and what it does of one taken for the
 * other is kept: a string none of whose bytes is over 99 prints as a
 * number, a number run is its bytes run as commands.
 *
 * A loop is a macro that runs itself. dc has no while: a string is
 * put in a register, and a comparison runs a register's string when
 * it holds. Counting from 1 to 5:
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
 * themselves stacks (Sx pushes, Lx pops: a function's local
 * variables), that is enough for bc's functions, its recursion and
 * its loops. dc is a small stack machine with a text for machine
 * code, and bc's compiler writes that text.
 *
 * others:
 * Forth (Charles Moore, about 1970) and PostScript (Adobe, 1984) are
 * the two other languages of that family one still meets: a stack,
 * the operator last, and code that is data ([...] here, { ... } in
 * PostScript). languages/forth has the first, lib_graphics/pdf
 * reads the descendant of the second.
 *
 * References: dc(1), the commands; principia's dc.c. *)

type caps = < Cap.stdin; Cap.stdout; Cap.open_in; Cap.fork; Cap.exec; Cap.wait >

(* dc's exit: the q command at the top, or its input's end *)
exception Quit

(* the commands of a text run, to its end (bc's use: what it compiles
 * of a statement); the stack, the registers and the bases stay *)
val feed : < caps; .. > -> string -> unit

(* the commands of a file if one is given, then of the standard input,
 * to its end or a q: dc itself *)
val run : < caps; .. > -> string option -> unit
