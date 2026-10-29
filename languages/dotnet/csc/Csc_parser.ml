(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Csc_parser.mli *)

open Csc_ast
module L = Csc_lexer

exception Error of string * int

(* the tokens, each with its line, and where the parser is *)
type p = { toks : (L.token * int) array; mutable i : int }

let peek (p : p) : L.token = fst p.toks.(p.i)
let peek2 (p : p) (k : int) : L.token =
  if p.i + k < Array.length p.toks then fst p.toks.(p.i + k) else L.EOF
let line (p : p) : int = snd p.toks.(p.i)
let advance (p : p) : unit = if p.i < Array.length p.toks - 1 then p.i <- p.i + 1

let show (t : L.token) : string =
  match t with
  | L.ID s -> s | L.KW s -> s | L.OP s -> s
  | L.INT n -> Int32.to_string n | L.LONG n -> Int64.to_string n
  | L.DOUBLE f -> string_of_float f | L.STRING s -> Printf.sprintf "%S" s
  | L.CHAR c -> Printf.sprintf "'%c'" (Char.chr c) | L.EOF -> "the end"

let fail (p : p) (what : string) =
  raise (Error (Printf.sprintf "%s expected, not %s" what (show (peek p)), line p))

let is (p : p) (t : L.token) : bool = peek p = t
let op (p : p) (s : string) : bool = peek p = L.OP s
let kw (p : p) (s : string) : bool = peek p = L.KW s
let expect (p : p) (t : L.token) : unit = if is p t then advance p else fail p (show t)
let expect_op (p : p) (s : string) : unit = expect p (L.OP s)
let accept (p : p) (t : L.token) : bool = if is p t then (advance p; true) else false

let ident (p : p) : string =
  match peek p with
  | L.ID s -> advance p; s
  | L.KW "get" -> advance p; "get"
  | _ -> fail p "a name"

let predefined = [ "int"; "bool"; "string"; "char"; "void"; "object"; "long"; "double" ]

(* ------------------------------------------------------------------ *)
(* Types *)
(* ------------------------------------------------------------------ *)

let rec ty (p : p) : ty =
  let base =
    match peek p with
    | L.KW k when List.mem k predefined -> advance p; Named ([ k ], [])
    | L.ID _ ->
        let rec names acc =
          let n = ident p in
          if op p "." && (match peek2 p 1 with L.ID _ -> true | _ -> false) then (advance p; names (n :: acc))
          else List.rev (n :: acc) in
        let ns = names [] in
        let args =
          if op p "<" then begin
            advance p;
            let rec go acc =
              let t = ty p in
              if accept p (L.OP ",") then go (t :: acc) else (expect_op p ">"; List.rev (t :: acc)) in
            go []
          end else [] in
        Named (ns, args)
    | _ -> fail p "a type" in
  let rec arrays t =
    if op p "[" && peek2 p 1 = L.OP "]" then (advance p; advance p; arrays (Array t)) else t in
  arrays base

(* is a type there, and what is after it? (a declaration, a cast) *)
let try_type (p : p) : ty option =
  let save = p.i in
  match ty p with
  | t -> Some t
  | exception Error _ -> p.i <- save; None

