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

val tokens : string -> (token * int) list
