val error : string -> 'a
type token =
    INT of int
  | CHAR of int
  | STR of string
  | LID of string
  | UID of string
  | KW of string
  | EOF

val lex : string -> (token * int) array
