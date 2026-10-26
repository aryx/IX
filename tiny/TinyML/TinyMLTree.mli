type ty = TVar of tvar ref | TCon of string * ty list
and tvar = Unbound of int * int | Link of ty
type const = CInt of int | CChar of int | CStr of string
type texpr = TE of string * texpr list | TEVar of string
type pat =
    PAny
  | PVar of string
  | PConst of const
  | PCon of string * pat list
  | PTuple of pat list
  | PAlias of pat * string
  | POr of pat * pat
  | PAnnot of pat * texpr
  | PRecord of (string * pat) list * int list ref * int ref
type expr =
    Const of const
  | Var of string * ty ref
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  | Fun of string list * expr
  | Let of bool * (pat * expr) list * expr
  | Match of expr * case list
  | Try of expr * case list
  | If of expr * expr * expr
  | Seq of expr * expr
  | While of expr * expr
  | For of string * expr * expr * bool * expr
  | Record of (string * expr) list * int list ref
  | With of expr * (string * expr) list * int list ref * int ref
  | Dot of expr * string * int ref
  | SetDot of expr * string * int ref * expr
and case = pat * expr option * expr
type item =
    ILet of bool * (pat * expr) list
  | IExt of string * texpr * string
  | IExn of string
  | IOpen of string
type kind = KConst of int | KBlock of int | KExn
type cinfo = {
  kind : kind;
  arity : int;
  nconst : int;
  nblock : int;
  scheme : ty;
}
val cons : (string, cinfo) Hashtbl.t
type linfo = {
  lrec : string;
  idx : int;
  mut : bool;
  lnames : string list;
  lscheme : ty;
}
val record_labels : (string, linfo) Hashtbl.t
val find_con : string -> cinfo
val generic : int
val level : int ref
val newvar : unit -> ty
val genvar : unit -> ty
val tcon : string -> ty
val arrow : ty -> ty -> ty
val int_t : ty
val bool_t : ty
val unit_t : ty
val string_t : ty
val unit_name : string ref
val known_units : string list ref
val of_texpr : (string * ty) list ref -> texpr -> ty
val var : string -> expr
