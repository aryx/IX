{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The lexer: lex.c's yylex, in ocamllex. What lex.c does that a
 * regular lexer does not is in [token], around the rule:
 *  - a / starts a regular expression or is a division by what came
 *    before it (the C's grammar tells its lexer, in the middle of a
 *    rule; here the last token says: after an operand, a division);
 *  - a } is given as a ; then a }: the last statement of a block
 *    needs no ; of its own;
 *  - a name is a parameter's number inside its function, a function's
 *    when a ( follows it at once, else a variable; $name is the field
 *    whose number the variable has, $NF and $param the general $(...).
 * A number is the longest text that strtoll (so 011 is 9) or strtod
 * reads, as a field's is. *)
open Parser

let keywords : (string * token) list =
  [ "BEGIN", XBEGIN; "END", XEND; "NF", VARNF; "atan2", BLTIN Ast.Atan2; "break", BREAK; "close", CLOSE;
    "continue", CONTINUE; "cos", BLTIN Ast.Cos; "delete", DELETE; "do", DO; "else", ELSE; "exit", EXIT;
    "exp", BLTIN Ast.Exp; "fflush", BLTIN Ast.Fflush; "for", FOR; "func", FUNC; "function", FUNC;
    "getline", GETLINE; "gsub", SUBOP true; "if", IF; "in", IN; "index", INDEX; "int", BLTIN Ast.Int;
    "length", BLTIN Ast.Length; "log", BLTIN Ast.Log; "match", MATCHFCN; "next", NEXT; "nextfile", NEXTFILE;
    "print", PRINT; "printf", PRINTF; "rand", BLTIN Ast.Rand; "return", RETURN; "sin", BLTIN Ast.Sin;
    "split", SPLIT; "sprintf", SPRINTF; "sqrt", BLTIN Ast.Sqrt; "srand", BLTIN Ast.Srand; "sub", SUBOP false;
    "substr", SUBSTR; "system", BLTIN Ast.System; "tolower", BLTIN Ast.Tolower; "toupper", BLTIN Ast.Toupper;
    "utf", BLTIN Ast.Utf; "while", WHILE ]

let error msg = raise (Cell.Syntax msg)

let variable name = Cell.install Cell.symtab name Cell.unset

(* a name: a keyword, a parameter, a function called, a variable *)
let word w called =
  match List.assoc_opt w keywords with
  | Some FUNC -> if !Scope.in_function then error "illegal nested function"; FUNC
  | Some RETURN -> if not !Scope.in_function then error "return not in function"; RETURN
  | Some token -> token
  | None ->
      match (if called || not !Scope.in_function then None else Scope.param w) with
      | Some n -> ARG n
      | None -> if called then CALL (variable w) else VAR (variable w)

(* the braces, brackets and parentheses open (an error says which are missing) *)
let braces = ref 0
let brackets = ref 0
let parens = ref 0
(* the text's end was reached (the C then has no file's name for an error) *)
let at_end = ref false
(* a function's last brace was given: it ends before the next token *)
let function_ends = ref false

(* the tokens to give before the rule is asked again *)
let pending : token list ref = ref []

(* a string's characters, its escapes done (lex.c's string) *)
let unescape s =
  let n = String.length s in
  let b = Buffer.create n in
  let octal k = k < n && s.[k] >= '0' && s.[k] <= '7' in
  let hex k = k < n && (match s.[k] with '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true | _ -> false) in
  let rec go k =
    if k < n then
      if s.[k] <> '\\' || k + 1 >= n then (Buffer.add_char b s.[k]; go (k + 1))
      else match s.[k + 1] with
        | 'n' -> Buffer.add_char b '\n'; go (k + 2)
        | 't' -> Buffer.add_char b '\t'; go (k + 2)
        | 'f' -> Buffer.add_char b '\012'; go (k + 2)
        | 'r' -> Buffer.add_char b '\r'; go (k + 2)
        | 'b' -> Buffer.add_char b '\b'; go (k + 2)
        | 'v' -> Buffer.add_char b '\011'; go (k + 2)
        | 'a' -> Buffer.add_char b '\007'; go (k + 2)
        | '0' .. '7' ->
            let rec digits j v = if j < k + 4 && octal j then digits (j + 1) ((8 * v) + Char.code s.[j] - 48) else (j, v) in
            let j, v = digits (k + 1) 0 in
            Buffer.add_char b (Char.chr (v land 255)); go j
        | 'x' ->
            let rec digits j v = if hex j then digits (j + 1) (((16 * v) + int_of_string ("0x" ^ String.make 1 s.[j])) land 255) else (j, v) in
            let j, v = digits (k + 2) 0 in
            Buffer.add_char b (Char.chr v); go j
        | c -> Buffer.add_char b c; go (k + 2) in
  go 0;
  Buffer.contents b

(* give back the token's last characters *)
let back (lexbuf : Lexing.lexbuf) n =
  lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos - n;
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_cnum = lexbuf.lex_curr_p.pos_cnum - n }
}

let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z' '_']
let name = letter (letter | digit)*
let in_string = [^ '"' '\\' '\n' '\r'] | '\\' _

