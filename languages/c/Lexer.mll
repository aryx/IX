{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Lexer.mli *)

open Tree
open Tree_helpers
(* claude: the characters, from the input stack *)
open Pre

module P = Parser

(*****************************************************************************)
(* Keywords *)
(*****************************************************************************)

(* a keyword's symbol has its token's index + 1 as lexical *)
let keywords = [ "auto", P.LAUTO; "break", P.LBREAK; "case", P.LCASE; "char", P.LCHAR; "const", P.LCONSTNT;
  "continue", P.LCONTINUE; "default", P.LDEFAULT; "do", P.LDO; "double", P.LDOUBLE; "else", P.LELSE;
  "enum", P.LENUM; "extern", P.LEXTERN; "float", P.LFLOAT; "for", P.LFOR; "goto", P.LGOTO; "if", P.LIF;
  "inline", P.LINLINE; "int", P.LINT; "long", P.LLONG; "register", P.LREGISTER; "restrict", P.LRESTRICT;
  "return", P.LRETURN; "SET", P.LSET; "short", P.LSHORT; "signed", P.LSIGNED; "signof", P.LSIGNOF;
  "sizeof", P.LSIZEOF; "static", P.LSTATIC; "struct", P.LSTRUCT; "switch", P.LSWITCH; "typedef", P.LTYPEDEF;
  "typestr", P.LTYPESTR; "union", P.LUNION; "unsigned", P.LUNSIGNED; "USED", P.LUSED; "void", P.LVOID;
  "volatile", P.LVOLATILE; "while", P.LWHILE ]

let init () =
  Array.fill hash 0 nhash [];
  List.iteri (fun i (k, _) -> (lookup k).lexical <- i + 1) keywords

