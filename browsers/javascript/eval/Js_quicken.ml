(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/eval/Js_quicken.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_quicken.mli *)
open Js_ast

(* whether the function being copied says arguments: a call makes
 * that array only then (Js_frame) *)
let says_arguments_here = Per_domain.make (fun () -> ref false)

let rec expr (e : expr) : expr =
  match e with
  | Name x ->
      if x = "arguments" then says_arguments_here () := true;
      Local (x, place ())
  | Local (x, _) ->
      if x = "arguments" then says_arguments_here () := true;
      e
  | Number _ | String _ | Bool _ | Null | This | Regex _ | Super_member _ | Import_meta -> e
  | Unary (op, a) -> Unary (op, expr a)
  | Update (op, prefix, a) -> Update (op, prefix, expr a)
  | Binary (op, a, b) -> Binary (op, expr a, expr b)
  | Logical (op, a, b) -> Logical (op, expr a, expr b)
  | Assign (op, a, b) -> Assign (op, expr a, expr b)
  | Conditional (c, a, b) -> Conditional (expr c, expr a, expr b)
  | Comma (a, b) -> Comma (expr a, expr b)
  | Member (a, k) -> Member (expr a, k)
  | Index (a, k) -> Index (expr a, expr k)
  | Call (f, args) -> Call (expr f, List.map expr args)
  | New (f, args) -> New (expr f, List.map expr args)
  | Function f -> Function (func f)
  | Array es -> Array (List.map expr es)
  | Object props -> Object (List.map property props)
  | Template (strings, es) -> Template (strings, List.map expr es)
  | Spread a -> Spread (expr a)
  | Tagged (tag, strings, es) -> Tagged (expr tag, strings, List.map expr es)
  | Yield (all, a) -> Yield (all, Option.map expr a)
  | Class c -> Class (class_ c)
  | Super_call args -> Super_call (List.map expr args)
  | Opt a -> Opt (expr a)
  | Optional a -> Optional (expr a)
  | Await a -> Await (expr a)
  | Import_call a -> Import_call (expr a)

(* a function: its parts, then what its calls have in common *)
and func (f : func) : func =
  (* an arrow's arguments are those of the function around it *)
  let around = !(says_arguments_here ()) in
  if not f.arrow then says_arguments_here () := false;
  let f = { f with params = List.map (fun (pt, d) -> (pattern pt, Option.map expr d)) f.params; rest = Option.map pattern f.rest; body = List.map stmt f.body } in
  let arguments = !(says_arguments_here ()) in
  if not f.arrow then says_arguments_here () := around;
  { f with frame = Some (Js_frame.layout_with ~arguments f) }

and key (k : key) : key = match k with Key _ -> k | Computed e -> Computed (expr e)

and property (p : property) : property =
  match p with
  | Prop (k, v) -> Prop (key k, expr v)
  | Getter (k, f) -> Getter (key k, func f)
  | Setter (k, f) -> Setter (key k, func f)
  | Spread_prop e -> Spread_prop (expr e)

and class_ (c : class_) : class_ =
  let member (m : member) : member =
    let what =
      match m.what with
      | Method f -> Method (func f)
      | Get f -> Get (func f)
      | Set f -> Set (func f)
      | Field e -> Field (Option.map expr e)
      | Static_block body -> Static_block (List.map stmt body)
    in
    { m with key = key m.key; what }
  in
  { c with parent = Option.map expr c.parent; ctor = Option.map func c.ctor; members = List.map member c.members }

(* a pattern's names stay names: its keys and defaults are expressions *)
and pattern (pt : pattern) : pattern =
  match pt with
  | Bind _ -> pt
  | Object_pattern (parts, rest) -> Object_pattern (List.map (fun (k, pt, d) -> (key k, pattern pt, Option.map expr d)) parts, Option.map pattern rest)
  | Array_pattern (parts, rest) -> Array_pattern (List.map (Option.map (fun (pt, d) -> (pattern pt, Option.map expr d))) parts, Option.map pattern rest)

and stmt (st : stmt) : stmt = { st with stmt = statement st.stmt }

and statement (st : statement) : statement =
  let body = List.map stmt in
  match st with
  | Expr e -> Expr (expr e)
  (* var a = 1, b: plain names, each given a place *)
  | Let (Var_kind, decls) when List.for_all (fun (pt, _) -> match pt with Bind _ -> true | _ -> false) decls ->
      Var_set (List.concat_map (fun (pt, init) -> match pt with Bind x -> [ (x, place (), Option.map expr init) ] | _ -> []) decls)
  | Let (kind, decls) -> Let (kind, List.map (fun (pt, init) -> (pattern pt, Option.map expr init)) decls)
  | Var_set _ | Break _ | Continue _ | Empty | Import _ -> st
  | Function_decl f -> Function_decl (func f)
  | Return e -> Return (Option.map expr e)
  | If (c, a, b) -> If (expr c, stmt a, Option.map stmt b)
  | While (c, b) -> While (expr c, stmt b)
  | For (init, test, update, b) -> For (Option.map stmt init, Option.map expr test, Option.map expr update, stmt b)
  | For_in (target, o, b) -> For_in ((match target with Declared _ -> target | Target e -> Target (expr e)), expr o, stmt b)
  | Block b -> Block (body b)
  | With (o, b) -> With (expr o, stmt b)
  | Do_while (b, c) -> Do_while (stmt b, expr c)
  | Switch (e, cases) -> Switch (expr e, List.map (fun (test, b) -> (Option.map expr test, body b)) cases)
  | Labeled (l, b) -> Labeled (l, stmt b)
  | Throw e -> Throw (expr e)
  | Try (b, handler, finally) -> Try (body b, Option.map (fun (x, h) -> (x, body h)) handler, Option.map body finally)
  | For_of (kind, x, xs, b) -> For_of (kind, pattern x, expr xs, stmt b)
  | For_await (kind, x, xs, b) -> For_await (kind, pattern x, expr xs, stmt b)
  | Class_decl c -> Class_decl (class_ c)
  | Export (Export_decl st) -> Export (Export_decl (stmt st))
  | Export (Export_default e) -> Export (Export_default (expr e))
  | Export (Export_default_decl st) -> Export (Export_default_decl (stmt st))
  | Export (Export_names _ | Export_all _) -> st

let program (p : program) : program = List.map stmt p
