(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/parsing/Js_ast.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_ast.mli *)

(* ix: an exception's value where mini-chrome has an open type (type code = ..), which mini-ml has not *)
type code = No_code | Code of exn

type place = { mutable hops : int; mutable slot : int }

let place () : place = { hops = -1; slot = 0 }

type expr = [%mli]

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
