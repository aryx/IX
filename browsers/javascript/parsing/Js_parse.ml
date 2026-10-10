(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/parsing/Js_parse.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_parse.mli *)
open Js_ast

type error = { line : int; message : string }

(* ix: Parse_error, where it was Error: a result's Error beside it is then mini-ml's to tell apart *)
exception Parse_error of error

(* the tokens, and where the parser is in them *)
type t = {
  text : string; (* what the tokens were read from *)
  tokens : Js_lexer.token array;
  mutable pos : int;
  aside : bool; (* read beside the window's run, on another thread: no slice of that run is its own to end *)
  (* in a for's first part: "in" is the for's, not an operator *)
  mutable no_in : bool;
  (* in an async function's body: "await" is the operator, not a name *)
  mutable in_async : bool;
  (* in a generator's body: "yield" is the operator *)
  mutable in_generator : bool;
}

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

(* (the least of two ints written out, and a token's kind matched: OCaml's
 * min and = on any two values are a call to the runtime each) *)
let peek_at (p : t) (k : int) : Js_lexer.token =
  let i = p.pos + k and last = Array.length p.tokens - 1 in
  p.tokens.(if i < last then i else last)

let peek (p : t) : Js_lexer.token = peek_at p 0
let advance (p : t) : Js_lexer.token = let t = peek p in p.pos <- p.pos + 1; t

let describe (k : Js_lexer.kind) : string =
  match k with
  | Keyword w | Name w | Punct w -> Printf.sprintf "'%s'" w
  | Number f -> Js_ast.number_to_string f
  | String s -> Printf.sprintf "%S" s
  | Regex (r, f) -> Printf.sprintf "/%s/%s" r f
  | Template _ -> "a template"
  | Eof -> "the end"

(* JS_SYNTAX=1: the tokens before the one refused said too -- a bundle
 * is one line of a megabyte, and its number says nothing *)
let syntax_context = ref false

let fail (p : t) (message : string) =
  let message =
    if not !syntax_context then message
    else
      let from = max 0 (p.pos - 12) in
      (* (and how the text starts, when it is short enough to be one a script made: an eval's) *)
      message ^ ", after: " ^ String.concat " " (List.init (p.pos - from) (fun i -> describe p.tokens.(from + i).kind))
      ^ if String.length p.text < 4000 then ", in: " ^ String.escaped (String.sub p.text 0 (min 600 (String.length p.text))) else ""
  in
  raise (Parse_error { line = (peek p).line; message })
let unexpected (p : t) (what : string) = fail p (Printf.sprintf "expected %s, not %s" what (describe (peek p).kind))
let is_punct (p : t) (s : string) : bool = match (peek p).kind with Punct x -> String.equal x s | _ -> false
let is_keyword (p : t) (s : string) : bool = match (peek p).kind with Keyword x -> String.equal x s | _ -> false

let expect (p : t) (s : string) : unit = if is_punct p s then ignore (advance p) else unexpected p (Printf.sprintf "'%s'" s)

let name (p : t) : string =
  match (advance p).kind with
  | Name x -> x
  | _ ->
      p.pos <- p.pos - 1;
      unexpected p "a name"

(*****************************************************************************)
(* Expressions: Pratt *)
(*****************************************************************************)

(* as tight as <: instanceof and in too, which are words *)
let relational = 10

(* an infix operator's binding power, and whether it is right-associative *)
let assignments = [ "="; "+="; "-="; "*="; "/="; "%="; "**="; "<<="; ">>="; ">>>="; "&="; "|="; "^=" ]

let infix_of (op : string) : (int * bool) option =
  match op with
  | "," -> Some (0, false)
  | op when List.mem op assignments -> Some (1, true)
  (* ES2021: a ||= b assigns only if a is falsy; &&=, ??= the same of && and ?? *)
  | "&&=" | "||=" | "??=" -> Some (1, true)
  | "?" -> Some (2, true)
  | "??" -> Some (3, false)
  | "||" -> Some (4, false)
  | "&&" -> Some (5, false)
  | "|" -> Some (6, false)
  | "^" -> Some (7, false)
  | "&" -> Some (8, false)
  | "===" | "!==" | "==" | "!=" -> Some (9, false)
  | "<" | ">" | "<=" | ">=" -> Some (relational, false)
  | "<<" | ">>" | ">>>" -> Some (11, false)
  | "+" | "-" -> Some (12, false)
  | "*" | "/" | "%" -> Some (13, false)
  | "**" -> Some (14, true)
  | _ -> None

(* opti: each operator's answer kept (the match above is a row of
 * string comparisons, asked at every token of an expression) *)
let infix_memo : (string, (int * bool) option) Hashtbl.t = Hashtbl.create 64

(* filled once, for every punctuation, and only read after: a text may
 * be parsed on a worker of the pool while another is here
 * (Js_module.parse), and a table two write at once is a table broken *)
let () = List.iter (fun op -> Hashtbl.replace infix_memo op (infix_of op)) Js_lexer.punctuators

let infix (op : string) : (int * bool) option = match Hashtbl.find_opt infix_memo op with Some r -> r | None -> infix_of op

let prefix_power = 15
let postfix_power = 16

(* what an assignment or ++ may change *)
let target (p : t) (e : expr) : expr =
  (* [a, b] = ..., ({ a, b } = ...): a literal read as a pattern (Js_eval.assign) *)
  match e with Name _ | Member _ | Index _ | Array _ | Object _ -> e | _ -> fail p "that cannot be assigned to"

(* the index of the ")" matching the "(" at [p.pos], if any *)
let closing (p : t) : int option =
  let rec go i depth =
    match p.tokens.(i).kind with
    | Eof -> None
    | Punct ("(" | "[" | "{") -> go (i + 1) (depth + 1)
    | Punct (")" | "]" | "}") -> if depth = 1 then Some i else go (i + 1) (depth - 1)
    | _ -> go (i + 1) depth
  in
  go p.pos 0

(* an arrow ahead: "x =>", or "( ... ) =>" *)
let arrow_ahead (p : t) : bool =
  match ((peek p).kind, (peek_at p 1).kind) with
  | Name _, Punct "=>" -> true
  | Punct "(", _ -> (
      match closing p with Some i -> p.tokens.(i + 1).kind = Punct "=>" | None -> false)
  | _ -> false

(* ix: a type, where they were `Get and `Set *)
type accessor = Getter | Setter

(* between brackets, "in" is the operator, whatever is outside
 * (ix: before the expressions and not among them: what it gives is of
 * any type) *)
let inside (p : t) (f : unit -> 'a) : 'a =
  let outer = p.no_in in
  p.no_in <- false;
  let x = f () in
  p.no_in <- outer;
  x

let rec expression (p : t) (min : int) : expr =
  let left = prefix p in
  loop p min left

(* the operators binding at least as tight as [min], each taking the
 * left side so far *)
and loop (p : t) (min : int) (left : expr) : expr =
  let t = peek p in
  match t.kind with
  | Punct "." when postfix_power >= min ->
      ignore (advance p);
      loop p min (Member (left, property_name p))
  (* a?.b, a?.[k], a?.(x): the chain from here read whole, so that it
   * ends as one if a is null or undefined *)
  | Punct "?." when postfix_power >= min ->
      let rec chain (e : expr) : expr =
        match (peek p).kind with
        | Punct "?." -> (
            ignore (advance p);
            match (peek p).kind with
            | Punct "[" -> ignore (advance p); let i = inside p (fun () -> expression p 0) in expect p "]"; chain (Index (Opt e, i))
            | Punct "(" -> ignore (advance p); chain (Call (Opt e, arguments p))
            | _ -> chain (Member (Opt e, property_name p)))
        | Punct "." -> ignore (advance p); chain (Member (e, property_name p))
        | Punct "[" -> ignore (advance p); let i = inside p (fun () -> expression p 0) in expect p "]"; chain (Index (e, i))
        | Punct "(" -> ignore (advance p); chain (Call (e, arguments p))
        | _ -> e
      in
      loop p min (Optional (chain left))
  | Punct "[" when postfix_power >= min ->
      ignore (advance p);
      let i = inside p (fun () -> expression p 0) in
      expect p "]";
      loop p min (Index (left, i))
  (* tag`...`: a template right after an expression is its argument *)
  | Template (strings, expressions) when postfix_power >= min ->
      ignore (advance p);
      loop p min (Tagged (left, strings, template_values p t expressions))
  | Punct "(" when postfix_power >= min ->
      ignore (advance p);
      let args = arguments p in
      loop p min (Call (left, args))
  (* x++, but not x on one line and ++y on the next: [no LineTerminator here] *)
  (* x instanceof F: as tight as < *)
  | Keyword (("instanceof" | "in") as op) when relational >= min && not (op = "in" && p.no_in) ->
      ignore (advance p);
      loop p min (Binary (op, left, expression p (relational + 1)))
  | Punct (("++" | "--") as op) when postfix_power >= min && not t.newline_before ->
      ignore (advance p);
      loop p min (Update (op, false, target p left))
  | Punct op -> (
      match infix op with
      | Some (power, right) when power >= min ->
          ignore (advance p);
          let next = if right then power else power + 1 in
          let e =
            match op with
            | "?" ->
                (* the middle as if in parentheses (but no comma), then the rest *)
                let a = expression p 1 in
                expect p ":";
                (* each side may be an assignment: c ? a = 1 : b = 2 *)
                ignore next;
                Conditional (left, a, expression p 1)
            | "," -> Comma (left, expression p next)
            | op when List.mem op assignments -> Assign (op, target p left, expression p next)
            | "&&=" | "||=" | "??=" -> Assign (op, target p left, expression p next)
            | "&&" | "||" | "??" -> Logical (op, left, expression p next)
            | _ -> Binary (op, left, expression p next)
          in
          loop p min e
      | _ -> left)
  | _ -> left

(* a function's body read by [f]: await is the operator in an async
 * one's, a name in another's, whatever the function around is *)
and body_in (p : t) ~(async : bool) ~(generator : bool) (f : unit -> stmt list) : stmt list =
  let outer = (p.in_async, p.in_generator) in
  p.in_async <- async;
  p.in_generator <- generator;
  let x = f () in
  p.in_async <- fst outer;
  p.in_generator <- snd outer;
  x

(* a template's ${ }s, each read as an expression of its own, on the
 * template's line *)
and template_values (p : t) (t : Js_lexer.token) (expressions : Js_lexer.token list list) : expr list =
  List.map
    (fun (tokens : Js_lexer.token list) ->
      let inner = { text = "" (* a ${ }'s tokens are of a text of their own: a function there has no text kept *); tokens = Array.of_list (tokens @ [ { t with kind = Eof } ]); pos = 0; aside = p.aside; no_in = false; in_async = p.in_async; in_generator = p.in_generator } in
      let e = expression inner 0 in
      if (peek inner).kind <> Eof then unexpected inner "'}'";
      e)
    expressions

(* after a ".": a name, and a keyword is one too (o.default, e.catch) *)
and property_name (p : t) : string =
  match (advance p).kind with Name x | Keyword x -> x | _ -> p.pos <- p.pos - 1; unexpected p "a property name"

(* what can start an expression *)
and prefix (p : t) : expr =
  let word_async = (peek p).kind = Name "async" in
  (* async function ..., async x => ..., async (a, b) => ...; else async is a name *)
  if word_async && (peek_at p 1).kind = Keyword "function" then (p.pos <- p.pos + 2; Function (named (func p ~arrow:false ~async:true)))
  else if word_async && (p.pos <- p.pos + 1; arrow_ahead p || (p.pos <- p.pos - 1; false)) then arrow p ~async:true
  else if arrow_ahead p then arrow p ~async:false
  else
    let t = advance p in
    match t.kind with
    | Name "await" when p.in_async -> Await (expression p prefix_power)
    (* yield, yield e, yield* e: in a generator *)
    | Name "yield" when p.in_generator ->
        let delegate = is_punct p "*" && (ignore (advance p); true) in
        let next = peek p in
        let nothing = next.newline_before || (match next.kind with Punct (")" | "]" | "}" | "," | ";" | ":") | Eof -> true | _ -> false) in
        Yield (delegate, if nothing && not delegate then None else Some (expression p 1))
    | Number f -> Number f
    | String s -> String s
    (* super(a), super.m: the class's parent *)
    | Name "super" when is_punct p "(" ->
        ignore (advance p);
        Super_call (arguments p)
    | Name "super" when is_punct p "." ->
        ignore (advance p);
        Super_member (property_name p)
    (* import("m"), import.meta: a module's; import is else a name *)
    | Name "import" when is_punct p "(" ->
        ignore (advance p);
        let spec = expression p 1 in
        (* a second argument (options), a trailing comma: read and dropped *)
        if is_punct p "," then (ignore (advance p); if not (is_punct p ")") then ignore (expression p 1));
        expect p ")";
        Import_call spec
    | Name "import" when is_punct p "." && (peek_at p 1).kind = Name "meta" ->
        p.pos <- p.pos + 2;
        Import_meta
    (* #x in o (ES2022): whether o has the private #x -- its key, as a string *)
    | Name x when String.length x > 1 && x.[0] = '#' && is_keyword p "in" -> String x
    | Name x -> Name x
    | Keyword "true" -> Bool true
    | Keyword "false" -> Bool false
    | Keyword "null" -> Null
    | Keyword "this" -> This
    | Keyword (("typeof" | "void" | "delete") as op) -> Unary (op, expression p prefix_power)
    | Keyword "function" -> Function (named (func p ~arrow:false ~async:false))
    | Punct (("-" | "+" | "!" | "~") as op) -> Unary (op, expression p prefix_power)
    | Punct (("++" | "--") as op) -> Update (op, true, target p (expression p prefix_power))
    | Punct "(" ->
        let e = inside p (fun () -> expression p 0) in
        expect p ")";
        e
    | Punct "[" ->
        let rec elements acc =
          if is_punct p "]" then List.rev acc
          (* [a, , b]: a hole, undefined *)
          else if is_punct p "," then (ignore (advance p); elements (Name "undefined" :: acc))
          else
            let e = spread_or p in
            if is_punct p "," then (ignore (advance p); elements (e :: acc))
            else List.rev (e :: acc)
        in
        let es = inside p (fun () -> elements []) in
        expect p "]";
        Array es
    | Punct "{" ->
        let rec members acc =
          if is_punct p "}" then List.rev acc
          else
            let m = property p in
            if is_punct p "," then (ignore (advance p); members (m :: acc)) else List.rev (m :: acc)
        in
        let props = inside p (fun () -> members []) in
        expect p "}";
        Object props
    | Regex (r, f) -> Regex (r, f)
    | Template (strings, expressions) -> Template (strings, template_values p t expressions)
    (* new F(a), new F: F a name and its members, not a call *)
    (* new.target: the constructor being instantiated -- read here as
     * the new object's constructor, which it is whenever the function
     * was called by new (a class's Object.setPrototypeOf(this,
     * new.target.prototype)); not undefined in a plain call *)
    | Keyword "new" when is_punct p "." && (peek_at p 1).kind = Name "target" ->
        ignore (advance p);
        ignore (advance p);
        Member (This, "constructor")
    | Keyword "new" ->
        let rec members e =
          match (peek p).kind with
          | Punct "." -> (
              ignore (advance p);
              match (advance p).kind with Name x | Keyword x -> members (Member (e, x)) | _ -> p.pos <- p.pos - 1; unexpected p "a property name")
          | Punct "[" ->
              ignore (advance p);
              let i = expression p 0 in
              expect p "]";
              members (Index (e, i))
          | _ -> e
        in
        let callee = members (prefix p) in
        let args = if is_punct p "(" then (ignore (advance p); arguments p) else [] in
        New (callee, args)
    | Keyword "class" -> Class (class_ p)
    | _ ->
        p.pos <- p.pos - 1;
        unexpected p "an expression"

(* an item of an array or an argument of a call: an expression, or
 * ...one, each of its items *)
and spread_or (p : t) : expr =
  if is_punct p "..." then (ignore (advance p); Spread (expression p 1)) else expression p 1

(* a property's key: a name (a keyword is one), a string, a number, or
 * [an expression] *)
and key (p : t) : key =
  match (advance p).kind with
  | Name k | Keyword k | String k -> Key k
  | Number f -> Key (Js_ast.number_to_string f)
  | Punct "[" ->
      let e = inside p (fun () -> expression p 1) in
      expect p "]";
      Computed e
  | _ -> p.pos <- p.pos - 1; unexpected p "a property name"

(* m(params) { body }, of an object literal or a class: what is after
 * its key *)
and method_ (p : t) (k : key) ~(async : bool) ~(generator : bool) : func =
  let ps, rest = params p in
  { name = (match k with Key n -> Some n | Computed _ -> None); params = ps; rest; body = body_in p ~async ~generator (fun () -> block_body p); arrow = false; generator; async; frame = None; own_name = false; text = None }

(* one property of an object literal *)
and property (p : t) : property =
  let next = (peek_at p 1).kind in
  (* a name, a string or [ after get or set: an accessor, not a
   * property called "get" *)
  let accessor = match next with Name _ | Keyword _ | String _ | Number _ | Punct "[" -> true | _ -> false in
  match (peek p).kind with
  | Punct "..." ->
      ignore (advance p);
      Spread_prop (expression p 1)
  | Name (("get" | "set") as which) when accessor ->
      ignore (advance p);
      let k = key p in
      let ps, rest = params p in
      let f = { name = None; params = ps; rest; body = body_in p ~async:false ~generator:false (fun () -> block_body p); arrow = false; generator = false; async = false; frame = None; own_name = false; text = None } in
      if which = "get" then Getter (k, f) else Setter (k, f)
  (* async m() { } *)
  | Name "async" when accessor || next = Punct "*" ->
      ignore (advance p);
      (* async *m() { }: an async generator *)
      let generator = is_punct p "*" && (ignore (advance p); true) in
      let k = key p in
      Prop (k, Function (method_ p k ~async:true ~generator))
  (* *m() { }: a generator *)
  | Punct "*" ->
      ignore (advance p);
      let k = key p in
      Prop (k, Function (method_ p k ~async:false ~generator:true))
  | _ -> (
      let k = key p in
      match ((peek p).kind, k) with
      | Punct ":", _ ->
          ignore (advance p);
          Prop (k, expression p 1)
      (* m() { }: a method *)
      | Punct "(", _ -> Prop (k, Function (method_ p k ~async:false ~generator:false))
      (* { a }: a: a; { a = 1 }, in a pattern: its default *)
      | Punct "=", Key x ->
          ignore (advance p);
          Prop (k, Assign ("=", Name x, expression p 1))
      | _, Key x -> Prop (k, Name x)
      | _, Computed _ -> unexpected p "':'")

(* f(a, b): what is after the "(" *)
and arguments (p : t) : expr list =
  let rec go acc =
    if is_punct p ")" then (ignore (advance p); List.rev acc)
    else
      let e = spread_or p in
      if is_punct p "," then (ignore (advance p); go (e :: acc))
      else (expect p ")"; List.rev (e :: acc))
  in
  go []

(* what a declaration or a parameter names: a name, or { } or [ ]
 * taking a value apart *)
and pattern (p : t) : pattern =
  match (peek p).kind with
  | Punct "{" ->
      ignore (advance p);
      let rec parts acc =
        if is_punct p "}" then (ignore (advance p); Object_pattern (List.rev acc, None))
        else if is_punct p "..." then (
          ignore (advance p);
          let r = pattern p in
          expect p "}";
          Object_pattern (List.rev acc, Some r))
        else
          let k = key p in
          (* { a }, or { a: its own pattern } *)
          let pt = if is_punct p ":" then (ignore (advance p); pattern p) else match k with Key x -> Bind x | Computed _ -> unexpected p "':'" in
          let part = (k, pt, default p) in
          if is_punct p "," then (ignore (advance p); parts (part :: acc))
          else (expect p "}"; Object_pattern (List.rev (part :: acc), None))
      in
      parts []
  | Punct "[" ->
      ignore (advance p);
      let rec parts acc =
        if is_punct p "]" then (ignore (advance p); Array_pattern (List.rev acc, None))
        else if is_punct p "," then (ignore (advance p); parts (None :: acc))
        else if is_punct p "..." then (
          ignore (advance p);
          let r = pattern p in
          expect p "]";
          Array_pattern (List.rev acc, Some r))
        else
          let pt = pattern p in
          let part = Some (pt, default p) in
          if is_punct p "," then (ignore (advance p); parts (part :: acc))
          else (expect p "]"; Array_pattern (List.rev (part :: acc), None))
      in
      parts []
  | _ -> Bind (name p)

(* "= e" after a pattern: what it is when there is no value *)
and default (p : t) : expr option = if is_punct p "=" then (ignore (advance p); Some (expression p 1)) else None

(* "(a, b = 1, ...rest)": the parameters, and the one taking the rest *)
and params (p : t) : (pattern * expr option) list * pattern option =
  expect p "(";
  let rec go acc =
    if is_punct p ")" then (ignore (advance p); (List.rev acc, None))
    else if is_punct p "..." then (
      ignore (advance p);
      let r = pattern p in
      expect p ")";
      (List.rev acc, Some r))
    else
      let pt = pattern p in
      let x = (pt, default p) in
      if is_punct p "," then (ignore (advance p); go (x :: acc))
      else (expect p ")"; (List.rev (x :: acc), None))
  in
  inside p (fun () -> go [])

(* x => ..., (a, b) => ...: a body in braces, or an expression returned *)
and arrow (p : t) ~(async : bool) : expr =
  let first = first_of p p.pos in
  let ps, rest = if is_punct p "(" then params p else ([ (Bind (name p), None) ], None) in
  let line = (peek p).line in
  expect p "=>";
  let body =
    body_in p ~async ~generator:false (fun () -> if is_punct p "{" then block_body p else [ { line; stmt = Return (Some (expression p 1)) } ])
  in
  (* (to the next token, less the blanks before it: its body may be an expression) *)
  let stop = ref (if p.pos < Array.length p.tokens then p.tokens.(p.pos).at else String.length p.text) in
  if p.text = "" then stop := first;
  while !stop > first && (match p.text.[!stop - 1] with ' ' | '\n' | '\t' | '\r' -> true | _ -> false) do decr stop done;
  Function { name = None; params = ps; rest; body; arrow = true; generator = false; async; frame = None; own_name = false; text = (if !stop > first then Some (p.text, first, !stop) else None) }

(* function name? (params) { body }: what is after the keyword *)
(* a function expression's name is its own, in its body *)
and named (f : func) : func = { f with own_name = f.name <> None }

(* where a function's text starts: at the token of that index, or at
 * the "async" before it *)
and first_of (p : t) (i : int) : int =
  let i = if i > 0 && p.tokens.(i - 1).kind = Name "async" then i - 1 else i in
  p.tokens.(min i (Array.length p.tokens - 1)).at

and func (p : t) ~(arrow : bool) ~(async : bool) : func =
  (* its text: from the keyword just read, to its body's last brace *)
  let first = first_of p (max 0 (p.pos - 1)) in
  (* function* f: a generator *)
  let generator = is_punct p "*" && (ignore (advance p); true) in
  let name = match (peek p).kind with Name x -> ignore (advance p); Some x | _ -> None in
  let ps, rest = params p in
  let body = body_in p ~async ~generator (fun () -> block_body p) in
  { name; params = ps; rest; body; arrow; generator; async; frame = None; own_name = false; text = (if p.text = "" then None else Some (p.text, first, p.tokens.(p.pos - 1).at + 1)) }

(* class Name extends Parent { members }: what is after the keyword. A
 * member: [static] then a method m() { }, an accessor get k() { } or
 * set k(v) { }, or a field k = e; the method called constructor is
 * the class's *)
and class_ (p : t) : class_ =
  let class_name = match (peek p).kind with Name x when x <> "extends" -> ignore (advance p); Some x | _ -> None in
  let parent = if (peek p).kind = Name "extends" then (ignore (advance p); Some (expression p prefix_power |> fun e -> loop p postfix_power e)) else None in
  expect p "{";
  let ctor = ref None in
  let rec members acc =
    if is_punct p "}" then (ignore (advance p); List.rev acc)
    else if is_punct p ";" then (ignore (advance p); members acc)
    else
      (* a word before a member's key, not the key itself: static x, get x() *)
      let modifier w = (peek p).kind = Name w && (match (peek_at p 1).kind with Punct ("(" | "=" | ";" | "}") -> false | _ -> true) in
      let static = modifier "static" && (ignore (advance p); true) in
      if static && is_punct p "{" then members ({ static; key = Key "static"; what = Static_block (block_body p) } :: acc)
      else
      let accessor = if modifier "get" then (ignore (advance p); Some Getter) else if modifier "set" then (ignore (advance p); Some Setter) else None in
      let async = modifier "async" && (ignore (advance p); true) in
      let generator = is_punct p "*" && (ignore (advance p); true) in
      let k = key p in
      let method_ () = method_ p k ~async ~generator in
      match (accessor, (peek p).kind, k) with
      | None, Punct "(", Key "constructor" when not static ->
          ctor := Some (method_ ());
          members acc
      | Some Getter, _, _ -> members ({ static; key = k; what = Get (method_ ()) } :: acc)
      | Some Setter, _, _ -> members ({ static; key = k; what = Set (method_ ()) } :: acc)
      | None, Punct "(", _ -> members ({ static; key = k; what = Method (method_ ()) } :: acc)
      | None, _, _ ->
          let init = default p in
          end_statement p;
          members ({ static; key = k; what = Field init } :: acc)
  in
  let members = members [] in
  { class_name; parent; ctor = !ctor; members }

(*****************************************************************************)
(* Statements: recursive descent *)
(*****************************************************************************)

(* "{ statements }" *)
and block_body (p : t) : stmt list =
  expect p "{";
  let rec go acc = if is_punct p "}" then (ignore (advance p); List.rev acc) else go (statement p :: acc) in
  (* a function's body in a for's first part: "in" is the operator there *)
  inside p (fun () -> go [])

(* a statement's end: ";", or before "}", the end, or a new line *)
and end_statement (p : t) : unit =
  let t = peek p in
  if is_punct p ";" then ignore (advance p)
  else if is_punct p "}" || t.kind = Eof || t.newline_before then ()
  else unexpected p "';' or a new line"

and let_kind (k : string) : let_kind = match k with "const" -> Const_kind | "var" -> Var_kind | _ -> Let_kind

(* let a = 1, b, { c } = o: after the keyword *)
and declarations (p : t) : (pattern * expr option) list =
  let rec go acc =
    let x = pattern p in
    let init = default p in
    if is_punct p "," then (ignore (advance p); go ((x, init) :: acc)) else List.rev ((x, init) :: acc)
  in
  go []

and statement (p : t) : stmt =
  (* a bundle of megabytes is seconds to read: the window drawn
   * meanwhile (Js_slice) -- if this is the window's run. A text read
   * aside (a worker of the pool: Js_module.ahead) must not: it would
   * end a slice of a run that is another thread's, which then ends
   * unseen, and the window waits for it for ever *)
  let t = peek p in
  let line = t.line in
  let s stmt = { line; stmt } in
  match t.kind with
  | Punct ";" -> ignore (advance p); s Empty
  | Punct "{" -> s (Block (block_body p))
  | Keyword (("let" | "const" | "var") as k) ->
      ignore (advance p);
      let ds = declarations p in
      end_statement p;
      s (Let (let_kind k, ds))
  | Keyword "function" | Name "async" when is_keyword p "function" || (peek_at p 1).kind = Keyword "function" ->
      let async = not (is_keyword p "function") in
      p.pos <- p.pos + if async then 2 else 1;
      let f = func p ~arrow:false ~async in
      if f.name = None then fail p "a function declaration needs a name";
      s (Function_decl f)
  | Keyword "return" ->
      ignore (advance p);
      (* return, then a new line: returns nothing *)
      let next = peek p in
      let value = if is_punct p ";" || is_punct p "}" || next.kind = Eof || next.newline_before then None else Some (expression p 0) in
      end_statement p;
      s (Return value)
  | Keyword "if" ->
      ignore (advance p);
      expect p "(";
      let c = expression p 0 in
      expect p ")";
      let a = statement p in
      let b = if is_keyword p "else" then (ignore (advance p); Some (statement p)) else None in
      s (If (c, a, b))
  (* with (o) body: with is a name, but before a ( at a statement's start *)
  | Name "with" when (peek_at p 1).kind = Punct "(" ->
      ignore (advance p);
      expect p "(";
      let o = inside p (fun () -> expression p 0) in
      expect p ")";
      s (With (o, statement p))
  | Keyword "while" ->
      ignore (advance p);
      expect p "(";
      let c = expression p 0 in
      expect p ")";
      s (While (c, statement p))
  | Keyword "for" ->
      ignore (advance p);
      (* for await (x of xs) *)
      let awaited = (peek p).kind = Name "await" && (ignore (advance p); true) in
      expect p "(";
      s (match (awaited, for_rest p) with true, For_of (k, x, xs, b) -> For_await (k, x, xs, b) | _, st -> st)
  | Keyword (("break" | "continue") as k) ->
      ignore (advance p);
      (* its label, if one follows on the line *)
      let label = match (peek p).kind with Name l when not (peek p).newline_before -> ignore (advance p); Some l | _ -> None in
      end_statement p;
      s (if k = "break" then Break label else Continue label)
  | Keyword "do" ->
      ignore (advance p);
      let body = statement p in
      if not (is_keyword p "while") then unexpected p "while";
      ignore (advance p);
      expect p "(";
      let c = expression p 0 in
      expect p ")";
      if is_punct p ";" then ignore (advance p);
      s (Do_while (body, c))
  | Keyword "switch" ->
      ignore (advance p);
      expect p "(";
      let e = expression p 0 in
      expect p ")";
      expect p "{";
      (* a case's statements: up to the next case, default or } *)
      let rec body acc = if is_keyword p "case" || is_keyword p "default" || is_punct p "}" then List.rev acc else body (statement p :: acc) in
      let rec cases acc =
        if is_punct p "}" then (ignore (advance p); List.rev acc)
        else if is_keyword p "case" then (
          ignore (advance p);
          let test = expression p 0 in
          expect p ":";
          cases ((Some test, body []) :: acc))
        else if is_keyword p "default" then (
          ignore (advance p);
          expect p ":";
          cases ((None, body []) :: acc))
        else unexpected p "case, default or '}'"
      in
      s (Switch (e, cases []))
  (* a label: "outer: for (...)" *)
  | Name l when (peek_at p 1).kind = Punct ":" ->
      p.pos <- p.pos + 2;
      s (Labeled (l, statement p))
  | Keyword "throw" ->
      ignore (advance p);
      let e = expression p 0 in
      end_statement p;
      s (Throw e)
  | Keyword "try" ->
      ignore (advance p);
      let body = block_body p in
      let handler =
        if is_keyword p "catch" then (
          ignore (advance p);
          (* catch (e) { }, or catch { } *)
          let x = if is_punct p "(" then (ignore (advance p); let x = name p in expect p ")"; Some x) else None in
          Some (x, block_body p))
        else None
      in
      let finally = if is_keyword p "finally" then (ignore (advance p); Some (block_body p)) else None in
      if handler = None && finally = None then unexpected p "catch or finally";
      s (Try (body, handler, finally))
  | Keyword "class" ->
      ignore (advance p);
      let c = class_ p in
      if c.class_name = None then fail p "a class declaration needs a name";
      s (Class_decl c)
  (* a module's: import and export are names, and statements only
   * where what follows cannot go on an expression *)
  | Name "import" when (match (peek_at p 1).kind with String _ | Name _ | Punct ("{" | "*") -> true | _ -> false) ->
      ignore (advance p);
      s (import p)
  | Name "export" when (match (peek_at p 1).kind with Keyword _ | Punct ("{" | "*") | Name "async" -> true | _ -> false) ->
      ignore (advance p);
      s (Export (export p))
  | _ ->
      let e = expression p 0 in
      end_statement p;
      s (Expr e)

(* a name in an import's or an export's list: any word (default is one) *)
and word (p : t) : string =
  match (advance p).kind with
  | Name x | Keyword x -> x
  | String x -> x
  | _ ->
      p.pos <- p.pos - 1;
      unexpected p "a name"

(* { a, b as c }: each (a, a) or (b, c) *)
and name_list (p : t) : (string * string) list =
  expect p "{";
  let rec go acc =
    if is_punct p "}" then (ignore (advance p); List.rev acc)
    else
      let a = word p in
      let b = if (peek p).kind = Name "as" then (ignore (advance p); word p) else a in
      if is_punct p "," then ignore (advance p);
      go ((a, b) :: acc)
  in
  go []

and from (p : t) : string =
  if (peek p).kind <> Name "from" then unexpected p "from";
  ignore (advance p);
  match (advance p).kind with
  | String s ->
      (* with { type: "json" }: read and dropped *)
      if (peek p).kind = Keyword "with" || (peek p).kind = Name "assert" then (ignore (advance p); ignore (block_skip p));
      s
  | _ ->
      p.pos <- p.pos - 1;
      unexpected p "a module's address"

and block_skip (p : t) : unit =
  expect p "{";
  while not (is_punct p "}" || (peek p).kind = Eof) do ignore (advance p) done;
  expect p "}"

(* after "import": "m"; d from "m"; * as ns from "m"; { a, b as c } from "m"; d, { a } from "m" *)
and import (p : t) : statement =
  match (peek p).kind with
  | String s ->
      ignore (advance p);
      end_statement p;
      Import ({ default = None; namespace = None; named = [] }, s)
  | _ ->
      let default = match (peek p).kind with Name _ -> let d = name p in if is_punct p "," then ignore (advance p); Some d | _ -> None in
      let namespace =
        if is_punct p "*" then (
          ignore (advance p);
          if (peek p).kind <> Name "as" then unexpected p "as";
          ignore (advance p);
          Some (name p))
        else None
      in
      let named = if is_punct p "{" then name_list p else [] in
      let m = from p in
      end_statement p;
      Import ({ default; namespace; named }, m)

(* after "export" *)
and export (p : t) : export =
  let line = (peek p).line in
  match (peek p).kind with
  | Keyword "default" -> (
      ignore (advance p);
      let async = (peek p).kind = Name "async" && (peek_at p 1).kind = Keyword "function" in
      if is_keyword p "function" || async then (
        p.pos <- p.pos + if async then 2 else 1;
        let f = func p ~arrow:false ~async in
        if f.name = None then Export_default (Function f) else Export_default_decl { line; stmt = Function_decl f })
      else if is_keyword p "class" then (
        ignore (advance p);
        let c = class_ p in
        if c.class_name = None then Export_default (Class c) else Export_default_decl { line; stmt = Class_decl c })
      else
        let e = expression p 1 in
        end_statement p;
        Export_default e)
  | Punct "*" ->
      ignore (advance p);
      let ns = if (peek p).kind = Name "as" then (ignore (advance p); Some (word p)) else None in
      let m = from p in
      end_statement p;
      Export_all (ns, m)
  | Punct "{" ->
      let names = name_list p in
      let m = if (peek p).kind = Name "from" then Some (from p) else None in
      end_statement p;
      Export_names (names, m)
  | _ -> Export_decl (statement p)

(* for (let x of xs) body, or for (init; test; update) body: what is
 * after the "(" *)
and for_rest (p : t) : statement =
  let line = (peek p).line in
  match (peek p).kind with
  (* for (let x of xs), for (let k in o), or for (let i = 0, ...; ; ):
   * told after the first thing declared *)
  | Keyword (("let" | "const" | "var") as k) -> (
      ignore (advance p);
      let first = pattern p in
      match ((peek p).kind, first) with
      | Name "of", _ ->
          ignore (advance p);
          let xs = expression p 1 in
          expect p ")";
          For_of (let_kind k, first, xs, statement p)
      | Keyword "in", Bind x ->
          ignore (advance p);
          let o = expression p 0 in
          expect p ")";
          For_in (Declared (let_kind k, x), o, statement p)
      | _ ->
          (* "in", in what follows, is the for's: not the operator *)
          p.no_in <- true;
          let init = default p in
          let more = if is_punct p "," then (ignore (advance p); declarations p) else [] in
          p.no_in <- false;
          for_parts p (Some { line; stmt = Let (let_kind k, (first, init) :: more) }))
  | Punct ";" -> for_parts p None
  | _ ->
      p.no_in <- true;
      let e = expression p 0 in
      p.no_in <- false;
      if is_keyword p "in" then (
        ignore (advance p);
        let o = expression p 0 in
        expect p ")";
        For_in (Target (target p e), o, statement p))
      else if (peek p).kind = Name "of" then (
        (* for (x of xs): into a name already declared *)
        ignore (advance p);
        let xs = expression p 1 in
        expect p ")";
        match e with Name x -> For_of (Var_kind, Bind x, xs, statement p) | _ -> fail p "for (... of): a name")
      else for_parts p (Some { line; stmt = Expr e })

(* for (init; test; update) body: after the first part *)
and for_parts (p : t) (init : stmt option) : statement =
  expect p ";";
  let test = if is_punct p ";" then None else Some (expression p 0) in
  expect p ";";
  let update = if is_punct p ")" then None else Some (expression p 0) in
  expect p ")";
  For (init, test, update, statement p)

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

let with_tokens ~(aside : bool) (text : string) (f : t -> 'a) : ('a, error) result =
  match Js_lexer.tokenize text with
  | exception Js_lexer.Error (line, message) -> Error { line; message }
  | tokens -> (
      let p = { text; tokens = Array.of_list tokens; pos = 0; aside; no_in = false; in_async = false; in_generator = false } in
      match f p with x -> Ok x | exception Parse_error e -> Error e)

let parse_with ~(aside : bool) (text : string) : (program, error) result =
  with_tokens ~aside text (fun p ->
      let rec go acc = if (peek p).kind = Eof then List.rev acc else go (statement p :: acc) in
      go [])

let parse (text : string) : (program, error) result = parse_with ~aside:false text

let parse_expression (text : string) : (expr, error) result =
  with_tokens ~aside:false text (fun p ->
      let e = expression p 0 in
      if (peek p).kind <> Eof then unexpected p "the end";
      e)
