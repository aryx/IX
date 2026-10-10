(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lex.mli *)

exception Error of int * string

type regexp =
  | Chars of string
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of string * regexp

type code = { text : string; line : int; col : int }
type clause = { re : regexp; action : code }
type rule = { name : string; params : string list; clauses : clause list }
type t = { header : code option; rules : rule list; trailer : code option }

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

type token =
  | Ident of string | Char of int | String of string | Code of code
  | Sym of char                       (* = | * + ? ( ) [ ] ^ - _ # *)
  | End

let set f = String.init 257 (fun c -> if f c then '\001' else '\000')
let one c = set (fun c' -> c' = c)

(* the text and where the reader is: its offset, its line, the offset of its line's start *)
type input = { s : string; mutable i : int; mutable line : int; mutable bol : int }

let error (t : input) fmt = Printf.ksprintf (fun m -> raise (Error (t.line, m))) fmt
let peek (t : input) k = if t.i + k < String.length t.s then t.s.[t.i + k] else '\000'
let advance (t : input) = if peek t 0 = '\n' then begin t.line <- t.line + 1; t.bol <- t.i + 1 end; t.i <- t.i + 1

(* a character after a backslash, in a character or a string: its code *)
let escape (t : input) =
  let c = peek t 0 in
  let digit k = Char.code (peek t k) - 48 in
  let hex k = let d = Char.code (Char.lowercase_ascii (peek t k)) in if d >= 97 then d - 87 else d - 48 in
  if c >= '0' && c <= '9' then begin
    let n = (100 * digit 0) + (10 * digit 1) + digit 2 in
    advance t; advance t; advance t; n
  end
  else if c = 'x' then begin let n = (16 * hex 1) + hex 2 in advance t; advance t; advance t; n end
  else begin
    advance t;
    Char.code (match c with 'n' -> '\n' | 't' -> '\t' | 'r' -> '\r' | 'b' -> '\b' | c -> c)
  end

(* OCaml's text skipped: a string, a comment (which nests, and holds
 * strings), a character (not a type variable's quote) *)
let rec skip_string (t : input) =
  advance t;
  while t.i < String.length t.s && peek t 0 <> '"' do if peek t 0 = '\\' then advance t; advance t done;
  if t.i >= String.length t.s then error t "a string is not ended";
  advance t

and skip_comment (t : input) =
  let start = t.line in
  advance t; advance t;
  while not (peek t 0 = '*' && peek t 1 = ')') do
    if t.i >= String.length t.s then raise (Error (start, "a comment is not ended"));
    if peek t 0 = '(' && peek t 1 = '*' then skip_comment t else if peek t 0 = '"' then skip_string t else advance t
  done;
  advance t; advance t

(* { ... }: the text between, its braces matched *)
let code (t : input) =
  advance t;
  let start = t.i and line = t.line and col = t.i - t.bol in
  let depth = ref 1 in
  while !depth > 0 do
    if t.i >= String.length t.s then raise (Error (line, "an action is not ended"));
    match peek t 0 with
    | '"' -> skip_string t
    | '(' when peek t 1 = '*' -> skip_comment t
    | '\'' when peek t 1 = '\\' -> advance t; advance t; ignore (escape t); advance t
    | '\'' when peek t 2 = '\'' -> advance t; advance t; advance t
    | '{' -> incr depth; advance t
    | '}' -> decr depth; advance t
    | _ -> advance t
  done;
  { text = String.sub t.s start (t.i - 1 - start); line; col }

let is_ident c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_' || c = '\''

let rec token (t : input) : token =
  match peek t 0 with
  | ' ' | '\t' | '\r' | '\n' | '\012' -> advance t; token t
  | '(' when peek t 1 = '*' -> skip_comment t; token t
  | '\000' when t.i >= String.length t.s -> End
  | '{' -> Code (code t)
  | '\'' ->
      advance t;
      let c = if peek t 0 = '\\' then (advance t; escape t) else (let c = Char.code (peek t 0) in advance t; c) in
      if peek t 0 <> '\'' then error t "a character is not ended";
      advance t;
      Char c
  | '"' ->
      advance t;
      let b = Buffer.create 16 in
      while peek t 0 <> '"' do
        if t.i >= String.length t.s then error t "a string is not ended";
        if peek t 0 = '\\' then (advance t; Buffer.add_char b (Char.chr (escape t))) else (Buffer.add_char b (peek t 0); advance t)
      done;
      advance t;
      String (Buffer.contents b)
  | c when is_ident c && c <> '\'' && not (c = '_' && not (is_ident (peek t 1))) ->
      let start = t.i in
      while is_ident (peek t 0) do advance t done;
      Ident (String.sub t.s start (t.i - start))
  | ('=' | '|' | '*' | '+' | '?' | '(' | ')' | '[' | ']' | '^' | '-' | '_' | '#') as c -> advance t; Sym c
  | c -> error t "the character %C" c

(*****************************************************************************)
(* The description *)
(*****************************************************************************)

let read (s : string) : t =
  let t = { s; i = 0; line = 1; bol = 0 } in
  (* one token ahead *)
  let tok = ref (token t) in
  let next () = tok := token t in
  let expect c = if !tok = Sym c then next () else error t "%C expected" c in
  let ident () = match !tok with Ident x -> next (); x | _ -> error t "a name expected" in
  let named = Hashtbl.create 16 in
  (* [ 'a'-'z' '_' ], [^ ... ]: of the characters, not of the end *)
  let cls () =
    let neg = !tok = Sym '^' in
    if neg then next ();
    let flags = Bytes.make 257 '\000' in
    let rec items () =
      match !tok with
      | Char a ->
          next ();
          let b = if !tok = Sym '-' then (next (); match !tok with Char b -> next (); b | _ -> error t "a character expected after -") else a in
          for c = a to b do Bytes.set flags c '\001' done;
          items ()
      | String str -> next (); String.iter (fun c -> Bytes.set flags (Char.code c) '\001') str; items ()
      | _ -> expect ']'
    in
    items ();
    Chars (set (fun c -> c < 256 && (Bytes.get flags c = '\001') <> neg))
  in
  let rec atom () =
    match !tok with
    | Char c -> next (); Chars (one c)
    | String str -> next (); List.fold_right (fun c r -> if r = Eps then Chars (one (Char.code c)) else Seq (Chars (one (Char.code c)), r)) (List.init (String.length str) (String.get str)) Eps
    | Sym '_' -> next (); Chars (set (fun c -> c < 256))
    | Ident "eof" -> next (); Chars (one 256)
    | Ident x -> (match Hashtbl.find_opt named x with Some r -> next (); r | None -> error t "%s: no regexp of that name" x)
    | Sym '[' -> next (); cls ()
    | Sym '(' -> next (); let r = regexp () in expect ')'; r
    | _ -> error t "a regexp expected"
  and postfix () =
    let rec go r =
      match !tok with
      | Sym '*' -> next (); go (Star r)
      | Sym '+' -> next (); go (Seq (r, Star r))
      | Sym '?' -> next (); go (Alt (r, Eps))
      | _ -> r
    in
    go (atom ())
  and starts_atom () =
    match !tok with
    | Char _ | String _ | Sym ('_' | '[' | '(') -> true
    | Ident ("as" | "let" | "rule" | "and" | "parse") -> false
    | Ident _ -> true
    | _ -> false
  and seq () = let r = postfix () in if starts_atom () then Seq (r, seq ()) else r
  (* as binds less than |, which binds less than a sequence *)
  and regexp () =
    let rec go r =
      match !tok with
      | Sym '|' -> next (); go (Alt (r, seq ()))
      | Ident "as" -> next (); go (Bind (ident (), r))
      | Sym '#' -> error t "r1 # r2 is not read by mini-lex"
      | _ -> r
    in
    go (seq ())
  in
  let header = match !tok with Code c -> next (); Some c | _ -> None in
  while !tok = Ident "let" do
    next ();
    let x = ident () in
    expect '=';
    Hashtbl.replace named x (regexp ())
  done;
  let rule () =
    let name = ident () in
    let rec params () = match !tok with Sym '=' -> [] | _ -> let x = ident () in x :: params () in
    let params = params () in
    expect '=';
    if !tok = Ident "shortest" then error t "shortest is not read by mini-lex";
    if !tok <> Ident "parse" then error t "parse expected";
    next ();
    if !tok = Sym '|' then next ();
    let rec clauses () =
      let re = regexp () in
      let action = match !tok with Code c -> next (); c | _ -> error t "an action expected" in
      if !tok = Sym '|' then (next (); { re; action } :: clauses ()) else [ { re; action } ]
    in
    { name; params; clauses = clauses () }
  in
  if !tok <> Ident "rule" then error t "rule expected";
  next ();
  let rec rules () = let r = rule () in if !tok = Ident "and" then (next (); r :: rules ()) else [ r ] in
  let rules = rules () in
  let trailer = match !tok with Code c -> next (); Some c | _ -> None in
  if !tok <> End then error t "the end expected";
  { header; rules; trailer }
