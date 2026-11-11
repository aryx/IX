(* tiny-ml's lexer: a file's text, its tokens, each with its line. *)

(* an error in the program compiled, its message, Common.Error (a bug a
 * Failure); TinyML.ml says the file and the line *)
val error : string -> 'a

type token =
  | INT of int
  | CHAR of int
  | STR of string
  | LID of string                     (* a name: x, a field *)
  | UID of string                     (* a constructor, a module: M.x is
                                       * one LID *)
  | KW of string                      (* a keyword, a punctuation *)
  | EOF

(* [@...] attributes and comments dropped *)
val lex : string -> (token * int) array
