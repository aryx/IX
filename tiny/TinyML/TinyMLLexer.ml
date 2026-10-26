(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLLexer.mli *)
open Common

(* (old: a format, Printf.ksprintf's: tiny-ml reads a format only where
 * it is written, Printf.sprintf at the call) *)
let error s = failwith s

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

(* a keyword and a symbol are both KW *)
type token =
  | INT of int | CHAR of int | STR of string | LID of string | UID of string
  | KW of string | EOF

let keywords =
  [ "let"; "rec"; "in"; "fun"; "function"; "match"; "with"; "if"; "then";
    "else"; "begin"; "end"; "try"; "type"; "of"; "exception"; "external";
    "and"; "when"; "as"; "while"; "for"; "to"; "downto"; "do"; "done"; "mod";
    "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr"; "or"; "open" ]

let symbols =
  [ "|||"; ";;"; "->"; "::"; ":="; ":>"; "<-"; "<="; ">="; "<>"; "==";
    "!="; "&&"; "||"; "|>"; ".["; "~-" ]

(* both as tables, which the lexer looks a word up in (old: List.mem
 * over the keywords at each name, List.find_opt over the symbols at
 * each other character, a String.sub for each: most of the time of a
 * compilation's lexing, a million comparisons for TinyML.ml) *)
let table l =
  let t = Hashtbl.create 64 in
  List.iter (fun k -> Hashtbl.replace t k ()) l;
  t
let keyword = table keywords
let symbol = table symbols

(* the tokens of a file, each with its line; String.length is one
 * name, true and false constructors *)
let lex (s : string) : (token * int) array =
  let n = String.length s and out = ref [] and line = ref 1 in
  let add t = out := (t, !line) :: !out in
  (* (old: 'a' .. 'z' and the others as patterns: tiny-ml has no
   * character ranges) *)
  let lower c = c >= 'a' && c <= 'z' and upper c = c >= 'A' && c <= 'Z'
  and digit c = c >= '0' && c <= '9' in
  let is_id c = lower c || upper c || digit c || c = '_' || c = '\'' in
  let rec span j = if j < n && is_id s.[j] then span (j + 1) else j in
  let escape i =
    match s.[i] with
    | 'n' -> 10, i + 1 | 't' -> 9, i + 1 | 'r' -> 13, i + 1 | 'b' -> 8, i + 1
    | c when digit c -> int_of_string (String.sub s i 3), i + 3
    | c -> Char.code c, i + 1
  in
  let rec comment i depth =
    if i + 1 >= n then error "unterminated comment"
    else if s.[i] = '*' && s.[i + 1] = ')' then
      if depth = 1 then i + 2 else comment (i + 2) (depth - 1)
    else if s.[i] = '(' && s.[i + 1] = '*' then comment (i + 2) (depth + 1)
    else (if s.[i] = '\n' then incr line; comment (i + 1) depth)
  in
  let rec go i =
    if i < n then
      match s.[i] with
      | '\n' -> incr line; go (i + 1)
      | ' ' | '\t' | '\r' -> go (i + 1)
      | '(' when i + 1 < n && s.[i + 1] = '*' -> go (comment (i + 2) 1)
      | c when digit c ->
          let j = span i in
          add (INT (int_of_string (String.sub s i (j - i))));
          go j
      | c when lower c || c = '_' ->
          let j = span i in
          let w = String.sub s i (j - i) in
          add
            (if w = "_" then KW w
             else if Hashtbl.mem keyword w then KW w
             else if w = "true" || w = "false" then UID w
             else LID w);
          go j
      | c when upper c ->
          let j = span i in
          let j =
            if j + 1 < n && s.[j] = '.' && (lower s.[j + 1] || upper s.[j + 1])
            then span (j + 1)
            else j
          in
          let w = String.sub s i (j - i) in
          (* (M.C is the constructor C: constructors are one namespace) *)
          add
            (match String.rindex_opt w '.' with
             | Some k when w.[k + 1] >= 'a' -> LID w
             | Some k -> UID (String.sub w (k + 1) (String.length w - k - 1))
             | None -> UID w);
          go j
      | '\'' when i + 2 < n && (s.[i + 2] = '\'' || s.[i + 1] = '\\') ->
          let c, j =
            if s.[i + 1] = '\\' then escape (i + 2) else Char.code s.[i + 1], i + 2
          in
          add (CHAR c);
          go (j + 1)
      (* {|...|}, OCaml's quoted string: its text as it is, no escape *)
      | '{' when i + 1 < n && s.[i + 1] = '|' ->
          let rec close j =
            if j + 1 >= n then error "unterminated string"
            else if s.[j] = '|' && s.[j + 1] = '}' then j
            else (if s.[j] = '\n' then incr line; close (j + 1))
          in
          let j = close (i + 2) in
          add (STR (String.sub s (i + 2) (j - i - 2)));
          go (j + 2)
      | '"' ->
          let b = Buffer.create 16 in
          let rec str j =
            match s.[j] with
            | '"' -> j + 1
            | '\\' ->
                let c, j = escape (j + 1) in
                Buffer.add_char b (Char.chr c);
                str j
            | c -> if c = '\n' then incr line; Buffer.add_char b c; str (j + 1)
          in
          let j = str (i + 1) in
          add (STR (Buffer.contents b));
          go j
      | _ ->
          (* the longest symbol here, 3 characters, 2, or this one *)
          let sym k =
            if i + k <= n && Hashtbl.mem symbol (String.sub s i k)
            then Some (String.sub s i k)
            else None
          in
          let p = sym 3 ||| (sym 2 ||| String.make 1 s.[i]) in
          add (KW p);
          go (i + String.length p)
  in
  go 0;
  add EOF;
  Array.of_list (List.rev !out)
