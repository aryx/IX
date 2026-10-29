{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The reduced C#'s tokens: identifiers and keywords, numbers (an L for
 * long, a dot for double), strings and characters with C#'s escapes,
 * comments of both kinds, the operators by their longest form. *)

type token =
  | ID of string
  | KW of string                  (* class, int, new, if... *)
  | INT of int32
  | LONG of int64
  | DOUBLE of float
  | STRING of string
  | CHAR of int
  | OP of string                  (* ( ) { } [ ] ; , . ? : and the operators *)
  | EOF

exception Error of string * int

let keywords = [
  "abstract"; "base"; "bool"; "break"; "catch"; "char"; "class"; "continue";
  "do"; "double"; "else"; "false"; "finally"; "for"; "foreach"; "get"; "if";
  "in"; "int"; "interface"; "internal"; "is"; "long"; "namespace"; "new";
  "null"; "object"; "out"; "override"; "private"; "protected"; "public";
  "readonly"; "ref"; "return"; "sealed"; "static"; "string"; "this"; "throw";
  "true"; "try"; "using"; "virtual"; "void"; "while";
]

let line = ref 1
let buf = Buffer.create 64

let escape (c : char) : char =
  match c with
  | 'n' -> '\n' | 't' -> '\t' | 'r' -> '\r' | '0' -> '\000'
  | c -> c
}

let blank = [' ' '\t' '\r']
let letter = ['a'-'z' 'A'-'Z' '_']
let digit = ['0'-'9']

rule token = parse
  | '\n' { incr line; token lexbuf }
  | blank+ { token lexbuf }
  | "//" [^ '\n']* { token lexbuf }
  | "/*" { comment lexbuf; token lexbuf }
  | letter (letter | digit)* as id
      { if List.mem id keywords then KW id else ID id }
  | (digit+ as n) ['L' 'l'] { LONG (Int64.of_string n) }
  | digit+ '.' digit+ as f { DOUBLE (float_of_string f) }
  | digit+ as n
      { match Int32.of_string n with
        | v -> INT v
        | exception _ -> raise (Error ("the number " ^ n ^ " is too big", !line)) }
  | '"' { Buffer.clear buf; string lexbuf }
  | "'\\" (_ as c) "'" { CHAR (Char.code (escape c)) }
  | "'" ([^ '\\' '\''] as c) "'" { CHAR (Char.code c) }
  | "++" | "--" | "&&" | "||" | "==" | "!=" | "<=" | ">=" | "+=" | "-=" | "*="
  | "/=" | "%=" | "=>" as op { OP op }
  | ['(' ')' '{' '}' '[' ']' ';' ',' '.' '?' ':' '+' '-' '*' '/' '%' '<' '>'
     '=' '!' '&' '|'] as c { OP (String.make 1 c) }
  | eof { EOF }
  | _ as c { raise (Error (Printf.sprintf "a character %C" c, !line)) }

and comment = parse
  | "*/" { () }
  | '\n' { incr line; comment lexbuf }
  | eof { raise (Error ("a comment without its end", !line)) }
  | _ { comment lexbuf }

and string = parse
  | '"' { STRING (Buffer.contents buf) }
  | '\\' (_ as c) { Buffer.add_char buf (escape c); string lexbuf }
  | '\n' { raise (Error ("a string without its end", !line)) }
  | eof { raise (Error ("a string without its end", !line)) }
  | _ as c { Buffer.add_char buf c; string lexbuf }
