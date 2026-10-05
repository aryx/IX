(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ML's tokens, ocamllex (plan_ml.md, decision 7): regular, with no
 * preprocessor. An operator's token is its class, which is its
 * precedence (the parser's INFIXOP0..4), from its first character, as
 * OCaml's: == and <> are INFIXOP0, @ and ^ INFIXOP1, and so on; mod,
 * land, lsl... are keywords of those classes. Comments nest, and a
 * string inside a comment is skipped as a string
 *)
{
open Parser

exception Error of string

let keywords = Hashtbl.create 64

let () =
  List.iter (fun (k, t) -> Hashtbl.replace keywords k t)
    [ "and", AND; "as", AS; "assert", ASSERT; "begin", BEGIN; "do", DO; "done", DONE; "downto", DOWNTO; "else", ELSE;
      "end", END; "exception", EXCEPTION; "external", EXTERNAL; "false", FALSE; "for", FOR; "fun", FUN; "function", FUNCTION;
      "if", IF; "in", IN; "let", LET; "match", MATCH; "module", MODULE; "mutable", MUTABLE; "of", OF; "open", OPEN;
      "or", OR; "rec", REC; "sig", SIG; "struct", STRUCT; "then", THEN; "to", TO; "true", TRUE; "try", TRY; "type", TYPE;
      "val", VAL; "when", WHEN; "while", WHILE; "with", WITH; "mod", INFIXOP3 "mod"; "land", INFIXOP3 "land";
      "lor", INFIXOP3 "lor"; "lxor", INFIXOP3 "lxor"; "lsl", INFIXOP4 "lsl"; "lsr", INFIXOP4 "lsr"; "asr", INFIXOP4 "asr" ]

let buf = Buffer.create 256

let escape = function 'n' -> '\n' | 't' -> '\t' | 'b' -> '\b' | 'r' -> '\r' | c -> c

let decimal s i = Char.chr (int_of_string (String.sub s i 3) land 255)
let hexa s i = Char.chr (int_of_string ("0x" ^ String.sub s i 2))

(* # n "file": the next line is the file's n *)
let directive lexbuf n f =
  let p = lexbuf.Lexing.lex_curr_p in
  lexbuf.Lexing.lex_curr_p <- { p with pos_lnum = int_of_string n - 1; pos_fname = (match f with Some f -> f | None -> p.pos_fname) }
}

let lowercase = ['a'-'z' '_']
let uppercase = ['A'-'Z']
let identchar = ['A'-'Z' 'a'-'z' '_' '\'' '0'-'9']
let symbolchar = ['!' '$' '%' '&' '*' '+' '-' '.' '/' ':' '<' '=' '>' '?' '@' '^' '|' '~']
let newline = '\n' | "\r\n"
let hex = ['0'-'9' 'A'-'F' 'a'-'f']
let int_literal =
  ['0'-'9'] ['0'-'9' '_']* | '0' ['x' 'X'] ['0'-'9' 'A'-'F' 'a'-'f' '_']+ | '0' ['o' 'O'] ['0'-'7' '_']+ | '0' ['b' 'B'] ['0'-'1' '_']+

rule token = parse
  | [' ' '\t' '\r' '\012']+ { token lexbuf }
  | newline { Lexing.new_line lexbuf; token lexbuf }
  (* mlpp: a line # n "file", as mlpp writes them (pp/): the next line
   * is the file's n *)
  | newline [' ' '\t']* '#' [' ' '\t']* (['0'-'9']+ as n) [' ' '\t']* ('"' ([^ '"' '\n']* as f) '"')? [^ '\n']*
      { directive lexbuf n f; token lexbuf }
  (* the file's first line: ocamllex's and ocamlyacc's files start so *)
  | '#' [' ' '\t']* (['0'-'9']+ as n) [' ' '\t']* ('"' ([^ '"' '\n']* as f) '"')? [^ '\n']*
      { if Lexing.lexeme_start lexbuf <> 0 then raise (Error "illegal character '#'");
        directive lexbuf n f; token lexbuf }
  | "(*" { comment 1 lexbuf; token lexbuf }
  | "_" { UNDERSCORE }
  | lowercase identchar* { let s = Lexing.lexeme lexbuf in match Hashtbl.find_opt keywords s with Some t -> t | None -> LIDENT s }
  | uppercase identchar* { UIDENT (Lexing.lexeme lexbuf) }
  | int_literal { INT (int_of_string (Lexing.lexeme lexbuf)) }
  (* 3l, an int32; 3L, an int64 *)
  | (int_literal as n) 'l' { INT32 n }
  | (int_literal as n) 'L' { INT64 n }
  | ['0'-'9'] ['0'-'9' '_']* ('.' ['0'-'9' '_']*)? (['e' 'E'] ['+' '-']? ['0'-'9']+)? { FLOAT (Lexing.lexeme lexbuf) }
  (* (the token starts at its first quote, not where its last piece does: mlpp's spans) *)
  | "\"" { let start = lexbuf.lex_start_p in Buffer.clear buf; string lexbuf; lexbuf.lex_start_p <- start; STRING (Buffer.contents buf) }
  (* {|...|}, {id|...|id}: nothing escaped *)
  | "{" (lowercase* as id) "|" { Buffer.clear buf; quoted id lexbuf; STRING (Buffer.contents buf) }
  | "'" ([^ '\\' '\'' '\n'] as c) "'" { CHAR c }
  | "'\\" (['\\' '\'' '"' 'n' 't' 'b' 'r' ' '] as c) "'" { CHAR (escape c) }
  | "'\\" ['0'-'9'] ['0'-'9'] ['0'-'9'] "'" { CHAR (decimal (Lexing.lexeme lexbuf) 2) }
  | "'\\x" hex hex "'" { CHAR (hexa (Lexing.lexeme lexbuf) 3) }
  | "(" { LPAREN } | ")" { RPAREN }
  | "{" { LBRACE } | "}" { RBRACE }
  | "[" { LBRACKET } | "]" { RBRACKET }
  | "[|" { LBRACKETBAR } | "|]" { BARRBRACKET }
  (* mlpp: [%bits "..."], [@@deriving show] *)
  | "[%" { LBRACKETPERCENT } | "[@@" [' ' '\t']* "deriving" { DERIVING }
  (* the other attributes, [@inline], [@@unboxed], [@@@warning "-32"]:
   * skipped (OCaml reads them in -pp's output, the text itself) *)
  | "[@" { attribute 1 lexbuf; token lexbuf }
  | "|" { BAR } | "*" { STAR } | "'" { QUOTE } | "," { COMMA }
  | "->" { MINUSGREATER } | "." { DOT } | ".." { DOTDOT }
  | ":" { COLON } | "::" { COLONCOLON } | ":=" { COLONEQUAL } | "<-" { LESSMINUS } | ":>" { COLONGREATER }
  | ";" { SEMI } | ";;" { SEMISEMI }
  | "=" { EQUAL } | "<" { LESS } | ">" { GREATER }
  | "&&" { AMPERAMPER } | "||" { BARBAR } | "&" { AMPERSAND }
  | "-" { SUBTRACTIVE "-" } | "-." { SUBTRACTIVE "-." }
  | "!=" { INFIXOP0 "!=" }
  (* ~x:e, ~x: a labeled argument or parameter *)
  | "~" (lowercase identchar* as l) ":" { LABEL l }
  | "~" { TILDE }
  | ['!' '?' '~'] symbolchar* { PREFIXOP (Lexing.lexeme lexbuf) }
  | ['=' '<' '>' '|' '&' '$'] symbolchar* { INFIXOP0 (Lexing.lexeme lexbuf) }
  | ['@' '^'] symbolchar* { INFIXOP1 (Lexing.lexeme lexbuf) }
  | ['+' '-'] symbolchar* { INFIXOP2 (Lexing.lexeme lexbuf) }
  | "**" symbolchar* { INFIXOP4 (Lexing.lexeme lexbuf) }
  | ['*' '/' '%'] symbolchar* { INFIXOP3 (Lexing.lexeme lexbuf) }
  | eof { EOF }
  | _ as c { raise (Error (Printf.sprintf "illegal character %C" c)) }

and comment depth = parse
  | "(*" { comment (depth + 1) lexbuf }
  | "*)" { if depth > 1 then comment (depth - 1) lexbuf }
  | "\"" { Buffer.clear buf; string lexbuf; comment depth lexbuf }
  | "{" (lowercase* as id) "|" { Buffer.clear buf; quoted id lexbuf; comment depth lexbuf }
  | "'" [^ '\\' '\'' '\n'] "'" | "'\\" _ "'" | "'\\" ['0'-'9'] ['0'-'9'] ['0'-'9'] "'" | "'\\x" hex hex "'" { comment depth lexbuf }
  | newline { Lexing.new_line lexbuf; comment depth lexbuf }
  | eof { raise (Error "unterminated comment") }
  | _ { comment depth lexbuf }

and string = parse
  | "\"" { () }
  | "\\" newline [' ' '\t']* { Lexing.new_line lexbuf; string lexbuf }
  | "\\" (['\\' '\'' '"' 'n' 't' 'b' 'r' ' '] as c) { Buffer.add_char buf (escape c); string lexbuf }
  | "\\" ['0'-'9'] ['0'-'9'] ['0'-'9'] { Buffer.add_char buf (decimal (Lexing.lexeme lexbuf) 1); string lexbuf }
  | "\\x" hex hex { Buffer.add_char buf (hexa (Lexing.lexeme lexbuf) 2); string lexbuf }
  | newline { Lexing.new_line lexbuf; Buffer.add_string buf (Lexing.lexeme lexbuf); string lexbuf }
  | eof { raise (Error "unterminated string") }
  | _ as c { Buffer.add_char buf c; string lexbuf }

and quoted id = parse
  | "|" (lowercase* as id') "}" { if id' <> id then (Buffer.add_string buf (Lexing.lexeme lexbuf); quoted id lexbuf) }
  | newline { Lexing.new_line lexbuf; Buffer.add_string buf (Lexing.lexeme lexbuf); quoted id lexbuf }
  | eof { raise (Error "unterminated string") }
  | _ as c { Buffer.add_char buf c; quoted id lexbuf }

and attribute depth = parse
  | "[" { attribute (depth + 1) lexbuf }
  | "]" { if depth > 1 then attribute (depth - 1) lexbuf }
  | "\"" { Buffer.clear buf; string lexbuf; attribute depth lexbuf }
  | newline { Lexing.new_line lexbuf; attribute depth lexbuf }
  | eof { raise (Error "unterminated attribute") }
  | _ { attribute depth lexbuf }
