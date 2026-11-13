(* tiny-ml's lexer: turns the text of a file into tokens, each with
 * its line number. *)

(* Raises Common.Error, for an error in the program being compiled (a
 * bug in tiny-ml raises Failure); TinyML.ml prints the file and the
 * line. *)
val error : string -> 'a

type token =
  | INT of int
  | CHAR of int
  | STR of string
  | LID of string                     (* a name: x, a field *)
  | UID of string                     (* a constructor, a module (M.x is
                                       * a LID) *)
  | KW of string                      (* a keyword or a punctuation *)
  | EOF

(* Attributes ([@...]) and comments are dropped. *)
val lex : string -> (token * int) array
