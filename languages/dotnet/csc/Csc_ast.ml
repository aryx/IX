(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The reduced C#'s tree, as Csc_parser makes it (plan_dotnet.md,
 * decision 11): classes and interfaces, their fields, methods,
 * constructors and properties with a getter; the statements and
 * expressions of C# 1 with foreach. No structs, generics of the
 * program's own, lambdas, interpolation, switch. A place is a line. *)

type pos = int

type ty =
  | Named of string list * ty list        (* System.Text.StringBuilder, List<int> *)
  | Array of ty
  | Byref of ty                             (* a parameter out or ref *)

type modifier =
  | Public | Private | Protected | Internal | Static | Abstract
  | Virtual | Override | Sealed | New | Readonly

type expr = { e : desc; pos : pos }

and desc =
  | Int of int32
  | Long of int64
  | Double of float
  | Str of string
  | Char of int
  | Bool of bool
  | Null
  | Name of string
  | This
  | Base
  | Member of expr * string                   (* e.name *)
  | Call of expr * expr list                  (* f(args): f a Name or a Member *)
  | Index of expr * expr
  | New of ty * expr list                     (* new T(args) *)
  | New_array of ty * expr                    (* new T[n] *)
  | Array_init of ty * expr list              (* new T[] { ... } *)
  | Unary of string * expr                    (* - ! *)
  | Binary of string * expr * expr            (* + - * / % == != < <= > >= && || *)
  | Assign of string * expr * expr            (* = += -= *= /= %= *)
  | Incr of bool * bool * expr                (* ++ or --, prefix?, the place *)
  | Cast of ty * expr
  | Is of expr * ty
  | Cond of expr * expr * expr
  | Typed_name of ty                          (* int.Parse: a type before a dot *)
  | Out of expr                               (* an argument out or ref: its address *)

type stmt = { s : sdesc; spos : pos }

and sdesc =
  | Block of stmt list
  | Local of ty * (string * expr option) list
  | Expr of expr
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | Do of stmt * expr
  | For of stmt list * expr option * expr list * stmt
  | Foreach of ty * string * expr * stmt
  | Return of expr option
  | Break
  | Continue
  | Throw of expr option
  | Try of stmt * (ty * string option * stmt) list * stmt option
  | Empty

type member =
  | Field of modifier list * ty * (string * expr option) list * pos
  | Method of modifier list * ty * string * (ty * string) list * stmt option * pos
  | Ctor of modifier list * string * (ty * string) list * (bool * expr list) option * stmt * pos
      (* : base(args) (true) or : this(args) *)
  | Property of modifier list * ty * string * stmt option * pos   (* its getter *)

type class_decl = {
  cname : string;
  interface : bool;
  cmods : modifier list;
  bases : ty list;
  members : member list;
  cpos : pos;
}

type program = { usings : string list list; classes : class_decl list }
