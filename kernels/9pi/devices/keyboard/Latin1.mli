(* The characters made by the Alt key and the keys typed after it, two
 * or three of them, or more for Alt X and a number. These are Plan 9's
 * compose sequences (principia's latin1.c and its table, latin1.h):
 * Alt ' e is é, Alt * a is α, and Alt X 2 0 a c is the character of
 * number 0x20ac.
 *
 * Kbd calls it at each key, with the keys typed since Alt. A character
 * ends the sequence, -1 gives the keys up as they are, and anything
 * below -1 asks for the next key.
 *
 * cs-history:
 * The table can name any character because Plan 9's text is Unicode
 * throughout, as UTF-8. Ken Thompson and Rob Pike designed that encoding
 * for Plan 9 in September 1992. In it ASCII is unchanged, and every
 * other character is two bytes or more that are never ASCII bytes, so
 * every program that handled bytes went on working. A rune is Plan 9's
 * word for a character's number.
 *
 * References: Rob Pike and Ken Thompson, "Hello World, or ..."
 * (USENIX Winter 1993), UTF-8's paper. keyboard(6) in the Plan 9
 * manual lists the sequences. *)

(* the character made by the keys typed after Alt (given by their
 * numbers); -1 when they make none, and below -1 when more keys are
 * needed *)
val latin1 : int list -> int
