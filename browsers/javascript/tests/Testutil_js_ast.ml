(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/parsing/Js_ast.ml's printing (its 8af888e), a test's only (docs/plans/plan_browser.md) *)

(* See Testutil_js_ast.mli *)

open Js_ast

let kind_to_string (k : let_kind) : string = match k with Let_kind -> "Let" | Const_kind -> "Const" | Var_kind -> "Var"
let list (f : 'a -> string) (xs : 'a list) : string = String.concat ", " (List.map f xs)

let rec expr_to_string (e : expr) : string =
  let p = Printf.sprintf in
  match e with
  | Number f -> number_to_string f
  | String s -> p "%S" s
  | Bool b -> string_of_bool b
  | Null -> "null"
  | Name x | Local (x, _) -> x
  | This -> "this"
  | Array es -> p "[%s]" (list expr_to_string es)
  | Object props ->
      p "{%s}"
        (list
           (fun pr ->
             match pr with
             | Prop (k, v) -> key_to_string k ^ ": " ^ expr_to_string v
             | Getter (k, f) -> "get " ^ key_to_string k ^ ": " ^ func_to_string f
             | Setter (k, f) -> "set " ^ key_to_string k ^ ": " ^ func_to_string f
             | Spread_prop e -> "..." ^ expr_to_string e)
           props)
  | Function { arrow = true; async; params; rest = None; body = [ { stmt = Return (Some e); _ } ]; _ } ->
      p "%s(%s) => %s" (if async then "async " else "") (list param_to_string params) (expr_to_string e)
  | Spread e -> "..." ^ expr_to_string e
  | Tagged (tag, strings, es) -> p "%s`%s`%s" (expr_to_string tag) (String.concat "${}" strings) (if es = [] then "" else p " [%s]" (list expr_to_string es))
  | Yield (delegate, e) -> p "(yield%s%s)" (if delegate then "*" else "") (match e with Some e -> " " ^ expr_to_string e | None -> "")
  | Opt e -> expr_to_string e ^ "?"
  | Optional e -> expr_to_string e
  | Await e -> p "(await %s)" (expr_to_string e)
  | Class c -> class_to_string c
  | Super_call args -> p "(super(%s))" (list expr_to_string args)
  | Super_member k -> "(super." ^ k ^ ")"
  | Function f -> func_to_string f
  | Unary (("typeof" as op), e) -> p "(%s %s)" op (expr_to_string e)
  | Unary (op, e) -> p "(%s%s)" op (expr_to_string e)
  | Update (op, true, e) -> p "(%s%s)" op (expr_to_string e)
  | Update (op, false, e) -> p "(%s%s)" (expr_to_string e) op
  | Binary (op, a, b) | Logical (op, a, b) | Assign (op, a, b) -> p "(%s %s %s)" (expr_to_string a) op (expr_to_string b)
  | Conditional (c, a, b) -> p "(%s ? %s : %s)" (expr_to_string c) (expr_to_string a) (expr_to_string b)
  | Member (o, x) -> p "(%s.%s)" (expr_to_string o) x
  | Index (o, i) -> p "(%s[%s])" (expr_to_string o) (expr_to_string i)
  | Call (f, args) -> p "(%s(%s))" (expr_to_string f) (list expr_to_string args)
  | New (f, args) -> p "(new %s(%s))" (expr_to_string f) (list expr_to_string args)
  | Regex (r, f) -> p "/%s/%s" r f
  | Comma (a, b) -> p "(%s, %s)" (expr_to_string a) (expr_to_string b)
  | Template (strings, es) -> p "`%s`" (String.concat "${}" strings) ^ if es = [] then "" else p " [%s]" (list expr_to_string es)

and class_to_string (c : class_) : string =
  Printf.sprintf "Class%s%s {%s}"
    (match c.class_name with Some n -> " " ^ n | None -> "")
    (match c.parent with Some e -> " extends " ^ expr_to_string e | None -> "")
    (String.concat "; "
       ((match c.ctor with Some f -> [ "constructor " ^ func_to_string f ] | None -> [])
       @ List.map
           (fun (m : member) ->
             (if m.static then "static " else "")
             ^ key_to_string m.key
             ^ match m.what with
               | Method f -> " " ^ func_to_string f
               | Get f -> " get " ^ func_to_string f
               | Set f -> " set " ^ func_to_string f
               | Field (Some e) -> " = " ^ expr_to_string e
               | Field None -> ""
               | Static_block body -> " " ^ body_to_string body)
           c.members))

