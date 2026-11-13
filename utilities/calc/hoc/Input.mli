(* What hoc reads, a character at a time: the files of the command line
 * one after the other, where - is the standard input, and -e's text.
 * The lexer and read(x) share one input, so read(x) takes the numbers
 * that follow its line. This is the C's Biobuf bin and its
 * moreinput. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stderr >

(* takes the program's name, for the messages, and its arguments (with
 * none, the input is the standard input) *)
val start : < caps; .. > -> string -> string list -> unit

(* moves to the next input, and returns false when there is none; an
 * input that cannot be opened is reported and skipped *)
val more : < caps; .. > -> bool

(* the current input's name (None for the standard input) and line *)
val file : string option ref
val lineno : int ref

(* the next character, or -1 at the end; [ungetc] gives that one back *)
val getc : unit -> int
val ungetc : unit -> unit

(* the last character the lexer was given: after an error, the line is
 * dropped from it to its end *)
val last : int ref

(* reads a number from next, a character at a time ([+-] digits [.]
 * digits [e [+-] digits], each part optional), and returns it with the
 * character that ended it. It is libc's charstod, with its arithmetic
 * (1e and . are numbers). *)
val number : (unit -> int) -> float * int

(* after an error, drops the rest of the line and what was read ahead
 * with it (the rest of a file; for a terminal, nothing more) *)
val recover : unit -> unit
