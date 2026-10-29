{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* acid's lexer (principia's lex.c): its keywords, its numbers (decimal,
 * 0x hexadecimal, 0 octal, 0b binary, a float with its . or e), 'c'
 * characters, strings with C's escapes, a format after a backslash
 * (x\D), // comments to the line's end. At a terminal a newline ends a
 * statement (a ;) but inside braces, so that a definition may take
 * lines; in a file it is a blank. *)

open Parser

exception Error of string

(* whether a newline ends a statement (the input is acid's terminal) *)
let interactive = ref false

(* the last name or number read, for a syntax error's message *)
let symbol = ref ""
let depth = ref 0
let line = ref 1

let keywords = [
  "do", DO; "if", IF; "then", THEN; "else", ELSE; "while", WHILE; "loop", LOOP;
  "head", HEAD; "tail", TAIL; "append", APPEND; "defn", DEFN; "return", RETURN;
  "local", LOCAL; "aggr", COMPLEX; "union", COMPLEX; "adt", COMPLEX;
  "complex", COMPLEX; "delete", DELETE; "whatis", WHAT; "eval", EVAL;
  "builtin", BUILTIN ]

let escape c =
  match c with
  | '0' -> '\000' | 'n' -> '\n' | 'r' -> '\r' | 't' -> '\t' | 'b' -> '\b'
  | 'f' -> '\012' | 'a' -> '\007' | 'v' -> '\011' | c -> c

(* strtoull's base 0: 0x, a leading 0 octal; 0b binary (acid's) *)
let integer s =
  let n = String.length s in
  if n > 2 && s.[0] = '0' && (s.[1] = 'b' || s.[1] = 'B') then Int64.of_string ("0b" ^ String.sub s 2 (n - 2))
  else if n > 2 && s.[0] = '0' && (s.[1] = 'x' || s.[1] = 'X') then Int64.of_string ("0x" ^ String.sub s 2 (n - 2))
  else if n > 1 && s.[0] = '0' then Int64.of_string ("0o" ^ String.sub s 1 (n - 1))
  else Int64.of_string s
}

let digit = ['0'-'9']
let ident = ['a'-'z' 'A'-'Z' '_' '$' '\128'-'\255'] ['a'-'z' 'A'-'Z' '0'-'9' '_' '$' '\128'-'\255']*

rule token = parse
  | [' ' '\t' '\r'] { token lexbuf }
  | "//" [^ '\n']* '\n'? | "/*" [^ '\n']* '\n'? { incr line; token lexbuf }
  | '\n' { incr line; if !interactive && !depth = 0 then SEMI else token lexbuf }
  | "0x" ['0'-'9' 'a'-'f' 'A'-'F']+ as s { symbol := s; CONST (integer s) }
  | "0b" ['0' '1']+ as s { symbol := s; CONST (integer s) }
  | (digit+ '.' digit* | '.' digit+ | digit+) (['e' 'E'] ['-' '+']? digit+) as s { symbol := s; FCONST (float_of_string s) }
  | (digit+ '.' digit* | '.' digit+) as s { symbol := s; FCONST (float_of_string s) }
  | digit+ as s { symbol := s; CONST (integer s) }
  | '\'' '\\' (_ as c) '\'' { CONST (Int64.of_int (Char.code (escape c))) }
  | '\'' (_ as c) '\'' { CONST (Int64.of_int (Char.code c)) }
  | '"' { STRING (str (Buffer.create 16) lexbuf) }
  | ident as s { symbol := s; match List.assoc_opt s keywords with Some k -> k | None -> ID s }
  | '\\' (_ as c) { if String.contains Value.formats c then FMT c else raise (Error "syntax error") }
  | "->" { INDIR } | "--" { DEC } | "++" { INC }
  | "<<" { LSH } | ">>" { RSH } | "<=" { LEQ } | ">=" { GEQ }
  | "==" { EQ } | "!=" { NEQ } | "&&" { ANDAND } | "||" { OROR }
  | '{' { incr depth; LBRACE } | '}' { decr depth; RBRACE }
  | '(' { LPAREN } | ')' { RPAREN } | '[' { LBRACK } | ']' { RBRACK }
  | ';' { SEMI } | ':' { COLON } | ',' { COMMA } | '~' { TILDE }
  | '*' { STAR } | '@' { AT } | '^' { CARET } | '%' { PERCENT }
  | '!' { BANG } | '+' { PLUS } | '-' { MINUS } | '&' { AMP } | '|' { BAR }
  | '=' { ASSIGN } | '<' { LT } | '>' { GT } | '/' { SLASH } | '.' { DOT }
  | eof { EOF }
  | _ as c { raise (Error (Printf.sprintf "syntax error near '%c'" c)) }

and str b = parse
  | '"' { Buffer.contents b }
  | '\\' (_ as c) { Buffer.add_char b (escape c); str b lexbuf }
  | '\n' { raise (Error "newline in string constant") }
  | eof { raise (Error "<eof> in string constant") }
  | _ as c { Buffer.add_char b c; str b lexbuf }