and key_to_string (k : key) : string = match k with Key k -> k | Computed e -> "[" ^ expr_to_string e ^ "]"

and pattern_to_string (pt : pattern) : string =
  let rest r = match r with Some r -> [ "..." ^ pattern_to_string r ] | None -> [] in
  match pt with
  | Bind x -> x
  | Object_pattern (parts, r) ->
      "{" ^ String.concat ", " (List.map (fun (k, pt, d) -> key_to_string k ^ ": " ^ param_to_string (pt, d)) parts @ rest r) ^ "}"
  | Array_pattern (parts, r) ->
      "[" ^ String.concat ", " (List.map (fun part -> match part with Some part -> param_to_string part | None -> "") parts @ rest r) ^ "]"

and param_to_string ((pt, default) : pattern * expr option) : string =
  pattern_to_string pt ^ match default with Some d -> " = " ^ expr_to_string d | None -> ""

and func_to_string (f : func) : string =
  Printf.sprintf "%s%s [%s] [%s]"
    ((if f.async then "Async " else "") ^ if f.arrow then "Arrow" else if f.generator then "Generator" else "Function")
    (match f.name with Some n -> " " ^ n | None -> "")
    (String.concat "; " (List.map param_to_string f.params @ match f.rest with Some r -> [ "..." ^ pattern_to_string r ] | None -> []))
    (body_to_string f.body)

and body_to_string (body : stmt list) : string = String.concat "; " (List.map stmt_to_string body)

and stmt_to_string (s : stmt) : string =
  let p = Printf.sprintf in
  let e = expr_to_string in
  let opt f x = match x with Some x -> f x | None -> "none" in
  match s.stmt with
  | Expr x -> "Expr " ^ e x
  | Let (k, decls) ->
      kind_to_string k ^ " " ^ list (fun (x, init) -> match init with Some v -> pattern_to_string x ^ " " ^ e v | None -> pattern_to_string x) decls
  | Var_set decls -> "Var " ^ list (fun (x, _, init) -> match init with Some v -> x ^ " " ^ e v | None -> x) decls
  | Function_decl f -> func_to_string f
  | Class_decl c -> class_to_string c
  | Return None -> "Return"
  | Return (Some x) -> "Return " ^ e x
  | If (c, a, None) -> p "If (%s, %s)" (e c) (stmt_to_string a)
  | If (c, a, Some b) -> p "If (%s, %s, %s)" (e c) (stmt_to_string a) (stmt_to_string b)
  | While (c, b) -> p "While (%s, %s)" (e c) (stmt_to_string b)
  | With (o, b) -> p "With (%s, %s)" (e o) (stmt_to_string b)
  | For (init, test, update, b) ->
      p "For (%s, %s, %s, %s)" (opt stmt_to_string init) (opt e test) (opt e update) (stmt_to_string b)
  | For_await (k, x, xs, b) -> "await " ^ stmt_to_string { s with stmt = For_of (k, x, xs, b) }
  | For_of (k, x, xs, b) -> p "For_of (%s %s, %s, %s)" (kind_to_string k) (pattern_to_string x) (e xs) (stmt_to_string b)
  | For_in (Declared (k, x), o, b) -> p "For_in (%s %s, %s, %s)" (kind_to_string k) x (e o) (stmt_to_string b)
  | For_in (Target x, o, b) -> p "For_in (%s, %s, %s)" (e x) (e o) (stmt_to_string b)
  | Do_while (b, c) -> p "Do_while (%s, %s)" (stmt_to_string b) (e c)
  | Switch (x, cases) ->
      p "Switch (%s, %s)" (e x)
        (list (fun (test, body) -> p "%s [%s]" (match test with Some t -> "case " ^ e t | None -> "default") (body_to_string body)) cases)
  | Labeled (l, b) -> p "%s: %s" l (stmt_to_string b)
  | Break None -> "Break"
  | Break (Some l) -> "Break " ^ l
  | Continue None -> "Continue"
  | Continue (Some l) -> "Continue " ^ l
  | Throw x -> "Throw " ^ e x
  | Try (body, handler, finally) ->
      p "Try [%s]%s%s" (body_to_string body)
        (match handler with Some (x, h) -> p " catch %s [%s]" ((match x with Some v_ -> v_ | None -> "_")) (body_to_string h) | None -> "")
        (match finally with Some f -> p " finally [%s]" (body_to_string f) | None -> "")
  | Block body -> p "Block [%s]" (body_to_string body)
  | Empty -> "Empty"
