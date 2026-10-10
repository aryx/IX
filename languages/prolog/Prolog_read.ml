(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prolog_read.mli *)

exception Error of string * int

type token =
  | Tatom of string  (* a name, a run of symbols, ! or ; *)
  | Tquoted of string (* 'an atom': never an operator *)
  | Tvar of string
  | Tint of int
  | Tstring of string
  | Tpunct of char   (* ( ) [ ] { } , | *)
  | Tend             (* the dot that ends a clause *)
  | Teof

type t = {
  ops : Prolog.ops;
  text : string;
  mutable pos : int;          (* after the token *)
  mutable tok : token;
  mutable at : int;           (* where the token starts *)
  mutable space : bool;       (* blanks or a comment before it *)
  mutable call : bool;        (* an open parenthesis right after it *)
  mutable vars : (string * Prolog.term) list; (* the clause's, the last met first *)
}

let make (ops : Prolog.ops) (text : string) : t =
  { ops; text; pos = 0; tok = Teof; at = 0; space = true; call = false; vars = [] }

let position (r : t) : int = r.at

let line (r : t) (pos : int) : int =
  let n = ref 1 in
  String.iteri (fun (i : int) (c : char) -> if i < pos && c = '\n' then incr n) r.text;
  !n

(*****************************************************************************)
(* The tokens *)
(*****************************************************************************)

let is_blank (c : char) : bool = c = ' ' || c = '\t' || c = '\n' || c = '\r'

(* blanks and comments passed: was there any? *)
let skip_blanks (r : t) : bool =
  let n = String.length r.text in
  let start = r.pos in
  let again = ref true in
  while !again do
    if r.pos < n && is_blank r.text.[r.pos] then r.pos <- r.pos + 1
    else if r.pos < n && r.text.[r.pos] = '%' then
      while r.pos < n && r.text.[r.pos] <> '\n' do
        r.pos <- r.pos + 1
      done
    else if r.pos + 1 < n && r.text.[r.pos] = '/' && r.text.[r.pos + 1] = '*' then begin
      let from = r.pos in
      r.pos <- r.pos + 2;
      while r.pos + 1 < n && not (r.text.[r.pos] = '*' && r.text.[r.pos + 1] = '/') do
        r.pos <- r.pos + 1
      done;
      if r.pos + 1 >= n then raise (Error ("a comment is not closed", from));
      r.pos <- r.pos + 2
    end
    else again := false
  done;
  r.pos > start

(* the character after a backslash *)
let escape (r : t) : char =
  let n = String.length r.text in
  if r.pos >= n then raise (Error ("end of file after a backslash", r.pos));
  let c = r.text.[r.pos] in
  r.pos <- r.pos + 1;
  match c with
  | 'n' -> '\n' | 't' -> '\t' | 'r' -> '\r' | 'a' -> '\007' | 'b' -> '\b' | 'f' -> '\012' | 'v' -> '\011'
  | '0' -> '\000' | 'e' -> '\027' | 's' -> ' '
  | c -> c

(* a text between two [quote]s; the quote doubled is one of it *)
let quoted (r : t) (quote : char) : string =
  let n = String.length r.text in
  let from = r.pos in
  let b = Buffer.create 16 in
  r.pos <- r.pos + 1;
  let closed = ref false in
  while not !closed do
    if r.pos >= n then raise (Error ("a quote is not closed", from));
    let c = r.text.[r.pos] in
    r.pos <- r.pos + 1;
    if c = quote then
      if r.pos < n && r.text.[r.pos] = quote then begin
        Buffer.add_char b quote;
        r.pos <- r.pos + 1
      end
      else closed := true
    else if c = '\\' then
      (* (a backslash at a line's end: the text goes on) *)
      if r.pos < n && r.text.[r.pos] = '\n' then r.pos <- r.pos + 1 else Buffer.add_char b (escape r)
    else Buffer.add_char b c
  done;
  Buffer.contents b

let run (r : t) (p : char -> bool) : string =
  let n = String.length r.text in
  let from = r.pos in
  while r.pos < n && p r.text.[r.pos] do
    r.pos <- r.pos + 1
  done;
  String.sub r.text from (r.pos - from)

let number (r : t) : token =
  let n = String.length r.text in
  let from = r.pos in
  if r.pos + 2 < n && r.text.[r.pos] = '0' && r.text.[r.pos + 1] = '\'' then begin
    (* 0'c: a character's code *)
    r.pos <- r.pos + 2;
    let c = r.text.[r.pos] in
    r.pos <- r.pos + 1;
    if c = '\\' then Tint (Char.code (escape r))
    else begin
      if c = '\'' && r.pos < n && r.text.[r.pos] = '\'' then r.pos <- r.pos + 1;
      Tint (Char.code c)
    end
  end
  else if r.pos + 2 < n && r.text.[r.pos] = '0' && r.text.[r.pos + 1] = 'x' then begin
    r.pos <- r.pos + 2;
    let digits = run r (fun (c : char) -> Prolog.is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) in
    match int_of_string_opt ("0x" ^ digits) with
    | Some v -> Tint v
    | None -> raise (Error ("a number is expected after 0x", from))
  end
  else begin
    let digits = run r Prolog.is_digit in
    if r.pos + 1 < n && r.text.[r.pos] = '.' && Prolog.is_digit r.text.[r.pos + 1] then
      raise (Error ("a number with a fraction: there are no floats here", from));
    match int_of_string_opt digits with
    | Some v -> Tint v
    | None -> raise (Error ("this number is too large", from))
  end

(* the next token, into the reader *)
let advance (r : t) : unit =
  let n = String.length r.text in
  r.space <- skip_blanks r;
  r.at <- r.pos;
  r.call <- false;
  if r.pos >= n then r.tok <- Teof
  else begin
    let c = r.text.[r.pos] in
    let tok : token =
      if Prolog.is_digit c then number r
      else if Prolog.is_upper c then Tvar (run r Prolog.is_alnum)
      else if Prolog.is_lower c then Tatom (run r Prolog.is_alnum)
      else if c = '\'' then Tquoted (quoted r '\'')
      else if c = '"' then Tstring (quoted r '"')
      else if String.contains "()[]{},|" c then begin
        r.pos <- r.pos + 1;
        Tpunct c
      end
      else if c = '!' || c = ';' then begin
        r.pos <- r.pos + 1;
        Tatom (String.make 1 c)
      end
      else if Prolog.is_symbol c then begin
        let s = run r Prolog.is_symbol in
        if s = "." && (r.pos >= n || is_blank r.text.[r.pos] || r.text.[r.pos] = '%') then Tend else Tatom s
      end
      else raise (Error (Printf.sprintf "the character %C is not Prolog's" c, r.pos)) in
    r.tok <- tok;
    r.call <- (match tok with Tatom _ | Tquoted _ -> r.pos < n && r.text.[r.pos] = '(' | _ -> false)
  end

(*****************************************************************************)
(* The terms *)
(*****************************************************************************)

let said (tok : token) : string =
  match tok with
  | Tatom s | Tquoted s | Tvar s -> s
  | Tint n -> string_of_int n
  | Tstring _ -> "a text"
  | Tpunct c -> String.make 1 c
  | Tend -> "the clause's end"
  | Teof -> "the end of the text"

let expect (r : t) (c : char) : unit =
  match r.tok with
  | Tpunct c' when c' = c -> advance r
  | tok -> raise (Error (Printf.sprintf "%c is expected, not %s" c (said tok), r.at))

let variable (r : t) (name : string) : Prolog.term =
  if name = "_" then Prolog.fresh ()
  else
    match List.assoc_opt name r.vars with
    | Some v -> v
    | None ->
        let v = Prolog.fresh () in
        r.vars <- (name, v) :: r.vars;
        v

(* can the token begin a term? (after a prefix operator: else the
 * operator is an atom, as in X = -) *)
let begins_term (r : t) : bool =
  match r.tok with
  | Tint _ | Tvar _ | Tstring _ | Tquoted _ -> true
  | Tpunct c -> c = '(' || c = '[' || c = '{'
  | Tatom name -> r.call || Hashtbl.mem r.ops.prefix name || not (Hashtbl.mem r.ops.infix name)
  | Tend | Teof -> false

(* a term of a priority of [max] at most; the priority it has *)
let rec parse (r : t) (max : int) : Prolog.term * int =
  let left, priority = primary r max in
  operators r max left priority

and primary (r : t) (max : int) : Prolog.term * int =
  match r.tok with
  | Tint n -> advance r; (Prolog.Int n, 0)
  | Tvar name -> advance r; (variable r name, 0)
  | Tstring s -> advance r; (Prolog.of_string s, 0)
  | Tquoted name -> named r max name false
  | Tatom name -> named r max name true
  | Tpunct '(' ->
      advance r;
      let t, _ = parse r 1200 in
      expect r ')';
      (t, 0)
  | Tpunct '[' -> (
      advance r;
      match r.tok with
      | Tpunct ']' -> named r max "[]" false
      | _ ->
          let items = arguments r in
          let tail : Prolog.term =
            match r.tok with
            | Tpunct '|' ->
                advance r;
                fst (parse r 999)
            | _ -> Prolog.nil in
          expect r ']';
          (List.fold_right Prolog.cons items tail, 0))
  | Tpunct '{' -> (
      advance r;
      match r.tok with
      | Tpunct '}' -> named r max "{}" false
      | _ ->
          let t, _ = parse r 1200 in
          expect r '}';
          (Prolog.Struct ("{}", [ t ]), 0))
  | tok -> raise (Error (Printf.sprintf "a term is expected, not %s" (said tok), r.at))

(* an atom met (the token is still it): alone, a functor with its
 * arguments, a sign before a number, or a prefix operator and its
 * argument *)
and named (r : t) (max : int) (name : string) (plain : bool) : Prolog.term * int =
  let call = r.call in
  advance r;
  if call then begin
    advance r;
    let args = arguments r in
    expect r ')';
    (Prolog.Struct (name, args), 0)
  end
  else
    match r.tok with
    | Tint n when plain && (name = "-" || name = "+") && not r.space ->
        advance r;
        (Prolog.Int (if name = "-" then -n else n), 0)
    | _ -> (
        match if plain then Hashtbl.find_opt r.ops.prefix name else None with
        | Some (p, fixity) when begins_term r ->
            (* (an operator too strong for its place, as f(:- a): read
             * as an argument is) *)
            let p = if p > max then 999 else p in
            let arg, _ = parse r (if fixity = Prolog.Fy then p else p - 1) in
            (Prolog.Struct (name, [ arg ]), p)
        | _ -> (Prolog.Atom name, 0))

(* terms between commas *)
and arguments (r : t) : Prolog.term list =
  let first, _ = parse r 999 in
  match r.tok with
  | Tpunct ',' ->
      advance r;
      first :: arguments r
  | _ -> [ first ]

(* the infix operators after a term of a priority *)
and operators (r : t) (max : int) (left : Prolog.term) (priority : int) : Prolog.term * int =
  let name : string option =
    match r.tok with
    | Tatom name -> Some name
    | Tpunct ',' -> Some ","
    | Tpunct '|' -> Some "|"
    | _ -> None in
  match name with
  | None -> (left, priority)
  | Some name -> (
      match Hashtbl.find_opt r.ops.infix name with
      | Some (p, fixity) when p <= max && priority <= (if fixity = Prolog.Yfx then p else p - 1) ->
          advance r;
          let right, _ = parse r (if fixity = Prolog.Xfy then p else p - 1) in
          (* (a bar between goals is the semicolon) *)
          operators r max (Prolog.Struct ((if name = "|" then ";" else name), [ left; right ])) p
      | _ -> (left, priority))

let next (r : t) : (Prolog.term * (string * Prolog.term) list) option =
  r.vars <- [];
  (* (not the last clause's end: skip, after a mistake, stops at one) *)
  r.tok <- Teof;
  r.at <- r.pos;
  advance r;
  match r.tok with
  | Teof -> None
  | _ -> (
      let t, _ = parse r 1200 in
      match r.tok with
      | Tend -> Some (t, List.rev r.vars)
      | tok -> raise (Error (Printf.sprintf "an operator or the clause's end is expected, not %s" (said tok), r.at)))

let skip (r : t) : unit =
  (* (the mistake may be the clause's end itself: nothing to pass) *)
  let stop = ref (match r.tok with Tend -> true | _ -> r.pos >= String.length r.text) in
  while not !stop do
    match advance r with
    | () -> ( match r.tok with Tend | Teof -> stop := true | _ -> ())
    | exception Error _ -> r.pos <- r.pos + 1
  done

let complete (text : string) : bool =
  let r = make (Prolog.default_ops ()) text in
  let last : token ref = ref Tend in
  (try
     advance r;
     while r.tok <> Teof do
       last := r.tok;
       advance r
     done
   with Error (msg, _) ->
     (* (a quote or a comment still open: the text goes on; any other
      * mistake is whole, and is said when the text is read) *)
     let open_still : bool =
       let k = String.length msg in
       k >= 10 && String.sub msg (k - 10) 10 = "not closed" in
     last := if open_still then Teof else Tend);
  !last = Tend

let term (ops : Prolog.ops) (text : string) : Prolog.term * (string * Prolog.term) list =
  let r = make ops (text ^ " .") in
  match next r with
  | Some x -> x
  | None -> raise (Error ("a term is expected", 0))
