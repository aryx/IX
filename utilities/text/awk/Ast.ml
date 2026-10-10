(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* awk's programs as trees, and the cells they name: what awkgram.y
 * builds of Node and Cell (awk.h), with a constructor where the C has
 * a token's number and four untyped arguments. *)

(* A cell: a variable, a constant, a field, an array's element or a
 * value being computed. awk.h's Cell, its tval's bits said: a scalar
 * has a number, a string or both valid at once, and using it one way
 * may make the other valid too (a field that looks like a number is
 * one from then on); so an expression's value is its cell, not a copy. *)
type cell = { name : string; mutable v : contents; kind : kind }

and kind =
  | Variable
  | Constant      (* a program's number or string: never made a number by its use *)
  | Field of int  (* $n; 0: the record *)
  | Temporary

and contents =
  | Scalar of value
  | Array of table
  | Function of func

and value = { num : bool; str : bool; f : float; s : string }

(* a symbol table, and an array: tran.c's hash table as it is, since
 * for (k in a) goes through it in its order *)
and table = { mutable size : int; mutable count : int; mutable buckets : cell list array }

(* its parameters' number: the call's cells past the arguments given are locals *)
and func = { params : int; body : stmt }

and expr =
  | Const of cell
  | Var of cell
  | Arg of int
  | Nf
  | Field_of of expr
  (* a[i, j]: the array's name (Var, Arg), the subscripts *)
  | Elem of expr * expr list
  | Assign of assign * expr * expr
  | Cond of expr * expr * expr
  | Or of expr * expr
  | And of expr * expr
  | Not of expr
  | Compare of compare * expr * expr
  (* e ~ r; true: !~ *)
  | Match of bool * expr * regex
  | In of expr list * expr
  (* getline, getline x, getline < file, cmd | getline *)
  | Getline of expr option * (source * expr) option
  | Cat of expr * expr
  | Arith of arith * expr * expr
  | Neg of expr
  (* x++, --x: what is added, and whether the value is the new one *)
  | Step of expr * float * bool
  | Builtin of builtin * expr list
  | Call of cell * expr list
  | Index of expr * expr
  | Match_fn of expr * regex
  | Split of expr * expr * separator
  | Sprintf of expr list
  (* sub, gsub (true): the regexp, the replacement, the target *)
  | Sub of bool * regex * expr * expr
  | Substr of expr * expr * expr option

(* a regexp written in the program is compiled once; any other
 * expression's string each time *)
and regex = Static of Regex.t | Dynamic of expr

and separator = Default | Sep_string of expr | Sep_regex of Regex.t

and source = From_file | From_command

and assign = Set | Add_to | Sub_to | Mul_to | Div_to | Mod_to | Pow_to

and compare = Eq | Ne | Lt | Le | Gt | Ge

and arith = Add | Sub_ | Mul | Div | Mod | Pow

and builtin =
  | Length | Sqrt | Exp | Log | Int | System | Rand | Srand | Sin | Cos | Atan2 | Toupper | Tolower | Fflush | Utf

and stmt =
  (* a statement at an offset of the program's text, for the errors *)
  | At of int * stmt
  | Expr of expr
  | Print of expr list * (output * expr) option
  | Printf of expr list * (output * expr) option
  | Delete of expr * expr list option
  | Close of expr
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | Do of stmt * expr
  | For of stmt option * expr option * stmt option * stmt
  | For_in of expr * expr * stmt
  | Block of stmt list
  | Break
  | Continue
  | Next
  | Nextfile
  | Exit of expr option
  | Return of expr option

and output = To_file | Append | To_command

(* pattern { action }: always, when the pattern is true, or from a
 * record where the first is true to one where the second is (the
 * cell: whether we are between the two) *)
type rule =
  | Always of stmt
  | When of expr * stmt
  | Range of expr * expr * stmt * bool ref

type program = { begins : stmt list; rules : rule list; ends : stmt list }
