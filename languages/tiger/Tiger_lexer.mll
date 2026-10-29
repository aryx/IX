{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Tiger's tokens (Appel's appendix: the Tiger Language Reference
 * Manual), with fork-tiger's four words for exceptions. Comments /* */
 * nest; a string has Appel's escapes: a newline, a tab, a quote and a
 * backslash by a backslash and n, t, the quote, a backslash; a
 * backslash and three digits (a character by its code), a backslash, ^
 * and a letter (a control character); and a backslash, blanks, another
 * backslash, which are nothing (a string continued on the next line). *)
open Tiger_parser

exception Error of string * Lexing.position

let keywords = [
  "array", ARRAY; "break", BREAK; "do", DO; "else", ELSE; "end", END;
  "for", FOR; "function", FUNCTION; "if", IF; "in", IN; "let", LET;
  "nil", NIL; "of", OF; "then", THEN; "to", TO; "type", TYPE; "var", VAR;
  "while", WHILE; "exception", EXCEPTION; "try", TRY; "handle", HANDLE;
  "raise", RAISE;
  (* (fork-tiger's words for & and |) *)
  "and", AND; "or", OR;
]

let buf = Buffer.create 64
}

let blank = [' ' '\t' '\r' '\012']
let letter = ['a'-'z' 'A'-'Z']
let digit = ['0'-'9']

rule token = parse
  | '\n' { Lexing.new_line lexbuf; token lexbuf }
  | blank+ { token lexbuf }
  | "/*" { comment 0 lexbuf; token lexbuf }
  | letter (letter | digit | '_')* as id
      { match List.assoc_opt id keywords with Some k -> k | None -> ID id }
  | digit+ as n
      { match Int32.of_string n with
        | v -> INT v
        | exception _ -> raise (Error ("the number " ^ n ^ " is too big", lexbuf.Lexing.lex_start_p)) }
  | '"' { Buffer.clear buf; string lexbuf.Lexing.lex_start_p lexbuf }
  | "+" { PLUS } | "-" { MINUS } | "*" { TIMES } | "/" { DIVIDE }
  | "&" { AND } | "|" { OR }
  | "=" { EQ } | "<>" { NEQ } | "<" { LT } | "<=" { LE } | ">" { GT } | ">=" { GE }
  | ":=" { ASSIGN } | ":" { COLON } | "," { COMMA } | "." { DOT } | ";" { SEMICOLON }
  | "(" { LPAREN } | ")" { RPAREN } | "[" { LBRACK } | "]" { RBRACK }
  | "{" { LBRACE } | "}" { RBRACE }
  | eof { EOF }
  | _ as c { raise (Error (Printf.sprintf "a character %C" c, lexbuf.Lexing.lex_start_p)) }

and comment depth = parse
  | "*/" { if depth > 0 then comment (depth - 1) lexbuf }
  | "/*" { comment (depth + 1) lexbuf }
  | '\n' { Lexing.new_line lexbuf; comment depth lexbuf }
  | eof { raise (Error ("a comment without its end", lexbuf.Lexing.lex_start_p)) }
  | _ { comment depth lexbuf }

and string start = parse
  | '"' { STRING (Buffer.contents buf) }
  | "\\n" { Buffer.add_char buf '\n'; string start lexbuf }
  | "\\t" { Buffer.add_char buf '\t'; string start lexbuf }
  | "\\\"" { Buffer.add_char buf '"'; string start lexbuf }
  | "\\\\" { Buffer.add_char buf '\\'; string start lexbuf }
  | "\\" (digit digit digit as d)
      { let n = int_of_string d in
        if n > 255 then raise (Error ("a character \\" ^ d, lexbuf.Lexing.lex_start_p));
        Buffer.add_char buf (Char.chr n); string start lexbuf }
  | "\\^" (['@'-'_'] as c) { Buffer.add_char buf (Char.chr (Char.code c - 64)); string start lexbuf }
  | "\\" { skip lexbuf; string start lexbuf }
  | '\n' { Lexing.new_line lexbuf; Buffer.add_char buf '\n'; string start lexbuf }
  | eof { raise (Error ("a string without its end", start)) }
  | _ as c { Buffer.add_char buf c; string start lexbuf }

(* \ blanks \: a string's text continued *)
and skip = parse
  | '\n' { Lexing.new_line lexbuf; skip lexbuf }
  | blank { skip lexbuf }
  | "\\" { () }
  | _ { raise (Error ("an escape \\ in a string", lexbuf.Lexing.lex_start_p)) }