(*****************************************************************************)
(* The lexbuf over Pre's input stack *)
(*****************************************************************************)

(* a character at a time, so that the lexbuf is never far ahead *)
let lexbuf () =
  Lexing.from_function (fun b _ -> let c = read () in if c = eof then 0 else (Bytes.set b 0 c; 1))

(* The characters the automaton read ahead go back on the stack: before
 * anything else reads Pre's input itself (a directive, a macro's
 * arguments, a string's or a comment's characters), or pushes on it (a
 * macro's expansion, read before what followed its use). *)
let sync (lexbuf : Lexing.lexbuf) =
  let p = lexbuf.lex_curr_pos and n = lexbuf.lex_buffer_len in
  if n > p then begin
    push (Bytes.sub_string lexbuf.lex_buffer p (n - p));
    lexbuf.lex_buffer_len <- p
  end

(*****************************************************************************)
(* Strings, characters, numbers (lex.c's yylex) *)
(*****************************************************************************)

(* the rune whose UTF-8 starts with c (lex.c's getr) *)
let rune c =
  let c = Char.code c in
  let n, v = if c land 0xe0 = 0xc0 then 1, c land 0x1f else if c land 0xf0 = 0xe0 then 2, c land 0x0f else 3, c land 0x07 in
  let rec go n v = if n = 0 then v else go (n - 1) ((v lsl 6) lor (Char.code (getc ()) land 0x3f)) in
  go n v

(* a hex digit's value, 99 if c is none *)
let hexval c =
  if is_digit c then Char.code c - 48
  else if c >= 'a' && c <= 'f' then Char.code c - 87
  else if c >= 'A' && c <= 'F' then Char.code c - 55
  else 99

let is_octal c = c >= '0' && c <= '7'

(* a character in a string or a constant, or None at its end e
 * (lex.c's escchar); an escape gives a byte, not a rune *)
let escchar e longflg =
  let c = getc () in
  if c = '\n' then error_at !lineno "newline in string";
  if c <> '\\' then (if c = e then None else Some ((if longflg && c >= '\128' then rune c else Char.code c), false))
  else
    let c = getc () in
    if c = 'x' then begin
      let rec hex i v = if i = 0 then v else let c = getc () in if hexval c < 16 then hex (i - 1) ((v * 16) + hexval c) else (unget c; v) in
      Some (hex (if longflg then 6 else 2) 0, true)
    end
    else if is_octal c then begin
      let rec oct i v = if i = 0 then v else let c = getc () in if is_octal c then oct (i - 1) ((v * 8) + hexval c) else (unget c; v) in
      Some (oct (if longflg then 8 else 2) (hexval c), true)
    end
    else Some ((match c with 'n' -> 10 | 't' -> 9 | 'b' -> 8 | 'r' -> 13 | 'f' -> 12 | 'a' -> 7 | 'v' -> 11 | c -> Char.code c), false)

(* a string's bytes: the source's UTF-8 as it is, an escape as a byte *)
let lexstring () =
  let b = Buffer.create 16 in
  let rec go () = match escchar '"' false with None -> () | Some (c, _) -> Buffer.add_char b (Char.chr (c land 255)); go () in
  go ();
  Buffer.contents b

(* lex.c's mpatov: decimal, 0 octal, 0x hex; ~0 on overflow *)
let mpatov s =
  let n = String.length s in
  let parse base start =
    let rec go i v =
      if i >= n then Some v
      else
        let d = hexval s.[i] in
        if d >= base && base <> 8 then None
        else
          let nv = Int64.add (Int64.mul v (Int64.of_int base)) (Int64.of_int d) in
          if Int64.compare v 0L < 0 && Int64.compare nv 0L >= 0 then None else go (i + 1) nv
    in
    go start 0L
  in
  let r = if n > 1 && s.[0] = '0' then (if s.[1] = 'x' || s.[1] = 'X' then parse 16 2 else parse 8 1) else parse 10 0 in
  match r with Some v -> v | None -> -1L

(* an integer: its digits, then its suffix (U, L, LL in any order) *)
let integer digits suffix =
  let has c = String.contains (String.lowercase_ascii suffix) c in
  let uns = has 'u' and lng = has 'l' in
  let vlng = List.length (List.filter (fun c -> c = 'l' || c = 'L') (List.init (String.length suffix) (String.get suffix))) > 1 in
  let v = mpatov digits in
  let neg t = Int64.compare (convvtox v t) 0L < 0 in
  let t =
    if vlng then (if uns || neg Tvlong then Tuvlong else Tvlong)
    else if lng then (if uns || neg Tlong then Tulong else Tlong)
    else if uns || neg Tint then Tuint else Tint
  in
  P.LCONST (convvtox v t, t)

(* a float: its text, then its suffix (L a double, F a float) *)
let floating text suffix =
  P.LFCONST (float_of_string text, (if suffix = "f" || suffix = "F" then Tfloat else Tdouble))

(* a character constant's value: its first character, ' if none *)
let charconst longflg = match escchar '\'' longflg with Some (c, _) -> c | None -> 39

(* a name: a macro's use (its expansion is read next, then what
 * followed), a typedef's name, a keyword, or a name *)
let word lexbuf again name =
  let s = lookup name in
  if s.macro <> None then begin
    sync lexbuf;
    let text = macexpand s in
    push text;
    again lexbuf
  end
  else if s.sclass = Ctypedef || s.sclass = Ctypestr then P.LTYPE s
  else if s.lexical > 0 then snd (List.nth keywords (s.lexical - 1)) else P.LNAME s
}

let digit = ['0'-'9']
let hex = ['0'-'9' 'a'-'f' 'A'-'F']
let letter = ['a'-'z' 'A'-'Z' '_' '\128'-'\255']
let isuffix = ['u' 'U' 'l' 'L']*
let exponent = ['e' 'E'] ['+' '-']? digit*
let fsuffix = ['l' 'L' 'f' 'F']?

rule token = parse
  | [' ' '\t' '\011' '\012' '\r']+ { token lexbuf }
  | '\n' { incr lineno; token lexbuf }
  | '#' { sync lexbuf; domacro (); token lexbuf }
  | "/*"
    { sync lexbuf;
      let rec skip c = if c = '*' then (let c = getc () in if c = '/' then () else skip c) else skip (getc ()) in
      skip (getc ());
      token lexbuf }
  | "//" { sync lexbuf; let rec eol () = if getc () <> '\n' then eol () in eol (); token lexbuf }
  | "L'"
    { sync lexbuf;
      let v = charconst true in
      ignore (escchar '\'' true);
      P.LCONST (convvtox (Int64.of_int v) Tuint, Tuint) }
  | "L\""
    { sync lexbuf;
      let rec go acc = match escchar '"' true with None -> List.rev acc | Some (c, _) -> go (c :: acc) in
      (* claude: little-endian runes, as outlstring writes them *)
      P.LLSTRING (String.concat "" (List.map (fun c -> let b = Bytes.create 4 in Bytes.set_int32_le b 0 (Int32.of_int c); Bytes.to_string b) (go []))) }
  | '"' { sync lexbuf; P.LSTRING (lexstring ()) }
  | '\''
    { sync lexbuf;
      let v = charconst false in
      (match escchar '\'' false with None -> () | Some _ -> error_at !lineno "missing '");
      P.LCONST (convvtox (Int64.of_int v) Tchar, Tint) }
  | letter (letter | digit)* as name { word lexbuf token name }
  (* a float has a point or an exponent; else hex, octal (a leading 0) or decimal *)
  | (digit+ '.' digit* exponent? | '.' digit+ exponent? | digit+ exponent as text) (fsuffix as suffix)
    { floating (String.map (fun c -> if c = 'E' then 'e' else c) text) suffix }
  | ('0' ['x' 'X'] hex* as digits) (isuffix as suffix) { integer digits suffix }
  | (digit+ as digits) (isuffix as suffix) { integer digits suffix }
  | "..." { P.LDOTS }
  | "->" { P.LMG } | "++" { P.LPP } | "--" { P.LMM }
  | "<<=" { P.LLSHE } | ">>=" { P.LRSHE } | "<<" { P.LLSH } | ">>" { P.LRSH }
  | "<=" { P.LLE } | ">=" { P.LGE } | "==" { P.LEQ } | "!=" { P.LNE }
  | "&&" { P.LANDAND } | "||" { P.LOROR }
  | "+=" { P.LPE } | "-=" { P.LME } | "*=" { P.LMLE } | "/=" { P.LDVE } | "%=" { P.LMDE }
  | "&=" { P.LANDE } | "|=" { P.LORE } | "^=" { P.LXORE }
  | ';' { P.SEMI } | ',' { P.COMMA } | '=' { P.ASSIGN } | '?' { P.QUESTION } | ':' { P.COLON }
  | '|' { P.OR } | '^' { P.XOR } | '&' { P.AND } | '<' { P.LT } | '>' { P.GT }
  | '+' { P.PLUS } | '-' { P.MINUS } | '*' { P.STAR } | '/' { P.SLASH } | '%' { P.PERCENT }
  | '(' { P.LPAREN } | ')' { P.RPAREN } | '[' { P.LBRACK } | ']' { P.RBRACK }
  | '{' { P.LBRACE } | '}' { P.RBRACE } | '.' { P.DOT } | '!' { P.NOT } | '~' { P.TILDE }
  | eof { P.EOF }
  | _ as c { error_at !lineno "illegal character: %c" c }
