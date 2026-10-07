(* dc, the desk calculator: dc.c's machine, a stack of numbers and
 * strings, 256 registers each a stack, strings run as macros.
 *
 * A number is an integer of any size and a scale, how many of its
 * decimal digits are after the point; a string is its bytes. The C has
 * one type for both, a block of bytes (a number's are its digits in
 * base 100 then its scale), and what it does of one taken for the
 * other is kept: a string none of whose bytes is over 99 prints as a
 * number, a number run is its bytes run as commands. *)

type caps = < Cap.stdin; Cap.stdout; Cap.open_in; Cap.fork; Cap.exec; Cap.wait >

(* dc's exit: the q command at the top, or its input's end *)
exception Quit

(* the commands of a text run, to its end (bc's use: what it compiles
 * of a statement); the stack, the registers and the bases stay *)
val feed : < caps; .. > -> string -> unit

(* the commands of a file if one is given, then of the standard input,
 * to its end or a q: dc itself *)
val run : < caps; .. > -> string option -> unit
