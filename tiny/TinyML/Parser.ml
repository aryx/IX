(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Parser.mli *)

(*****************************************************************************)
(* The parser *)
(*****************************************************************************)

let toks : (Lexer.token * int) array ref = ref (Array.of_list []) and pos =
  ref 0
let peek () = fst (!toks).(!pos)
let peek_at k = fst (!toks).(min (!pos + k) (Array.length !toks - 1))
let line () = snd (!toks).(!pos)
let advance () = if peek () <> Lexer.EOF then incr pos
let accept t = if peek () = t then (advance (); true) else false
let show_tok = function
  | Lexer.INT n -> string_of_int n | Lexer.CHAR _ -> "a character"
    | Lexer.STR _ -> "a string"
  | Lexer.LID x -> x | Lexer.UID x -> x | Lexer.KW x -> x
    | Lexer.EOF -> "the end"
let fail () =
  Lexer.error
    (Printf.sprintf "line %d: syntax error at %s" (line ())
      (show_tok (peek ())))
let expect t = if not (accept t) then fail ()
let fresh = ref 0

(* the names of types declared as an object's: read and forgotten (ty) *)
let forgotten : string list ref = ref []

(* the abbreviations, Tree's (of_texpr reads them too) *)
let abbreviations = Tree.abbreviations

(* the abbreviation that a name with these arguments is *)
let abbreviation c ts =
  match
    List.find_opt
      (fun (c', (ps, _)) -> c' = c && List.length ps = List.length ts)
      !abbreviations
  with
  | Some (_, (ps, te)) -> Some (Tree.of_texpr (ref (List.combine ps ts)) te)
  | None -> None

(* the operators, OCaml's rules: a prefix one starts with !, ~ or ?; an
 * infix one's precedence and right associativity are its first
 * character's, but for the words and those listed ("," is 1). So a
 * program defines its own, let ( // ) = ..., with no table to extend
 * (old: a table of the standard library's, |> and ||| added to it) *)
let is_prefix o =
  o <> "" && o <> "!="
  && (o.[0] = '!' || (String.length o > 1 && (o.[0] = '~' || o.[0] = '?')))
let binop o =
  match o with
  | ":=" | "<-" -> Some (0, true)
  | "||" | "or" -> Some (2, true)
  | "&&" | "&" -> Some (3, true)
  | "::" -> Some (6, true)
  | "mod" | "land" | "lor" | "lxor" -> Some (8, false)
  | "lsl" | "lsr" | "asr" -> Some (9, true)
  | "->" | "|" -> None
  | _ when o = "" || is_prefix o -> None
  | _ when String.length o > 1 && o.[0] = '*' && o.[1] = '*' -> Some (9, true)
  | _ ->
      (match o.[0] with
       | '*' | '/' | '%' -> Some (8, false)
       | '+' | '-' -> Some (7, false)
       | '@' | '^' -> Some (5, true)
       | '=' | '<' | '>' | '|' | '&' | '$' | '!' -> Some (4, false)
       | _ -> None)

let is_op o = binop o <> None || is_prefix o

(* C (a, b) is a constructor of two arguments, the tuple its parser saw *)
let con_args c args untuple =
  let ci = Tree.find_con c in
  match args with
  | [] when ci.arity = 0 -> []
  | [ a ] when ci.arity = 1 -> [ a ]
  | [ a ] when ci.arity > 1 ->
      (match untuple ci.arity a with
       | Some l when List.length l = ci.arity -> l
       | _ ->
           Lexer.error
             (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c
                ci.arity))
  | _ ->
      Lexer.error
        (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c ci.arity)

let starts_atom = function
  | Lexer.INT _ | Lexer.CHAR _ | Lexer.STR _ | Lexer.LID _ | Lexer.UID _
  | Lexer.KW ("(" | "[" | "{" | "begin") -> true
  | Lexer.KW o -> is_prefix o
  | _ -> false
let starts_patom = function
  | Lexer.INT _ | Lexer.CHAR _ | Lexer.STR _ | Lexer.LID _ | Lexer.UID _
    | Lexer.KW ("_" | "(" | "[" | "{") -> true
  | _ -> false

(* expressions: a sequence, then let/match/fun/if, then the operators
 * by precedence climbing, then application *)
let rec expr () =
  let e = stmt () in
  if accept (Lexer.KW ";") then
    match peek () with
    | Lexer.KW ("end" | ")" | "done" | "in" | ";;" | "|" | "]" | "with" | "else"
         | "then")
    | Lexer.EOF -> e
    | _ -> Tree.Seq (e, expr ())
  else e

and stmt () =
  match peek () with
  | Lexer.KW "let" ->
      advance ();
      let r = if accept (Lexer.KW "rec") then Tree.Recursive else
        Tree.Nonrecursive in
      let bs = bindings () in
      expect (Lexer.KW "in");
      Tree.Let (r, bs, expr ())
  | Lexer.KW "match" ->
      advance (); let e = expr () in expect (Lexer.KW "with");
      Tree.Match (e, cases ())
  | Lexer.KW "try" ->
      advance (); let e = expr () in expect (Lexer.KW "with");
      Tree.Try (e, cases ())
  | Lexer.KW "function" -> advance ();
  Tree.Fun ([ "%f" ], Tree.Match (Tree.var "%f", cases ()))
  | Lexer.KW "fun" ->
      advance (); let ps = params () in expect (Lexer.KW "->");
      fun_of ps (expr ())
  | Lexer.KW "if" ->
      advance ();
      let c = expr () in
      expect (Lexer.KW "then");
      let a = stmt () in
      Tree.If (c, a,
        if accept (Lexer.KW "else") then stmt () else Tree.Con ("()", []))
  | Lexer.KW "while" ->
      advance ();
      let c = expr () in
      expect (Lexer.KW "do");
      let b = expr () in
      expect (Lexer.KW "done");
      Tree.While (c, b)
  | Lexer.KW "for" ->
      advance ();
      let x = match peek () with Lexer.LID x -> advance (); x | _ -> fail () in
      expect (Lexer.KW "=");
      let a = expr () in
      let up =
        if accept (Lexer.KW "to") then true else
          (expect (Lexer.KW "downto"); false) in
      let b = expr () in
      expect (Lexer.KW "do");
      let body = expr () in
      expect (Lexer.KW "done");
      Tree.For (x, a, b, up, body)
  | _ -> binary 0

and binary min =
  let rec loop lhs =
    match peek () with
    | Lexer.KW "," when min <= 1 ->
        let rec more () =
          advance ();
          let e = binary 2 in
          if peek () = Lexer.KW "," then e :: more () else [ e ]
        in
        loop (Tree.Tuple (lhs :: more ()))
    | Lexer.KW op -> (
        match binop op with
        | Some (p, right) when p >= min ->
            advance ();
            let rhs = binary (if right then p else p + 1) in
            loop
              (match op with
               | "::" -> Tree.Con ("::", [ lhs; rhs ])
               | "&&" | "&" -> Tree.If (lhs, rhs, Tree.Con ("false", []))
               | "||" | "or" -> Tree.If (lhs, Tree.Con ("true", []), rhs)
               | "<-" -> (
                   match lhs with
                   | Tree.Dot (e, l, i) -> Tree.SetDot (e, l, i, rhs)
                   | Tree.App (Tree.Var ("Array.get", _), [ a; i ]) ->
                       (* i, a, then the value, ocamlopt's order *)
                       incr fresh;
                       let a' = Printf.sprintf "%%a%d" !fresh
                       and i' = Printf.sprintf "%%i%d" !fresh in
                       Tree.Let (Tree.Nonrecursive, [ Tree.PVar i', i ],
                         Tree.Let (Tree.Nonrecursive, [ Tree.PVar a', a ],
                           Tree.App (Tree.var "Array.set",
                             [ Tree.var a'; Tree.var i'; rhs ])))
                   | _ ->
                       Lexer.error
                         (Printf.sprintf
                            "line %d: <- on a field or an array's element only"
                            (line ())))
               | _ -> Tree.App (Tree.var op, [ lhs; rhs ]))
        | _ -> lhs)
    | _ -> lhs
  in
  loop (unary ())

and unary () =
  match peek () with
  | Lexer.KW "-" ->
      advance ();
      (match peek () with
       | Lexer.INT n -> advance (); Tree.Const (Tree.CInt (-n))
       | _ -> Tree.App (Tree.var "~-", [ unary () ]))
  | _ -> app ()

and app () =
  match peek () with
  | Lexer.UID c when starts_atom (peek_at 1) && (Tree.find_con c).arity > 0 ->
      advance ();
      let a = atom () in
      Tree.Con (Tree.resolve_con c,
        con_args c [ a ] (fun _ -> function Tree.Tuple l -> Some l | _ -> None))
  | _ -> (
      let f = atom () in
      let rec args () =
        if starts_atom (peek ()) then let a = atom () in a :: args () else [] in
      match f, args () with
      | _, [] -> f
      | Tree.Var (p, _), l
        when p = "Printf.sprintf" || p = "Printf.ksprintf"
             || p = "Printf.bprintf" ->
          Formats.printf_call p l
      (* Logs.debug (fun m -> m "%s" x): m given the message made, as
       * Printf.sprintf makes it (TinyLibCore's Logs.mli) *)
      | Tree.Var (p, _),
        [ Tree.Fun
          ([ m ], Tree.App
            (Tree.Var (m', _), (Tree.Const (Tree.CStr _) :: _ as l))) ]
        when String.length p > 5 && String.sub p 0 5 = "Logs." && m = m' ->
          let msg = Formats.printf_call "Printf.sprintf" l in
          Tree.App (f, [ Tree.Fun ([ m ], Tree.App (Tree.var m, [ msg ])) ])
      | _, l -> Tree.App (f, l))

and atom () = postfix (simple ())

(* an atom without its postfix (.l, .(i), .[i]): a prefix operator's
 * operand, as OCaml's, whose !r.l is (!r).l (old: !(r.l)) *)
and simple () =
  match peek () with
  | Lexer.INT n -> advance (); Tree.Const (Tree.CInt n)
  | Lexer.CHAR c -> advance (); Tree.Const (Tree.CChar c)
  | Lexer.STR s -> advance (); Tree.Const (Tree.CStr s)
  | Lexer.LID x -> advance (); Tree.var x
  (* M.( op ): M's operator, a value named M.op (old: M a constructor) *)
  | Lexer.UID m
    when peek_at 1 = Lexer.KW "." && peek_at 2 = Lexer.KW "("
         && peek_at 4 = Lexer.KW ")"
         && (match peek_at 3 with Lexer.KW o -> is_op o | _ -> false) ->
      let o = match peek_at 3 with Lexer.KW o -> o | _ -> fail () in
      advance (); advance (); advance (); advance (); advance ();
      Tree.var (m ^ "." ^ o)
  | Lexer.UID c ->
      advance (); Tree.Con (Tree.resolve_con c, con_args c [] (fun _ _ -> None))
  | Lexer.KW o when is_prefix o ->
      advance ();
      Tree.App (Tree.var o, [ simple () ])
  | Lexer.KW "(" -> (
      advance ();
      if accept (Lexer.KW ")") then Tree.Con ("()", [])
      else
        match peek (), peek_at 1 with
        | Lexer.KW op, Lexer.KW ")" when is_op op -> advance (); advance ();
        Tree.var op
        | _ ->
            let e = expr () in
            if accept (Lexer.KW ":") || accept (Lexer.KW ":>") then
              ignore (ty ());
            expect (Lexer.KW ")");
            e)
  | Lexer.KW "begin" ->
      advance ();
      if accept (Lexer.KW "end") then Tree.Con ("()", [])
      else (let e = expr () in expect (Lexer.KW "end"); e)
  | Lexer.KW "[" ->
      advance ();
      let rec elems () =
        if accept (Lexer.KW "]") then Tree.Con ("[]", [])
        else (
          let e = stmt () in
          ignore (accept (Lexer.KW ";"));
          Tree.Con ("::", [ e; elems () ]))
      in
      elems ()
  | Lexer.KW "{" ->
      advance ();
      let rec fields () =
        if accept (Lexer.KW "}") then []
        else match peek () with
          (* { text; pos = 0 }: a field alone is the variable of its name *)
          | Lexer.LID l ->
              advance ();
              let e = if accept (Lexer.KW "=") then stmt () else Tree.var l in
              ignore (accept (Lexer.KW ";"));
              (l, e) :: fields ()
          | _ -> fail () in
      (* a label followed by =, ; or } begins the fields; anything else
       * is the record that { e with ... } copies *)
      (match peek (), peek_at 1 with
       | Lexer.LID _,
         Lexer.KW ("=" | ";" | "}") -> Tree.Record (fields (), ref [])
       | _ ->
           let e = atom () in
           expect (Lexer.KW "with");
           (match fields () with
            | [] -> fail ()
            | fs -> Tree.With (e, fs, ref [], ref 0)))
  | Lexer.KW
    ("let" | "match" | "try" | "fun" | "function" | "if" | "while" | "for")
    ->
      stmt ()
  | _ -> fail ()

and postfix e =
  if accept (Lexer.KW ".[") then (
    let i = expr () in
    expect (Lexer.KW "]");
    postfix (Tree.App (Tree.var "String.get", [ e; i ])))
  else if peek () = Lexer.KW "." then (
    advance ();
    match peek () with
    | Lexer.LID l -> advance (); postfix (Tree.Dot (e, l, ref 0))
    | Lexer.KW "(" ->
        advance ();
        let i = expr () in
        expect (Lexer.KW ")");
        postfix (Tree.App (Tree.var "Array.get", [ e; i ]))
    | _ -> fail ())
  else e

and cases () =
  ignore (accept (Lexer.KW "|"));
  let p = pattern () in
  let g = if accept (Lexer.KW "when") then Some (expr ()) else None in
  expect (Lexer.KW "->");
  let e = expr () in
  (p, g, e) :: (if peek () = Lexer.KW "|" then cases () else [])

(* patterns: as, then |, then the tuple, then ::, then a constructor's *)
and pattern () =
  let p = por () in
  if accept (Lexer.KW "as") then
    (match peek () with Lexer.LID x -> advance (); Tree.PAlias (p, x)
      | _ -> fail ())
  else p

and por () = let p = ptuple () in if accept (Lexer.KW "|") then
  Tree.POr (p, por ()) else p

and ptuple () =
  let p = pcons () in
  if peek () = Lexer.KW "," then (
    let rec more () =
      if accept (Lexer.KW ",") then let q = pcons () in q :: more () else [] in
    Tree.PTuple (p :: more ()))
  else p

and pcons () =
  let p = papp () in
  if accept (Lexer.KW "::") then Tree.PCon ("::", [ p; pcons () ]) else p

and papp () =
  match peek () with
  | Lexer.UID c when starts_patom (peek_at 1) && (Tree.find_con c).arity > 0 ->
      advance ();
      let a = patom () in
      Tree.PCon (Tree.resolve_con c,
        con_args c [ a ] (fun n -> function
          | Tree.PTuple l -> Some l
          | Tree.PAny -> Some (List.init n (fun _ -> Tree.PAny))
          | _ -> None))
  | _ -> patom ()

and patom () =
  match peek () with
  | Lexer.LID x -> advance (); Tree.PVar x
  | Lexer.KW "_" -> advance (); Tree.PAny
  | Lexer.INT n -> advance (); Tree.PConst (Tree.CInt n)
  | Lexer.CHAR c -> advance (); Tree.PConst (Tree.CChar c)
  | Lexer.STR s -> advance (); Tree.PConst (Tree.CStr s)
  | Lexer.KW "-" ->
      advance ();
      (match peek () with Lexer.INT n -> advance ();
        Tree.PConst (Tree.CInt (-n)) | _ -> fail ())
  | Lexer.UID c ->
      advance (); Tree.PCon (Tree.resolve_con c, con_args c [] (fun _ _ -> None))
  | Lexer.KW "(" ->
      advance ();
      if accept (Lexer.KW ")") then Tree.PCon ("()", [])
      else (
        let p = pattern () in
        let p = if accept (Lexer.KW ":") then Tree.PAnnot (p, ty ()) else p in
        expect (Lexer.KW ")");
        p)
  | Lexer.KW "[" ->
      advance ();
      let rec elems () =
        if accept (Lexer.KW "]") then Tree.PCon ("[]", [])
        else (
          let p = pattern () in
          ignore (accept (Lexer.KW ";"));
          Tree.PCon ("::", [ p; elems () ]))
      in
      elems ()
  | Lexer.KW "{" ->
      advance ();
      (* { view; update = u; _ }: a field alone binds the variable of its
       * name, and _ allows the fields not named *)
      let rec fields () =
        if accept (Lexer.KW "}") then []
        else match peek () with
          | Lexer.LID l ->
              advance ();
              let p = if accept (Lexer.KW "=") then pattern () else
                Tree.PVar l in
              ignore (accept (Lexer.KW ";"));
              (l, p) :: fields ()
          | Lexer.KW "_" -> advance (); ignore (accept (Lexer.KW ";"));
          expect (Lexer.KW "}"); []
          | _ -> fail () in
      (match fields () with
       | [] -> fail ()
       | fs -> Tree.PRecord (fs, ref [], ref 0))
  | _ -> fail ()

and params () =
  if starts_patom (peek ()) then let p = patom () in p :: params () else []

(* fun p q -> e: a pattern other than a name is a let of the parameter *)
and fun_of ps body =
  let names, body =
    List.fold_right (fun p (names, body) ->
      match p with
      | Tree.PVar x -> x :: names, body
      | p ->
          incr fresh;
          let x = Printf.sprintf "%%p%d" !fresh in
          x :: names, Tree.Let (Tree.Nonrecursive, [ p, Tree.var x ], body))
      ps ([], body)
  in
  (* fun x -> function ...: one function of both, as OCaml makes it
   * (old: a closure made at each call of the first, List.length's
   * len n = function ..., an allocation an element: half of tiny-ml's
   * time on tiny-kernel) *)
  match body with
  | Tree.Fun (more, body)
    when List.length names + List.length more <= 10
         && not (List.exists (fun x -> List.mem x names) more) ->
      Tree.Fun (names @ more, body)
  | _ -> Tree.Fun (names, body)

and bindings () =
  let b = binding () in
  if accept (Lexer.KW "and") then b :: bindings () else [ b ]

and binding () =
  let name =
    match peek (), peek_at 1 with
    | Lexer.LID x,
      t when not
        (List.mem t
          [ Lexer.KW "="; Lexer.KW ","; Lexer.KW ":"; Lexer.KW "as";
            Lexer.KW "::" ])
      ->
        advance (); Some x
    | Lexer.KW "(", Lexer.KW op when is_op op && peek_at 2 = Lexer.KW ")" ->
        advance (); advance (); advance (); Some op
    | _ -> None
  in
  match name with
  | Some f ->
      let ps = params () in
      if accept (Lexer.KW ":") then ignore (ty ());
      expect (Lexer.KW "=");
      Tree.PVar f, (if ps = [] then expr () else fun_of ps (expr ()))
  | None ->
      let p = pattern () in
      let p = if accept (Lexer.KW ":") then Tree.PAnnot (p, ty ()) else p in
      expect (Lexer.KW "=");
      p, expr ()

(* types: ->, then *, then applications of names (int list). An
 * object's type, < Cap.fork; Cap.exec; .. >, is read and forgotten: any
 * type (ix's capabilities, which OCaml checks when it builds the same
 * file; here a program's caps are a value like another, and (e :> t)
 * is e); so is a name declared as one, type caps = < ... > *)
(* a label, prefix:string -> ... in an .mli, read and dropped: a call
 * gives the arguments in their order, without their labels, which
 * OCaml accepts of a whole application *)
and ty () =
  (match peek (), peek_at 1 with Lexer.LID _, Lexer.KW ":" -> advance ();
    advance () | _ -> ());
  let t = ty_tuple () in if accept (Lexer.KW "->") then
    Tree.TE ("->", [ t; ty () ]) else t

and ty_tuple () = match ty_args () with [ t ] -> t | l -> Tree.TE ("*", l)

and ty_args () =
  let t = ty_app () in
  if accept (Lexer.KW "*") then t :: ty_args () else [ t ]

and ty_app () =
  let args =
    match peek () with
    | Lexer.KW "'" ->
        advance ();
        (match peek () with Lexer.LID v -> advance (); [ Tree.TEVar v ]
          | _ -> fail ())
    | Lexer.KW "(" ->
        advance ();
        let rec go () =
          let t = ty () in
          if accept (Lexer.KW ",") then t :: go () else [ t ]
        in
        let l = go () in
        expect (Lexer.KW ")");
        l
    | Lexer.KW "<" -> skip_object (); [ any () ]
    | Lexer.LID c when List.mem c !forgotten -> advance (); [ any () ]
    | Lexer.LID c -> advance (); [ Tree.TE (Tree.resolve_type c, []) ]
    | _ -> fail ()
  in
  (* (val: OCaml's keyword, not tiny-ml's: an .mli's next item) *)
  let rec post args =
    match peek () with
    | Lexer.LID c when c <> "val" ->
        advance (); post [ Tree.TE (Tree.resolve_type c, args) ]
    | _ -> args
  in
  match post args with [ t ] -> t | _ -> fail ()

and any () = incr fresh; Tree.TEVar (Printf.sprintf "%%o%d" !fresh)

and skip_object () =
  advance ();
  while peek () <> Lexer.KW ">" do (if peek () = Lexer.EOF then fail ());
  advance () done;
  advance ()

(* type ('a, 'b) t = A | B of 'a * t and ...: the constructors
 * numbered, the constant ones and the others apart; or a record, type
 * t = { a : int; mutable b : t }, its labels numbered; or another
 * type's second name, type word = piece list (abbreviations) *)
let rec type_decl () =
  let tvar () =
    expect (Lexer.KW "'"); match peek () with Lexer.LID v -> advance (); v
      | _ -> fail () in
  let params =
    match peek () with
    | Lexer.KW "'" -> [ tvar () ]
    | Lexer.KW "(" ->
        advance ();
        let rec go () =
          let v = tvar () in
          if accept (Lexer.KW ",") then v :: go () else [ v ]
        in
        let l = go () in
        expect (Lexer.KW ")");
        l
    | _ -> []
  in
  let name = match peek () with Lexer.LID x -> advance (); x | _ -> fail () in
  expect (Lexer.KW "=");
  ignore (accept (Lexer.KW "|"));
  let vars = ref (List.map (fun v -> v, Tree.genvar ()) params) in
  (* (its name in scope already, from the file's start: parse's) *)
  Tree.declare_type name;
  let q = Tree.own name in
  let res = Tree.TCon (q, List.map snd !vars) in
  if peek () = Lexer.KW "<" then
    (skip_object (); forgotten := name :: !forgotten)
  else if accept (Lexer.KW "{") then begin
    let rec fields () =
      if accept (Lexer.KW "}") then []
      else
        let mut = accept (Lexer.LID "mutable") in
        let l = match peek () with Lexer.LID l -> advance (); l
          | _ -> fail () in
        expect (Lexer.KW ":");
        let t = Tree.of_texpr vars (ty ()) in
        ignore (accept (Lexer.KW ";"));
        (l, mut, t) :: fields () in
    let fs = fields () in
    let lnames = List.map (fun (l, _, _) -> l) fs in
    List.iteri (fun idx (l, mut, t) ->
      Tree.add_label l
        { lrec = q; idx; mut; lnames;
          lscheme = Tree.TCon ("%l", [ res; t ]) })
      fs
  end else if (match peek () with Lexer.UID _ -> false | _ -> true) then begin
    abbreviations := (q, (params, ty ())) :: !abbreviations
  end else begin
    let rec ctors () =
      let c =
        match peek () with
        | Lexer.UID c -> advance (); c
        | _ ->
            Lexer.error
              (Printf.sprintf "line %d: a constructor or a record expected"
                 (line ()))
      in
      let args =
        if accept (Lexer.KW "of") then
          List.map (Tree.of_texpr vars) (ty_args ()) else []
      in
      (c, args) :: (if accept (Lexer.KW "|") then ctors () else [])
    in
    let cs = ctors () in
    let nconst = List.length (List.filter (fun (_, a) -> a = []) cs) in
    let nblock = List.length cs - nconst in
    let ic = ref 0 and ib = ref 0 in
    List.iter (fun (c, args) ->
      let kind =
        if args = [] then (incr ic; Tree.KConst (!ic - 1))
        else (incr ib; Tree.KBlock (!ib - 1))
      in
      Tree.add_con c
        { kind; arity = List.length args; nconst; nblock;
          scheme = Tree.TCon ("%c", res :: args) })
      cs
  end;
  if accept (Lexer.KW "and") then type_decl ()

(* an external's or a val's name: x, or an operator ( op ) *)
let val_name () =
  match peek () with
  | Lexer.LID x -> advance (); x
  | Lexer.KW "(" ->
      advance ();
      let o = (match peek () with Lexer.KW o -> advance (); o | _ -> fail ()) in
      expect (Lexer.KW ")");
      o
  | _ -> fail ()

let rec items () : (Tree.item * int) list =
  let l = line () in
  match peek () with
  | Lexer.EOF | Lexer.KW "end" -> []
  | Lexer.KW ";;" -> advance (); items ()
  | Lexer.KW "let" ->
      advance ();
      let r = if accept (Lexer.KW "rec") then Tree.Recursive else
        Tree.Nonrecursive in
      let bs = bindings () in
      if accept (Lexer.KW "in") then (
        let e = Tree.Let (r, bs, expr ()) in
        (Tree.ILet (Tree.Nonrecursive, [ Tree.PAny, e ]), l) :: items ())
      else (Tree.ILet (r, bs), l) :: items ()
  | Lexer.KW "type" -> advance (); type_decl (); items ()
  (* module M = struct ... end, one level: its names M.x, for the units
   * after (open A.M); in it, a name is not found by its short name.
   * Or module A = M, a shorter name for a unit: A.x is M.x, in this
   * unit alone, and A.t M's type t *)
  | Lexer.KW "module" ->
      advance ();
      let m = match peek () with Lexer.UID m -> advance (); m | _ -> fail () in
      expect (Lexer.KW "=");
      (match peek () with
       | Lexer.UID u ->
           advance ();
           Tree.aliases := (m, u) :: !Tree.aliases;
           (Tree.IAlias (m, u), l) :: items ()
       | Lexer.KW "struct" ->
           advance ();
           let inner = items () in
           expect (Lexer.KW "end");
           let rec named p = match p with
             | Tree.PVar x -> Tree.PVar (m ^ "." ^ x)
             | Tree.PAnnot (p, t) -> Tree.PAnnot (named p, t)
             | _ -> fail () in
           List.map (fun (it, l) ->
               match it with
               | Tree.ILet (r, bs) ->
                 Tree.ILet (r, List.map (fun (p, e) -> named p, e) bs), l
               | Tree.IExt (x, t, p) -> Tree.IExt (m ^ "." ^ x, t, p), l
               | _ -> fail ()) inner
           @ items ()
       | _ -> fail ())
  | Lexer.KW "open" ->
      advance ();
      (match peek () with
       | Lexer.UID m ->
           advance (); Tree.open_unit m; (Tree.IOpen m, l) :: items ()
       | _ -> fail ())
  | Lexer.KW "exception" ->
      advance ();
      let c = match peek () with Lexer.UID c -> advance (); c | _ -> fail () in
      let args =
        if accept (Lexer.KW "of") then
          List.map (Tree.of_texpr (ref [])) (ty_args ())
        else []
      in
      Tree.add_con c
        { kind = Tree.KExn !Tree.unit_name; arity = List.length args;
          nconst = 0; nblock = 0;
          scheme = Tree.TCon ("%c", Tree.tcon "exn" :: args) };
      (Tree.IExn c, l) :: items ()
  | Lexer.KW "external" ->
      advance ();
      let x = val_name () in
      expect (Lexer.KW ":");
      let t = ty () in
      expect (Lexer.KW "=");
      let p = match peek () with Lexer.STR p -> advance (); p | _ -> fail () in
      (Tree.IExt (x, t, p), l) :: items ()
  | _ -> let e = expr () in (Tree.ILet (Tree.Nonrecursive, [ Tree.PAny, e ]), l)
    :: items ()

(* the types the file declares, their names in scope from its start, so
 * that a type is named above its declaration (type a = A of b and b =
 * ...): each name after type or a type's and, its parameters skipped *)
let declare_types () =
  let n = Array.length !toks in
  let tok k = if k < n then fst (!toks).(k) else Lexer.EOF in
  let rec name k =
    match tok k with
    | Lexer.KW "'" -> name (k + 2)
    | Lexer.KW "(" ->
        let rec close k = if k >= n || tok k = Lexer.KW ")" then k + 1
          else close (k + 1) in
        name (close k)
    | Lexer.LID x -> Tree.declare_type x
    | _ -> () in
  let rec go k in_type =
    if k < n then
      match tok k with
      | Lexer.KW "type" -> name (k + 1); go (k + 1) true
      | Lexer.KW "and" when in_type -> name (k + 1); go (k + 1) true
      | Lexer.KW ("let" | "exception" | "external" | "open" | "module") ->
          go (k + 1) false
      | _ -> go (k + 1) in_type in
  go 0 false

(* a file's text, its items, each with its line *)
let parse (text : string) =
  toks := Lexer.lex text; pos := 0;
  (* (a unit's aliases its own) *)
  Tree.aliases := [];
  declare_types ();
  let is = items () in
  if peek () <> Lexer.EOF then fail ();
  is

(* M.mli's vals and their types, in place of what M.ml's inferred: its
 * types and exceptions are M.ml's too, and skipped; a val of module
 * N : sig ... end is N.x *)
let mli_types (text : string) : (string * Tree.ty) list =
  toks := Lexer.lex text; pos := 0;
  let prefix = ref "" in
  let starts () =
    match peek () with
    | Lexer.LID "val"
      | Lexer.KW ("module" | "type" | "exception" | "external" | "end")
    | Lexer.EOF -> true
    | _ -> false
  in
  let rec go acc =
    match peek () with
    | Lexer.EOF -> acc
    | Lexer.KW "module" ->
        advance ();
        (match peek () with
         | Lexer.UID m -> advance (); prefix := m ^ "."
         | _ -> fail ());
        expect (Lexer.KW ":");
        if peek () <> Lexer.KW "sig" then fail ();
        advance ();
        go acc
    | Lexer.KW "end" -> advance (); prefix := ""; go acc
    | Lexer.LID "val" ->
        advance ();
        let x = val_name () in
        expect (Lexer.KW ":");
        let t = ty () in
        go ((!prefix ^ x, Tree.of_texpr (ref []) t) :: acc)
    | _ -> advance (); while not (starts ()) do advance () done; go acc in
  go []
