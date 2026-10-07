(* What hoc reads, a character at a time: the files of the command line
 * one after the other, - for the standard input, -e's text. One input
 * for the lexer and for read(x), which takes the numbers that follow
 * its line; the C's Biobuf bin and moreinput. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stderr >

(* the program's name, for the messages, and its arguments (none: the
 * standard input) *)
val start : < caps; .. > -> string -> string list -> unit

(* the next input, false when there is none; one that cannot be opened
 * is said and passed *)
val more : < caps; .. > -> bool

(* the current input's name (None: the standard input) and line *)
val file : string option ref
val lineno : int ref

(* the next character, -1 at the end; and that one given back *)
val getc : unit -> int
val ungetc : unit -> unit

(* the last character the lexer was given: an error drops the line up
 * to it *)
val last : int ref

(* a number read by next, a character at a time ([+-] digits [.] digits
 * [e [+-] digits], each part optional), and the character that ended
 * it; libc's charstod, with its arithmetic (1e and . are numbers) *)
val number : (unit -> int) -> float * int

(* after an error: the rest of the line is dropped, and what was read
 * ahead with it (the rest of a file; of a terminal, nothing more) *)
val recover : unit -> unit
