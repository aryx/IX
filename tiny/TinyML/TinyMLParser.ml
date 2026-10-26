(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLParser.mli *)
open TinyMLLexer
open TinyMLTree
open TinyMLPrintf

(*****************************************************************************)
(* The parser *)
(*****************************************************************************)

let toks : (token * int) array ref = ref (Array.of_list []) and pos = ref 0
let peek () = fst (!toks).(!pos)
let peek_at k = fst (!toks).(min (!pos + k) (Array.length !toks - 1))
let line () = snd (!toks).(!pos)
let advance () = if peek () <> EOF then incr pos
let accept t = if peek () = t then (advance (); true) else false
let show_tok = function
  | INT n -> string_of_int n | CHAR _ -> "a character" | STR _ -> "a string"
  | LID x -> x | UID x -> x | KW x -> x | EOF -> "the end"
let fail () =
  error
    (Printf.sprintf "line %d: syntax error at %s" (line ()) (show_tok (peek ())))
let expect t = if not (accept t) then fail ()
let fresh = ref 0

(* the names of types declared as an object's: read and forgotten (ty) *)
let forgotten : string list ref = ref []

(* type word = piece list, type 'a t = unit -> 'a node: a second name
 * for a type, its parameters' names; unify puts the type in the name's
 * place when the two differ, so a name may be used above its
 * declaration. A name and its number of parameters say which: Sha1's
 * t and Seq's 'a t are two
 * (old: no parameter, a name only) *)
let abbreviations : (string * (string list * texpr)) list ref = ref []

(* the abbreviation that a name with these arguments is *)
let abbreviation c ts =
  match
    List.find_opt (fun (c', (ps, _)) -> c' = c && List.length ps = List.length ts)
      !abbreviations
  with
  | Some (_, (ps, te)) -> Some (of_texpr (ref (List.combine ps ts)) te)
  | None -> None

(* the operators: precedence and right associativity; "," is 1 *)
let binops =
  [ ":=", 0, true; "<-", 0, true; "||", 2, true; "or", 2, true; "&&", 3, true;
    "&", 3, true; "=", 4, false; "<>", 4, false; "<", 4, false; ">", 4, false;
    "<=", 4, false; ">=", 4, false; "==", 4, false; "!=", 4, false;
    "|>", 4, false; "|||", 4, false; "@", 5, true; "^", 5, true; "::", 6, true;
    "+", 7, false; "-", 7, false; "*", 8, false; "/", 8, false; "mod", 8, false;
    "land", 8, false; "lor", 8, false;
    "lxor", 8, false; "lsl", 9, true; "lsr", 9, true; "asr", 9, true ]

let is_op o = List.exists (fun (b, _, _) -> b = o) binops || o = "!" || o = "~-"

(* C (a, b) is a constructor of two arguments, the tuple its parser saw *)
let con_args c args untuple =
  let ci = find_con c in
  match args with
  | [] when ci.arity = 0 -> []
  | [ a ] when ci.arity = 1 -> [ a ]
  | [ a ] when ci.arity > 1 ->
      (match untuple ci.arity a with
       | Some l when List.length l = ci.arity -> l
       | _ ->
           error
             (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c
                ci.arity))
  | _ ->
      error
        (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c ci.arity)

let starts_atom = function
  | INT _ | CHAR _ | STR _ | LID _ | UID _
  | KW ("(" | "[" | "{" | "begin" | "!") -> true
  | _ -> false
let starts_patom = function
  | INT _ | CHAR _ | STR _ | LID _ | UID _ | KW ("_" | "(" | "[" | "{") -> true
  | _ -> false

(* expressions: a sequence, then let/match/fun/if, then the operators
 * by precedence climbing, then application *)
let rec expr () =
  let e = stmt () in
  if accept (KW ";") then
    match peek () with
    | KW ("end" | ")" | "done" | "in" | ";;" | "|" | "]" | "with" | "else"
         | "then")
    | EOF -> e
    | _ -> Seq (e, expr ())
  else e

and stmt () =
  match peek () with
  | KW "let" ->
      advance ();
      let r = accept (KW "rec") in
      let bs = bindings () in
      expect (KW "in");
      Let (r, bs, expr ())
  | KW "match" ->
      advance (); let e = expr () in expect (KW "with"); Match (e, cases ())
  | KW "try" ->
      advance (); let e = expr () in expect (KW "with"); Try (e, cases ())
  | KW "function" -> advance (); Fun ([ "%f" ], Match (var "%f", cases ()))
  | KW "fun" ->
      advance (); let ps = params () in expect (KW "->"); fun_of ps (expr ())
  | KW "if" ->
      advance ();
      let c = expr () in
      expect (KW "then");
      let a = stmt () in
      If (c, a, if accept (KW "else") then stmt () else Con ("()", []))
  | KW "while" ->
      advance ();
      let c = expr () in
      expect (KW "do");
      let b = expr () in
      expect (KW "done");
      While (c, b)
  | KW "for" ->
      advance ();
      let x = match peek () with LID x -> advance (); x | _ -> fail () in
      expect (KW "=");
      let a = expr () in
      let up =
        if accept (KW "to") then true else (expect (KW "downto"); false) in
      let b = expr () in
      expect (KW "do");
      let body = expr () in
      expect (KW "done");
      For (x, a, b, up, body)
  | _ -> binary 0

and binary min =
  let rec loop lhs =
    match peek () with
    | KW "," when min <= 1 ->
        let rec more () =
          advance ();
          let e = binary 2 in
          if peek () = KW "," then e :: more () else [ e ]
        in
        loop (Tuple (lhs :: more ()))
    | KW op -> (
        match List.find_opt (fun (o, _, _) -> o = op) binops with
        | Some (_, p, right) when p >= min ->
            advance ();
            let rhs = binary (if right then p else p + 1) in
            loop
              (match op with
               | "::" -> Con ("::", [ lhs; rhs ])
               | "&&" | "&" -> If (lhs, rhs, Con ("false", []))
               | "||" | "or" -> If (lhs, Con ("true", []), rhs)
               | "<-" -> (
                   match lhs with
                   | Dot (e, l, i) -> SetDot (e, l, i, rhs)
                   | App (Var ("Array.get", _), [ a; i ]) ->
                       (* i, a, then the value, ocamlopt's order *)
                       incr fresh;
                       let a' = Printf.sprintf "%%a%d" !fresh
                       and i' = Printf.sprintf "%%i%d" !fresh in
                       Let (false, [ PVar i', i ],
                         Let (false, [ PVar a', a ],
                           App (var "Array.set", [ var a'; var i'; rhs ])))
                   | _ ->
                       error
                         (Printf.sprintf
                            "line %d: <- on a field or an array's element only"
                            (line ())))
               | _ -> App (var op, [ lhs; rhs ]))
        | _ -> lhs)
    | _ -> lhs
  in
  loop (unary ())

and unary () =
  match peek () with
  | KW "-" ->
      advance ();
      (match peek () with
       | INT n -> advance (); Const (CInt (-n))
       | _ -> App (var "~-", [ unary () ]))
  | _ -> app ()

and app () =
  match peek () with
  | UID c when starts_atom (peek_at 1) && (find_con c).arity > 0 ->
      advance ();
      let a = atom () in
      Con (c, con_args c [ a ] (fun _ -> function Tuple l -> Some l | _ -> None))
  | _ -> (
      let f = atom () in
      let rec args () =
        if starts_atom (peek ()) then let a = atom () in a :: args () else [] in
      match f, args () with
      | _, [] -> f
      | Var (p, _), l
        when p = "Printf.sprintf" || p = "Printf.ksprintf"
             || p = "Printf.bprintf" ->
          printf_call p l
      | _, l -> App (f, l))

and atom () =
  let e =
    match peek () with
    | INT n -> advance (); Const (CInt n)
    | CHAR c -> advance (); Const (CChar c)
    | STR s -> advance (); Const (CStr s)
    | LID x -> advance (); var x
    | UID c -> advance (); Con (c, con_args c [] (fun _ _ -> None))
    | KW "!" -> advance (); App (var "!", [ atom () ])
    | KW "(" -> (
        advance ();
        if accept (KW ")") then Con ("()", [])
        else
          match peek (), peek_at 1 with
          | KW op, KW ")" when is_op op -> advance (); advance (); var op
          | _ ->
              let e = expr () in
              if accept (KW ":") || accept (KW ":>") then ignore (ty ());
              expect (KW ")");
              e)
    | KW "begin" ->
        advance ();
        if accept (KW "end") then Con ("()", [])
        else (let e = expr () in expect (KW "end"); e)
    | KW "[" ->
        advance ();
        let rec elems () =
          if accept (KW "]") then Con ("[]", [])
          else (
            let e = stmt () in
            ignore (accept (KW ";"));
            Con ("::", [ e; elems () ]))
        in
        elems ()
    | KW "{" ->
        advance ();
        let rec fields () =
          if accept (KW "}") then []
          else match peek () with
            (* { text; pos = 0 }: a field alone is the variable of its name *)
            | LID l ->
                advance ();
                let e = if accept (KW "=") then stmt () else var l in
                ignore (accept (KW ";"));
                (l, e) :: fields ()
            | _ -> fail () in
        (* a label followed by =, ; or } begins the fields; anything else
         * is the record that { e with ... } copies *)
        (match peek (), peek_at 1 with
         | LID _, KW ("=" | ";" | "}") -> Record (fields (), ref [])
         | _ ->
             let e = atom () in
             expect (KW "with");
             (match fields () with
              | [] -> fail ()
              | fs -> With (e, fs, ref [], ref 0)))
    | KW ("let" | "match" | "try" | "fun" | "function" | "if" | "while" | "for")
      ->
        stmt ()
    | _ -> fail ()
  in
  postfix e

and postfix e =
  if accept (KW ".[") then (
    let i = expr () in
    expect (KW "]");
    postfix (App (var "String.get", [ e; i ])))
  else if peek () = KW "." then (
    advance ();
    match peek () with
    | LID l -> advance (); postfix (Dot (e, l, ref 0))
    | KW "(" ->
        advance ();
        let i = expr () in
        expect (KW ")");
        postfix (App (var "Array.get", [ e; i ]))
    | _ -> fail ())
  else e

and cases () =
  ignore (accept (KW "|"));
  let p = pattern () in
  let g = if accept (KW "when") then Some (expr ()) else None in
  expect (KW "->");
  let e = expr () in
  (p, g, e) :: (if peek () = KW "|" then cases () else [])

(* patterns: as, then |, then the tuple, then ::, then a constructor's *)
and pattern () =
  let p = por () in
  if accept (KW "as") then
    (match peek () with LID x -> advance (); PAlias (p, x) | _ -> fail ())
  else p

and por () = let p = ptuple () in if accept (KW "|") then POr (p, por ()) else p

and ptuple () =
  let p = pcons () in
  if peek () = KW "," then (
    let rec more () =
      if accept (KW ",") then let q = pcons () in q :: more () else [] in
    PTuple (p :: more ()))
  else p

and pcons () =
  let p = papp () in
  if accept (KW "::") then PCon ("::", [ p; pcons () ]) else p

and papp () =
  match peek () with
  | UID c when starts_patom (peek_at 1) && (find_con c).arity > 0 ->
      advance ();
      let a = patom () in
      PCon (c,
        con_args c [ a ] (fun n -> function
          | PTuple l -> Some l
          | PAny -> Some (List.init n (fun _ -> PAny))
          | _ -> None))
  | _ -> patom ()

and patom () =
  match peek () with
  | LID x -> advance (); PVar x
  | KW "_" -> advance (); PAny
  | INT n -> advance (); PConst (CInt n)
  | CHAR c -> advance (); PConst (CChar c)
  | STR s -> advance (); PConst (CStr s)
  | KW "-" ->
      advance ();
      (match peek () with INT n -> advance (); PConst (CInt (-n)) | _ -> fail ())
  | UID c -> advance (); PCon (c, con_args c [] (fun _ _ -> None))
  | KW "(" ->
      advance ();
      if accept (KW ")") then PCon ("()", [])
      else (
        let p = pattern () in
        let p = if accept (KW ":") then PAnnot (p, ty ()) else p in
        expect (KW ")");
        p)
  | KW "[" ->
      advance ();
      let rec elems () =
        if accept (KW "]") then PCon ("[]", [])
        else (
          let p = pattern () in
          ignore (accept (KW ";"));
          PCon ("::", [ p; elems () ]))
      in
      elems ()
  | KW "{" ->
      advance ();
      (* { view; update = u; _ }: a field alone binds the variable of its
       * name, and _ allows the fields not named *)
      let rec fields () =
        if accept (KW "}") then []
        else match peek () with
          | LID l ->
              advance ();
              let p = if accept (KW "=") then pattern () else PVar l in
              ignore (accept (KW ";"));
              (l, p) :: fields ()
          | KW "_" -> advance (); ignore (accept (KW ";")); expect (KW "}"); []
          | _ -> fail () in
      (match fields () with
       | [] -> fail ()
       | fs -> PRecord (fs, ref [], ref 0))
  | _ -> fail ()

and params () =
  if starts_patom (peek ()) then let p = patom () in p :: params () else []

(* fun p q -> e: a pattern other than a name is a let of the parameter *)
and fun_of ps body =
  let names, body =
    List.fold_right (fun p (names, body) ->
      match p with
      | PVar x -> x :: names, body
      | p ->
          incr fresh;
          let x = Printf.sprintf "%%p%d" !fresh in
          x :: names, Let (false, [ p, var x ], body))
      ps ([], body)
  in
  (* fun x -> function ...: one function of both, as OCaml makes it
   * (old: a closure made at each call of the first, List.length's
   * len n = function ..., an allocation an element: half of tiny-ml's
   * time on tiny-kernel) *)
  match body with
  | Fun (more, body)
    when List.length names + List.length more <= 10
         && not (List.exists (fun x -> List.mem x names) more) ->
      Fun (names @ more, body)
  | _ -> Fun (names, body)

and bindings () =
  let b = binding () in
  if accept (KW "and") then b :: bindings () else [ b ]

and binding () =
  let name =
    match peek (), peek_at 1 with
    | LID x, t when not (List.mem t [ KW "="; KW ","; KW ":"; KW "as"; KW "::" ])
      ->
        advance (); Some x
    | KW "(", KW op when is_op op && peek_at 2 = KW ")" ->
        advance (); advance (); advance (); Some op
    | _ -> None
  in
  match name with
  | Some f ->
      let ps = params () in
      if accept (KW ":") then ignore (ty ());
      expect (KW "=");
      PVar f, (if ps = [] then expr () else fun_of ps (expr ()))
  | None ->
      let p = pattern () in
      let p = if accept (KW ":") then PAnnot (p, ty ()) else p in
      expect (KW "=");
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
  (match peek (), peek_at 1 with LID _, KW ":" -> advance (); advance () | _ -> ());
  let t = ty_tuple () in if accept (KW "->") then TE ("->", [ t; ty () ]) else t

and ty_tuple () = match ty_args () with [ t ] -> t | l -> TE ("*", l)

and ty_args () =
  let t = ty_app () in
  if accept (KW "*") then t :: ty_args () else [ t ]

and ty_app () =
  let args =
    match peek () with
    | KW "'" ->
        advance ();
        (match peek () with LID v -> advance (); [ TEVar v ] | _ -> fail ())
    | KW "(" ->
        advance ();
        let rec go () =
          let t = ty () in
          if accept (KW ",") then t :: go () else [ t ]
        in
        let l = go () in
        expect (KW ")");
        l
    | KW "<" -> skip_object (); [ any () ]
    | LID c when List.mem c !forgotten -> advance (); [ any () ]
    | LID c -> advance (); [ TE (c, []) ]
    | _ -> fail ()
  in
  (* (val: OCaml's keyword, not tiny-ml's: an .mli's next item) *)
  let rec post args =
    match peek () with
    | LID c when c <> "val" -> advance (); post [ TE (c, args) ]
    | _ -> args
  in
  match post args with [ t ] -> t | _ -> fail ()

and any () = incr fresh; TEVar (Printf.sprintf "%%o%d" !fresh)

and skip_object () =
  advance ();
  while peek () <> KW ">" do (if peek () = EOF then fail ()); advance () done;
  advance ()

(* type ('a, 'b) t = A | B of 'a * t and ...: the constructors
 * numbered, the constant ones and the others apart; or a record, type
 * t = { a : int; mutable b : t }, its labels numbered; or another
 * type's second name, type word = piece list (abbreviations) *)
let rec type_decl () =
  let tvar () =
    expect (KW "'"); match peek () with LID v -> advance (); v | _ -> fail () in
  let params =
    match peek () with
    | KW "'" -> [ tvar () ]
    | KW "(" ->
        advance ();
        let rec go () =
          let v = tvar () in
          if accept (KW ",") then v :: go () else [ v ]
        in
        let l = go () in
        expect (KW ")");
        l
    | _ -> []
  in
  let name = match peek () with LID x -> advance (); x | _ -> fail () in
  expect (KW "=");
  ignore (accept (KW "|"));
  let vars = ref (List.map (fun v -> v, genvar ()) params) in
  let res = TCon (name, List.map snd !vars) in
  if peek () = KW "<" then (skip_object (); forgotten := name :: !forgotten)
  else if accept (KW "{") then begin
    let rec fields () =
      if accept (KW "}") then []
      else
        let mut = accept (LID "mutable") in
        let l = match peek () with LID l -> advance (); l | _ -> fail () in
        expect (KW ":");
        let t = of_texpr vars (ty ()) in
        ignore (accept (KW ";"));
        (l, mut, t) :: fields () in
    let fs = fields () in
    let lnames = List.map (fun (l, _, _) -> l) fs in
    List.iteri (fun idx (l, mut, t) ->
      Hashtbl.add record_labels l
        { lrec = name; idx; mut; lnames; lscheme = TCon ("%l", [ res; t ]) })
      fs
  end else if (match peek () with UID _ -> false | _ -> true) then begin
    abbreviations := (name, (params, ty ())) :: !abbreviations
  end else begin
    let rec ctors () =
      let c =
        match peek () with
        | UID c -> advance (); c
        | _ ->
            error
              (Printf.sprintf "line %d: a constructor or a record expected"
                 (line ()))
      in
      let args =
        if accept (KW "of") then List.map (of_texpr vars) (ty_args ()) else []
      in
      (c, args) :: (if accept (KW "|") then ctors () else [])
    in
    let cs = ctors () in
    let nconst = List.length (List.filter (fun (_, a) -> a = []) cs) in
    let nblock = List.length cs - nconst in
    let ic = ref 0 and ib = ref 0 in
    List.iter (fun (c, args) ->
      let kind =
        if args = [] then (incr ic; KConst (!ic - 1))
        else (incr ib; KBlock (!ib - 1))
      in
      Hashtbl.replace cons c
        { kind; arity = List.length args; nconst; nblock;
          scheme = TCon ("%c", res :: args) })
      cs
  end;
  if accept (KW "and") then type_decl ()

let rec items () : (item * int) list =
  let l = line () in
  match peek () with
  | EOF -> []
  | KW ";;" -> advance (); items ()
  | KW "let" ->
      advance ();
      let r = accept (KW "rec") in
      let bs = bindings () in
      if accept (KW "in") then (
        let e = Let (r, bs, expr ()) in
        (ILet (false, [ PAny, e ]), l) :: items ())
      else (ILet (r, bs), l) :: items ()
  | KW "type" -> advance (); type_decl (); items ()
  | KW "open" ->
      advance ();
      (match peek () with
       | UID m -> advance (); (IOpen m, l) :: items ()
       | _ -> fail ())
  | KW "exception" ->
      advance ();
      let c = match peek () with UID c -> advance (); c | _ -> fail () in
      let args =
        if accept (KW "of") then List.map (of_texpr (ref [])) (ty_args ())
        else []
      in
      Hashtbl.replace cons c
        { kind = KExn; arity = List.length args; nconst = 0; nblock = 0;
          scheme = TCon ("%c", tcon "exn" :: args) };
      (IExn c, l) :: items ()
  | KW "external" ->
      advance ();
      let x =
        match peek () with
        | LID x -> advance (); x
        | KW "(" ->
            advance ();
            let o = (match peek () with KW o -> advance (); o | _ -> fail ()) in
            expect (KW ")");
            o
        | _ -> fail ()
      in
      expect (KW ":");
      let t = ty () in
      expect (KW "=");
      let p = match peek () with STR p -> advance (); p | _ -> fail () in
      (IExt (x, t, p), l) :: items ()
  | _ -> let e = expr () in (ILet (false, [ PAny, e ]), l) :: items ()
