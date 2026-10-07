{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The lexer: bc.y's yylex, in ocamllex. A name is one small letter; a
 * word of several is a keyword, known by its two first letters (print,
 * pr, prxyz are the same), and quit ends bc where it is read. A digit
 * is a token of its own (A to F too): the grammar makes the numbers. *)
open Parser

let keyword w =
  match String.sub w 0 2 with
  | "pr" -> PRINT | "if" -> IF | "wh" -> WHILE | "fo" -> FOR | "sq" -> SQRT | "re" -> RETURN
  | "br" -> BREAK | "de" -> DEFINE | "sc" -> SCALE | "ba" | "ib" -> BASE | "ob" -> OBASE
  | "di" -> FFF | "au" -> AUTO | "le" -> LENGTH
  | "qu" -> raise State.Quit
  | _ -> ERROR
}

rule token = parse
  | [' ' '\t']+ { token lexbuf }
  | '\\' _ { token lexbuf }
  | "/*" { comment lexbuf }
  | ['a'-'z'] ['a'-'z']+ as w { keyword w }
  | ['a'-'z'] as c { LETTER (String.make 1 c) }
  | ['0'-'9' 'A'-'F'] as c { DIGIT c }
  | '"' ([^ '"']* as s) '"' { QSTR s }
  | '.' { DOT }
  | "*=" { EQOP "*" } | "%=" { EQOP "%" } | "^=" { EQOP "^" } | "+=" { EQOP "+" } | "-=" { EQOP "-" } | "/=" { EQOP "/" }
  | "++" { INCR } | "--" { DECR }
  | "==" { EQ } | "<=" { LE } | ">=" { GE } | "!=" { NE }
  | '*' { STAR } | '%' { PERCENT } | '^' { CARET } | '+' { PLUS } | '-' { MINUS } | '/' { SLASH }
  | '=' { ASSIGN } | '<' { LT } | '>' { GT }
  | '(' { LPAREN } | ')' { RPAREN } | '{' { LBRACE } | '}' { RBRACE } | '[' { LBRACKET } | ']' { RBRACKET }
  | ',' { COMMA } | ';' { SEMI } | '\n' { NEWLINE } | '~' { TILDE } | '?' { QUESTION } | '_' { UNDERSCORE }
  | eof { EOF }
  | _ { ERROR }

and comment = parse
  | "*/" { token lexbuf }
  | eof { EOF }
  | _ { comment lexbuf }
