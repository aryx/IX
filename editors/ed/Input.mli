(* The command stream: where ed's characters come from.
 *
 * Three readers share it:
 * - the command loop, which reads a character at a time;
 * - input mode (a, i, c), which reads a line at a time until a line
 *   that is ".";
 * - while g runs, its command list, a string that is read before the
 *   stream (ed.c's globp), and whose end is an end of file for that
 *   line's run.
 * One character can be pushed back (ed.c's peekc), and the last one
 * read is kept (lastc), for the clean-up after an error.
 *
 * Standard input is read one byte at a time, as plan9port's ed does,
 * so that a child of ! reads what ed has not. Characters are runes:
 * the bytes of a UTF-8 sequence are read together.
 *
 *     let t = of_string "1p\n" in
 *     getc t = Char.code '1';  unget t (Char.code '1');  getc t = Char.code '1'
 *     getc t = Char.code 'p';  getc t = nl;  getc t = eof
 *
 * design:
 * A program that runs another on its own standard input must not
 * read ahead: what it took into a buffer of its own is gone for the
 * child. With
 *
 *     !read x          a command, then the line it is to read,
 *     this line        both in the script given to ed
 *
 * the second line is the child's only if ed stopped at the first
 * newline. What is not yet read (a file's offset, which the kernel
 * keeps for both; a pipe's bytes still in it) is all that the two
 * processes share. So ed reads one byte with each read, a system call
 * for each character, which a person typing never notices but a long
 * script pays for. *)

type t

(* ed's ?, and ?file. It is raised anywhere, and caught by the command
 * loop. *)
exception Error of string

val eof : int
val nl : int

val of_fd : Unix.file_descr -> t
val of_string : string -> t

val getc : t -> int
val unget : t -> int -> unit
val lastc : t -> int
val set_lastc : t -> int -> unit

(* [line t] is input mode's next line (with NULs dropped), or None at
 * the end of the stream. In a g list, the end then stays for the loop
 * to see. *)
val line : t -> string option

(* [digits t] reads a number, and is 0 when there is none (ed.c's
 * getnum) *)
val digits : t -> int

(* g's command list: [list] is read in front of the stream *)
val set_global : t -> string option -> unit
val in_global : t -> bool

(* Are we in a g list with more of it to come? A newline in s's
 * replacement is then part of the replacement. *)
val global_has_more : t -> bool

(* ed.c's error_1 on the input: it drops the g list and throws away
 * the rest of the line, and, if standard input is a file, all of the
 * input *)
val recover : t -> unit
