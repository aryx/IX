(* The tokens of Plan 9's assembly. A name includes its dots, so MOVW.P
 * and .string are each one token. There are numbers (in hexadecimal
 * with 0x, in octal, characters like 'c', and floats), strings with C's
 * escapes, the punctuation, and Eol, which stands for a newline or a
 * semicolon. Comments are // and /* */. *)

type token =
  | Ident of string
  | Int of int64
  | Float of float
  | String of string
  | Punct of string
  | Eol

exception Error of int * string

(* [preprocess dir text] handles #include "file" (found in dir) and
 * #define NAME text, which are the only directives the inputs use. *)
val preprocess : < Cap.open_in; .. > -> Fpath.t -> string -> string

(* A text being read, a line at a time. *)
type lexer

val lexer : string -> lexer

(* The tokens of the next line, each with its line, the Eol that ends it
 * the last: a line is a newline's, so one with semicolons has several
 * Eol, and one that opens a comment goes on to the line that closes it.
 * After the last line, the text's end, which is an Eol too; then []. *)
val line_tokens : lexer -> (token * int) list
