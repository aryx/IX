(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Tiger's tree, as the grammar (Tiger_parser) makes it: Appel's
 * Absyn (Modern Compiler Implementation in ML, chapter 4), with
 * fork-tiger's exceptions (exception, raise, try ... handle). The `&`
 * and `|` of the text are already ifs, and -e is 0 - e, as Appel's
 * parser makes them. A place is its line and column, for the errors. *)

type pos = int * int

type exp =
  | Nil of pos
  | Int of int32 * pos
  | String of string * pos
  | Var of var
  | Op of exp * oper * exp * pos
  | Call of string * exp list * pos
  | Record of string * (string * exp * pos) list * pos
  | Array of string * exp * exp * pos     (* type [size] of init *)
  | Seq of exp list * pos
  | Assign of var * exp * pos
  | If of exp * exp * exp option * pos
  | While of exp * exp * pos
  | For of string * exp * exp * exp * pos
  | Break of pos
  | Let of dec list * exp * pos
  | Try of exp * (string * exp * pos) list * pos
  | Raise of string * pos

and var =
  | Simple of string * pos
  | Field of var * string * pos
  | Subscript of var * exp * pos

and oper = Plus | Minus | Times | Divide | Eq | Neq | Lt | Le | Gt | Ge

and dec =
  | VarDec of string * (string * pos) option * exp * pos
  | TypeDecs of (string * ty * pos) list          (* a group: they may name each other *)
  | FunDecs of fundec list                        (* the same *)
  | ExnDec of string * pos

and ty =
  | NameTy of string * pos
  | RecordTy of (string * string * pos) list     (* a field's name, its type's *)
  | ArrayTy of string * pos

and fundec = {
  fname : string;
  params : (string * string * pos) list;
  result : (string * pos) option;
  body : exp;
  fpos : pos;
}
