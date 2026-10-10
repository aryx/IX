(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's languages/javascript/parsing/Js_ast.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_ast.mli *)

(* ix: an exception's value where mini-chrome has an open type (type code = ..), which mini-ml has not *)
type code = No_code | Code of exn

type place = { mutable hops : int; mutable slot : int }

let place () : place = { hops = -1; slot = 0 }

type expr =
  | Number of float
  | String of string
  | Bool of bool
  | Null
  | Name of string
  | Local of string * place
  | This
  | Unary of string * expr
  | Update of string * bool * expr
  | Binary of string * expr * expr
  | Logical of string * expr * expr
  | Assign of string * expr * expr
  | Conditional of expr * expr * expr
  | Comma of expr * expr
  | Member of expr * string
  | Index of expr * expr
  | Call of expr * expr list
  | New of expr * expr list
  | Function of func
  | Array of expr list
  | Object of property list
  | Regex of string * string
  | Template of string list * expr list
  | Spread of expr
  | Tagged of expr * string list * expr list
  | Yield of bool * expr option
  | Class of class_
  | Super_call of expr list
  | Super_member of string
  | Opt of expr
  | Optional of expr
  | Await of expr
  | Import_call of expr (* import("m"): a promise of the module's names *)
  | Import_meta (* import.meta: what a module knows of itself, its url *)

and func = {
  name : string option;
  params : (pattern * expr option) list;
  rest : pattern option;
  body : stmt list;
  arrow : bool;
  generator : bool;
  async : bool;
  frame : frame option;
  own_name : bool;
  (* its own text: the program's, and where the function starts and
   * ends in it (f.toString(), which a page may read, compare, or
   * evaluate again) *)
  text : (string * int * int) option;
}

and frame = { names : string array; index : (string, int) Hashtbl.t option; slots : int array; plain : bool; own : int; arguments : bool; mutable code : code }

and property =
  | Prop of key * expr
  | Getter of key * func
  | Setter of key * func
  | Spread_prop of expr

and key = Key of string | Computed of expr

and class_ = { class_name : string option; parent : expr option; ctor : func option; members : member list }

and member = { static : bool; key : key; what : member_kind }
and member_kind = Method of func | Get of func | Set of func | Field of expr option | Static_block of stmt list

and pattern =
  | Bind of string
  | Object_pattern of (key * pattern * expr option) list * pattern option
  | Array_pattern of (pattern * expr option) option list * pattern option

and stmt = { line : int; stmt : statement }

and statement =
  | Expr of expr
  | Let of let_kind * (pattern * expr option) list
  | Var_set of (string * place * expr option) list
  | Function_decl of func
  | Return of expr option
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | For of stmt option * expr option * expr option * stmt
  | For_in of for_target * expr * stmt
  | Break of string option
  | Continue of string option
  | Block of stmt list
  | Empty
  | With of expr * stmt
  | Do_while of stmt * expr
  | Switch of expr * (expr option * stmt list) list
  | Labeled of string * stmt
  | Throw of expr
  | Try of stmt list * (string option * stmt list) option * stmt list option
  | For_of of let_kind * pattern * expr * stmt
  | For_await of let_kind * pattern * expr * stmt
  | Class_decl of class_
  | Import of import_names * string (* import ... from "m": a module's first lines *)
  | Export of export

(* import d, * as ns, { a, b as c } from "m": the default's name here,
 * the name of the whole, and each (name there, name here) *)
and import_names = { default : string option; namespace : string option; named : (string * string) list }

and export =
  | Export_decl of stmt (* export const x = 1, export function f, export class C *)
  | Export_default of expr (* export default e *)
  | Export_default_decl of stmt (* export default function f / class C: named here too *)
  | Export_names of (string * string) list * string option (* export { a, b as c } [from "m"]: (name here or there, name out) *)
  | Export_all of string option * string (* export * [as ns] from "m" *)

and for_target = Declared of let_kind * string | Target of expr

and let_kind = Let_kind | Const_kind | Var_kind

type program = stmt list

(*****************************************************************************)
(* Numbers *)
(*****************************************************************************)

(* the shortest of 15, 16 and 17 significant digits that reads back as
   the same float: 17 always do (a double's 53 bits), fewer usually do,
   and a person wants 0.1, not 0.10000000000000001 *)
let number_to_string (f : float) : string =
  if Float.is_nan f then "NaN"
  else if f = infinity then "Infinity"
  else if f = neg_infinity then "-Infinity"
  (* an integer a float holds exactly: written as one (no printf: a
   * program that draws writes ten thousand a frame) *)
  else if Float.is_integer f && Float.abs f < 9007199254740992. then string_of_int (Float.to_int f)
  else
    let shortest = List.find (fun p -> float_of_string (Printf.sprintf "%.*g" p f) = f) [ 15; 16; 17 ] in
    if Float.is_integer f && Float.abs f < 1e21 then (
      (* an integer past 2^53: the shortest digits that say it, then
       * zeros (9223372036854776000, not ...775808) *)
      let all = Printf.sprintf "%.0f" f in
      let sign = if f < 0. then 1 else 0 in
      String.mapi (fun i c -> if i - sign >= shortest then '0' else c) (Printf.sprintf "%.*e" (shortest - 1) f |> fun e -> String.concat "" (String.split_on_char '.' (List.hd (String.split_on_char 'e' e))) ^ String.make (max 0 (String.length all - shortest - sign)) '0'))
    else Printf.sprintf "%.*g" shortest f

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

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
  | Import_call e -> p "import(%s)" (expr_to_string e)
  | Import_meta -> "import.meta"
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
  | Import (n, from) ->
      p "Import (%s) from %S"
        (String.concat ", "
           ((match n.default with Some d -> [ "default as " ^ d ] | None -> [])
           @ (match n.namespace with Some ns -> [ "* as " ^ ns ] | None -> [])
           @ List.map (fun (a, b) -> if a = b then a else a ^ " as " ^ b) n.named))
        from
  | Export (Export_decl st) -> "Export " ^ stmt_to_string st
  | Export (Export_default x) -> "Export default " ^ e x
  | Export (Export_default_decl st) -> "Export default " ^ stmt_to_string st
  | Export (Export_names (names, from)) ->
      p "Export (%s)%s" (String.concat ", " (List.map (fun (a, b) -> if a = b then a else a ^ " as " ^ b) names)) (match from with Some f -> p " from %S" f | None -> "")
  | Export (Export_all (ns, from)) -> p "Export *%s from %S" (match ns with Some n -> " as " ^ n | None -> "") from
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
