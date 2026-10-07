{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The lexer: hoc.y's yylex, in ocamllex. A name's token is what the
 * name is when it is read: a variable, a built-in, a function or a
 * procedure (so f(1) before f's definition is a syntax error, and a
 * definition's own name is a function inside its body: the parser says
 * so before the body is read). The lines are counted here, at each
 * newline read as one. *)
open Parser

let keywords =
  [ "proc", PROC; "func", FUNC; "return", RETURN; "if", IF; "else", ELSE; "while", WHILE; "for", FOR;
    "print", PRINT; "read", READ ]

let error msg = raise (Symbol.Error msg)

(* the C's buffers: 99 characters for a name and for a string *)
let max = 99

let name s =
  if String.length s > max then error ("name too long " ^ String.sub s 0 max);
  match List.assoc_opt s keywords with
  | Some token -> token
  | None ->
      let symbol = Symbol.find s in
      match symbol.value with
      | Undef | Var _ -> VAR symbol
      | Builtin f -> BLTIN f
      | Func _ -> FUNCTION symbol
      | Proc _ -> PROCEDURE symbol

(* a number's text, read as read(x) reads one *)
let number s =
  let k = ref 0 in
  fst (Input.number (fun () -> incr k; if !k <= String.length s then Char.code s.[!k - 1] else -1))

(* a string's characters: \b \f \n \r \t, any other one after a \ itself *)
let unescape s =
  let b = Buffer.create (String.length s) in
  let rec go k =
    if k < String.length s then
      if s.[k] = '\\' then begin
        Buffer.add_char b (match s.[k + 1] with 'b' -> '\b' | 'f' -> '\012' | 'n' -> '\n' | 'r' -> '\r' | 't' -> '\t' | c -> c);
        go (k + 2)
      end else (Buffer.add_char b s.[k]; go (k + 1)) in
  go 0;
  if Buffer.length b > max then error ("string too long " ^ Buffer.sub b 0 max);
  Buffer.contents b
}

let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z' '_' '\128'-'\255']
let in_string = [^ '"' '\\' '\n'] | '\\' _

rule token = parse
  | [' ' '\t']+ { token lexbuf }
  | '#' [^ '\n']* { token lexbuf }
  | '\\' '\n' { incr Input.lineno; token lexbuf }
  (* yylex goes on with the character after a \: not skipped if a space,
   * not looked at again if a \ *)
  | '\\' [' ' '\t' '\\'] { OTHER }
  | '\\' { token lexbuf }
  | '\n' { incr Input.lineno; NEWLINE }
  | (digit+ '.'? | '.') digit* (['e' 'E'] ['+' '-']? digit*)? as s { NUMBER (number s) }
  | letter (letter | digit)* as s { name s }
  | '"' (in_string* as s) '"' { STRING (unescape s) }
  (* (the message's space: execerror's second string, empty) *)
  | '"' in_string* { error "missing quote " }
  | "++" { INC } | "+=" { ADDEQ } | '+' { PLUS }
  | "--" { DEC } | "-=" { SUBEQ } | '-' { MINUS }
  | "*=" { MULEQ } | '*' { STAR }
  | "/=" { DIVEQ } | '/' { SLASH }
  | "%=" { MODEQ } | '%' { PERCENT }
  | ">=" { GE } | '>' { GT }
  | "<=" { LE } | '<' { LT }
  | "==" { EQ } | '=' { ASSIGN }
  | "!=" { NE } | '!' { NOT }
  | "||" { OR } | "&&" { AND }
  | '^' { CARET } | '(' { LPAREN } | ')' { RPAREN } | '{' { LBRACE } | '}' { RBRACE }
  | ',' { COMMA } | ';' { SEMI }
  | eof { EOF }
  | _ { OTHER }

{
(* the current input's tokens. A character at a time: the lexer has
 * read nothing past a line's end when the line runs, so read(x) finds
 * what follows it, and a line typed is run before the next one *)
let lexbuf () =
  Lexing.from_function (fun buf _ ->
    let c = Input.getc () in
    Input.last := c;
    if c < 0 then 0 else (Bytes.set buf 0 (Char.chr c); 1))
}