rule token_of division = parse
  | [' ' '\t' '\r']+ { token_of division lexbuf }
  | '#' [^ '\n']* { token_of division lexbuf }
  | '\\' '\r'? '\n' { token_of division lexbuf }
  | '\n' { NL }
  | (digit | '.') (digit | ['e' 'E' '.' '+' '-'])* as s
      { match Cell.number_prefix s with
        | Some (f, stop) ->
            back lexbuf (String.length s - stop);
            NUMBER { name = ""; v = Scalar { num = true; str = false; f; s = String.sub s 0 stop }; kind = Constant }
        | None -> back lexbuf (String.length s - 1); OTHER }
  | (name as w) ('(' as p)? { if p <> None then back lexbuf 1; word w (p <> None) }
  | '"' (in_string* as s) '"' { STRING { name = ""; v = Scalar (Cell.of_string (unescape s)); kind = Constant } }
  | '"' (in_string* as s) ['\n' '\r']? { error (Printf.sprintf "non-terminated string %s..." (String.sub s 0 (min 10 (String.length s)))) }
  | '$' (name as w)
      { if w = "NF" then (pending := [ LPAREN; VARNF; RPAREN ]; INDIRECT)
        else if !Scope.in_function && Scope.param w <> None then (back lexbuf (String.length w); INDIRECT)
        else IVAR (variable w) }
  | '$' { INDIRECT }
  | ';' { SEMI }
  | "&&" { AND } | "||" { BOR } | '|' { BAR }
  | "!=" { NE } | "!~" { MATCHOP true } | '!' { NOT } | '~' { MATCHOP false }
  | "<=" { LE } | '<' { LT } | "==" { EQ } | '=' { ASGNOP Ast.Set }
  | ">=" { GE } | ">>" { APPEND } | '>' { GT }
  | "++" { INCR } | "+=" { ASGNOP Ast.Add_to } | '+' { PLUS }
  | "--" { DECR } | "-=" { ASGNOP Ast.Sub_to } | '-' { MINUS }
  | "*=" { ASGNOP Ast.Mul_to } | "**=" { ASGNOP Ast.Pow_to } | "**" { POWER } | '*' { STAR }
  | "%=" { ASGNOP Ast.Mod_to } | '%' { PERCENT }
  | "^=" { ASGNOP Ast.Pow_to } | '^' { POWER }
  | "/=" { if division then ASGNOP Ast.Div_to else (back lexbuf 1; REGEXPR (regex (Buffer.create 16) lexbuf)) }
  | '/' { if division then SLASH else REGEXPR (regex (Buffer.create 16) lexbuf) }
  | '}' { decr braces; if !braces < 0 then error "extra }"; pending := [ RBRACE ]; SEMI }
  | '{' { incr braces; LBRACE } | '[' { incr brackets; LBRACKET }
  | ']' { decr brackets; if !brackets < 0 then error "extra ]"; RBRACKET }
  | '(' { incr parens; LPAREN } | ')' { decr parens; if !parens < 0 then error "extra )"; RPAREN }
  | ',' { COMMA } | '?' { QUESTION } | ':' { COLON }
  | eof { at_end := true; EOF }
  | _ { OTHER }

(* a regular expression's text, to its /: a \ and what follows it kept *)
and regex b = parse
  | '/' { Buffer.contents b }
  | '\\' _ as s { Buffer.add_string b s; regex b lexbuf }
  | '\n' { error (Printf.sprintf "newline in regular expression %s..." (Buffer.sub b 0 (min 10 (Buffer.length b)))) }
  | eof { Buffer.contents b }
  | _ as c { Buffer.add_char b c; regex b lexbuf }

{
(* a / divides: an operand has just ended *)
let last_was_operand = ref false

(* did the C's lexer look at the character after the last token (a
 * name, a number, an operator that may be longer): an error's context
 * then goes on to the line's end *)
let looked_ahead = ref false

let token lexbuf =
  (* (the names after a function's last brace are not its parameters;
   * not sooner: the grammar is still at the function's last statement
   * when it asks for the brace) *)
  if !function_ends then (function_ends := false; Scope.in_function := false);
  let peeked text = List.mem text [ "&"; "|"; "!"; "<"; "="; ">"; "+"; "-"; "*"; "**"; "%"; "^" ]
    || (text <> "" && (match text.[0] with 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9' | '.' -> true | _ -> false)) in
  let t = match !pending with
    | t :: rest ->
        pending := rest; looked_ahead := false;
        if t = RBRACE && !braces = 0 then function_ends := true;
        t
    | [] ->
        match token_of !last_was_operand lexbuf with
        | t -> looked_ahead := (match t with STRING _ | REGEXPR _ | EOF -> false | _ -> peeked (Lexing.lexeme lexbuf)); t
        | exception e -> looked_ahead := peeked (Lexing.lexeme lexbuf); raise e in
  (* a regular expression may start only where an expression may: after
   * an operator, a separator, a statement's word *)
  last_was_operand := (match t with
    | NL | SEMI | LBRACE | RBRACE | LPAREN | LBRACKET | COMMA | NOT | AND | BOR | MATCHOP _ | ASGNOP _ | QUESTION | COLON
    | EQ | NE | LT | LE | GT | GE | APPEND | BAR | PLUS | MINUS | STAR | SLASH | PERCENT | POWER
    (* (/a/ /b/: two rules) *)
    | PRINT | PRINTF | RETURN | EXIT | CLOSE | ELSE | DO | IN | REGEXPR _ -> false
    | _ -> true);
  t
}