(* ------------------------------------------------------------------ *)
(* Expressions, by C#'s precedences *)
(* ------------------------------------------------------------------ *)

let mk (p : p) (e : desc) : expr = { e; pos = line p }

(* the binary operators, from the loosest *)
let levels = [ [ "||" ]; [ "&&" ]; [ "=="; "!=" ]; [ "<"; ">"; "<="; ">=" ]; [ "+"; "-" ]; [ "*"; "/"; "%" ] ]

let rec expr (p : p) : expr =
  let l = cond p in
  match peek p with
  | L.OP ("=" | "+=" | "-=" | "*=" | "/=" | "%=" as o) ->
      advance p;
      let r = expr p in
      { e = Assign (o, l, r); pos = l.pos }
  | _ -> l

and cond (p : p) : expr =
  let c = binary p 0 in
  if op p "?" then begin
    advance p;
    let a = expr p in
    expect_op p ":";
    let b = expr p in
    { e = Cond (c, a, b); pos = c.pos }
  end else c

and binary (p : p) (level : int) : expr =
  if level >= List.length levels then unary p
  else begin
    let ops = List.nth levels level in
    let rec go (l : expr) =
      match peek p with
      | L.OP o when List.mem o ops ->
          advance p;
          let r = binary p (level + 1) in
          go { e = Binary (o, l, r); pos = l.pos }
      | L.KW "is" when level = 3 ->
          advance p;
          let t = ty p in
          go { e = Is (l, t); pos = l.pos }
      | _ -> l in
    go (binary p (level + 1))
  end

and unary (p : p) : expr =
  match peek p with
  | L.OP ("-" | "!" as o) -> advance p; let e = unary p in mk p (Unary (o, e))
  | L.OP ("++" | "--" as o) -> advance p; let e = unary p in mk p (Incr (o = "++", true, e))
  | L.OP "(" when is_cast p ->
      advance p;
      let t = ty p in
      expect_op p ")";
      let e = unary p in
      mk p (Cast (t, e))
  | _ -> postfix p (primary p)

(* ( type ) followed by what starts an operand: a cast (C#'s rule,
 * 7.7.6: a predefined type is always one) *)
and is_cast (p : p) : bool =
  let save = p.i in
  advance p;
  let r = match try_type p with
    | Some (Named ([ k ], [])) when List.mem k predefined && op p ")" -> true
    | Some _ when op p ")" ->
        advance p;
        (match peek p with
         | L.ID _ | L.INT _ | L.LONG _ | L.DOUBLE _ | L.STRING _ | L.CHAR _ -> true
         | L.KW ("this" | "new" | "true" | "false" | "null" | "base") -> true
         | L.OP ("(" | "!") -> true
         | _ -> false)
    | _ -> false in
  p.i <- save;
  r

and args (p : p) : expr list =
  expect_op p "(";
  if accept p (L.OP ")") then []
  else
    let rec go acc =
      let e = if kw p "out" || kw p "ref" then (advance p; let x = expr p in { e = Out x; pos = x.pos })
        else expr p in
      if accept p (L.OP ",") then go (e :: acc) else (expect_op p ")"; List.rev (e :: acc)) in
    go []

and postfix (p : p) (e : expr) : expr =
  match peek p with
  | L.OP "." -> advance p; let n = ident p in postfix p { e = Member (e, n); pos = e.pos }
  | L.OP "(" -> let a = args p in postfix p { e = Call (e, a); pos = e.pos }
  | L.OP "[" ->
      advance p;
      let i = expr p in
      expect_op p "]";
      postfix p { e = Index (e, i); pos = e.pos }
  | L.OP ("++" | "--" as o) -> advance p; postfix p { e = Incr (o = "++", false, e); pos = e.pos }
  | _ -> e

and elements (p : p) : expr list =
  expect_op p "{";
  if accept p (L.OP "}") then []
  else
    let rec go acc =
      let e = expr p in
      if accept p (L.OP ",") then
        (if op p "}" then (advance p; List.rev (e :: acc)) else go (e :: acc))
      else (expect_op p "}"; List.rev (e :: acc)) in
    go []

and primary (p : p) : expr =
  match peek p with
  | L.INT n -> advance p; mk p (Int n)
  | L.LONG n -> advance p; mk p (Long n)
  | L.DOUBLE f -> advance p; mk p (Double f)
  | L.STRING s -> advance p; mk p (Str s)
  | L.CHAR c -> advance p; mk p (Char c)
  | L.KW "true" -> advance p; mk p (Bool true)
  | L.KW "false" -> advance p; mk p (Bool false)
  | L.KW "null" -> advance p; mk p Null
  | L.KW "this" -> advance p; mk p This
  | L.KW "base" -> advance p; mk p Base
  | L.ID n -> advance p; mk p (Name n)
  | L.KW k when List.mem k predefined -> advance p; mk p (Typed_name (Named ([ k ], [])))
  | L.OP "(" -> advance p; let e = expr p in expect_op p ")"; e
  | L.KW "new" ->
      advance p;
      let pos = line p in
      (* new T(args), new T[n], new T[] { ... } *)
      let save = p.i in
      let elem = ty p in
      (match elem with
       | Array t when op p "{" -> { e = Array_init (t, elements p); pos }
       | _ ->
           if op p "[" then begin
             p.i <- save;
             (* (the element's type, then [n]) *)
             let base = match peek p with
               | L.KW k when List.mem k predefined -> advance p; Named ([ k ], [])
               | _ -> (match ty p with Array t -> t | t -> t) in
             expect_op p "[";
             let n = expr p in
             expect_op p "]";
             { e = New_array (base, n); pos }
           end else { e = New (elem, args p); pos })
  | _ -> fail p "an expression"

(* ------------------------------------------------------------------ *)
(* Statements *)
(* ------------------------------------------------------------------ *)

let rec stmt (p : p) : stmt =
  let spos = line p in
  let mk s = { s; spos } in
  match peek p with
  | L.OP "{" -> mk (Block (block p))
  | L.OP ";" -> advance p; mk Empty
  | L.KW "if" ->
      advance p; expect_op p "(";
      let c = expr p in
      expect_op p ")";
      let t = stmt p in
      let e = if accept p (L.KW "else") then Some (stmt p) else None in
      mk (If (c, t, e))
  | L.KW "while" ->
      advance p; expect_op p "(";
      let c = expr p in
      expect_op p ")";
      mk (While (c, stmt p))
  | L.KW "do" ->
      advance p;
      let b = stmt p in
      expect p (L.KW "while"); expect_op p "(";
      let c = expr p in
      expect_op p ")"; expect_op p ";";
      mk (Do (b, c))
  | L.KW "for" ->
      advance p; expect_op p "(";
      let init = if op p ";" then [] else [ simple p ] in
      expect_op p ";";
      let c = if op p ";" then None else Some (expr p) in
      expect_op p ";";
      let rec steps acc =
        if op p ")" then List.rev acc
        else let e = expr p in
          if accept p (L.OP ",") then steps (e :: acc) else List.rev (e :: acc) in
      let step = steps [] in
      expect_op p ")";
      mk (For (init, c, step, stmt p))
  | L.KW "foreach" ->
      advance p; expect_op p "(";
      let t = ty p in
      let n = ident p in
      expect p (L.KW "in");
      let e = expr p in
      expect_op p ")";
      mk (Foreach (t, n, e, stmt p))
  | L.KW "return" ->
      advance p;
      let e = if op p ";" then None else Some (expr p) in
      expect_op p ";"; mk (Return e)
  | L.KW "break" -> advance p; expect_op p ";"; mk Break
  | L.KW "continue" -> advance p; expect_op p ";"; mk Continue
  | L.KW "throw" ->
      advance p;
      let e = if op p ";" then None else Some (expr p) in
      expect_op p ";"; mk (Throw e)
  | L.KW "try" ->
      advance p;
      let body = mk (Block (block p)) in
      let rec catches acc =
        if accept p (L.KW "catch") then begin
          let t, n =
            if accept p (L.OP "(") then begin
              let t = ty p in
              let n = match peek p with L.ID n -> advance p; Some n | _ -> None in
              expect_op p ")"; (t, n)
            end else (Named ([ "System"; "Exception" ], []), None) in
          let b = { s = Block (block p); spos = line p } in
          catches ((t, n, b) :: acc)
        end else List.rev acc in
      let cs = catches [] in
      let fin = if accept p (L.KW "finally") then Some { s = Block (block p); spos = line p } else None in
      mk (Try (body, cs, fin))
  | _ -> let s = simple p in expect_op p ";"; s

(* a declaration of locals, or an expression *)
and simple (p : p) : stmt =
  let spos = line p in
  let save = p.i in
  let decl =
    match try_type p with
    | Some t -> (match peek p with
        | L.ID _ when (match peek2 p 1 with L.OP ("=" | ";" | ",") -> true | L.KW "in" -> false | _ -> false) -> Some t
        | _ -> None)
    | None -> None in
  match decl with
  | Some t ->
      let rec vars acc =
        let n = ident p in
        let init =
          if accept p (L.OP "=") then
            Some (if op p "{" then { e = Array_init ((match t with Array e -> e | t -> t), elements p); pos = spos }
                  else expr p)
          else None in
        if accept p (L.OP ",") then vars ((n, init) :: acc) else List.rev ((n, init) :: acc) in
      { s = Local (t, vars []); spos }
  | None -> p.i <- save; { s = Expr (expr p); spos }

and block (p : p) : stmt list =
  expect_op p "{";
  let rec go acc = if accept p (L.OP "}") then List.rev acc else go (stmt p :: acc) in
  go []

(* ------------------------------------------------------------------ *)
(* Classes *)
(* ------------------------------------------------------------------ *)

let modifier (t : L.token) : modifier option =
  match t with
  | L.KW "public" -> Some Public | L.KW "private" -> Some Private
  | L.KW "protected" -> Some Protected | L.KW "internal" -> Some Internal
  | L.KW "static" -> Some Static | L.KW "abstract" -> Some Abstract
  | L.KW "virtual" -> Some Virtual | L.KW "override" -> Some Override
  | L.KW "sealed" -> Some Sealed | L.KW "new" -> Some New
  | L.KW "readonly" -> Some Readonly
  | _ -> None

let modifiers (p : p) : modifier list =
  let rec go acc = match modifier (peek p) with
    | Some m -> advance p; go (m :: acc)
    | None -> List.rev acc in
  go []

let params (p : p) : (ty * string) list =
  expect_op p "(";
  if accept p (L.OP ")") then []
  else
    let rec go acc =
      let byref = kw p "out" || kw p "ref" in
      if byref then advance p;
      let t = ty p in
      let t = if byref then Byref t else t in
      let n = ident p in
      if accept p (L.OP ",") then go ((t, n) :: acc) else (expect_op p ")"; List.rev ((t, n) :: acc)) in
    go []

let member (p : p) (cls : string) : member =
  let pos = line p in
  let mods = modifiers p in
  match peek p, peek2 p 1 with
  | L.ID n, L.OP "(" when n = cls ->
      advance p;
      let ps = params p in
      let init =
        if accept p (L.OP ":") then
          let base = if accept p (L.KW "base") then true else (expect p (L.KW "this"); false) in
          Some (base, args p)
        else None in
      Ctor (mods, n, ps, init, { s = Block (block p); spos = line p }, pos)
  | _ ->
      let t = ty p in
      let n = ident p in
      if op p "(" then begin
        let ps = params p in
        let body = if accept p (L.OP ";") then None else Some { s = Block (block p); spos = line p } in
        Method (mods, t, n, ps, body, pos)
      end else if op p "{" then begin
        (* a property: its getter alone *)
        advance p;
        expect p (L.KW "get");
        let body = if accept p (L.OP ";") then None else Some { s = Block (block p); spos = line p } in
        expect_op p "}";
        Property (mods, t, n, body, pos)
      end else begin
        let rec vars acc name =
          let init = if accept p (L.OP "=") then
              Some (if op p "{" then { e = Array_init ((match t with Array e -> e | t -> t), elements p); pos }
                    else expr p)
            else None in
          if accept p (L.OP ",") then vars ((name, init) :: acc) (ident p)
          else (expect_op p ";"; List.rev ((name, init) :: acc)) in
        Field (mods, t, vars [] n, pos)
      end

let class_decl (p : p) : class_decl =
  let cpos = line p in
  let cmods = modifiers p in
  let interface = if accept p (L.KW "interface") then true else (expect p (L.KW "class"); false) in
  let cname = ident p in
  let bases =
    if accept p (L.OP ":") then
      let rec go acc = let t = ty p in if accept p (L.OP ",") then go (t :: acc) else List.rev (t :: acc) in
      go []
    else [] in
  expect_op p "{";
  let rec members acc = if accept p (L.OP "}") then List.rev acc else members (member p cname :: acc) in
  { cname; interface; cmods; bases; members = members []; cpos }

let program (text : string) : program =
  L.line := 1;
  let lexbuf = Lexing.from_string text in
  let rec toks acc =
    let t = L.token lexbuf in
    let acc = (t, !L.line) :: acc in
    if t = L.EOF then Array.of_list (List.rev acc) else toks acc in
  let p = { toks = toks []; i = 0 } in
  let rec usings acc =
    if accept p (L.KW "using") then begin
      let rec names acc = let n = ident p in if accept p (L.OP ".") then names (n :: acc) else List.rev (n :: acc) in
      let ns = names [] in
      expect_op p ";";
      usings (ns :: acc)
    end else List.rev acc in
  let us = usings [] in
  let rec classes acc = if is p L.EOF then List.rev acc else classes (class_decl p :: acc) in
  { usings = us; classes = classes [] }
