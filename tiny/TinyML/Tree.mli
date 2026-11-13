(* tiny-ml's tree: the types, expressions and patterns that the parser
 * builds, and the items of a unit. This module also has the program's
 * tables of constructors and of record labels. The parser fills them as
 * it reads a type declaration, and TinyML.ml fills them from an
 * interface; the type checker and the compiler read them. *)

(* Unbound has a number and a level; Link is the type it became. *)
type ty = TVar of tvar ref | TCon of string * ty list
and tvar = Unbound of int * int | Link of ty

type const = CInt of int | CChar of int | CStr of string

(* A type as written in the source. *)
type texpr = TE of string * texpr list | TEVar of string

(* PAnnot (p : t) makes a record's type known where its labels are used.
 * PRecord names some fields; typing fills their indexes and the number
 * of fields of the record. *)
type pat =
  | PAny
  | PVar of string
  | PConst of const
  | PCon of string * pat list
  | PTuple of pat list
  | PAlias of pat * string
  | POr of pat * pat
  | PAnnot of pat * texpr
  | PRecord of (string * pat) list * int list ref * int ref

type rec_flag = Nonrecursive | Recursive

type expr =
  | Const of const
  | Var of string * ty ref            (* its type at this use, which a
                                       * comparison reads *)
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  | Fun of string list * expr         (* a parameter's pattern becomes a
                                       * let in the body *)
  | Let of rec_flag * (pat * expr) list * expr
  | Match of expr * case list
  | Try of expr * case list
  | If of expr * expr * expr
  | Seq of expr * expr
  | While of expr * expr
  | For of string * expr * expr * bool * expr   (* true for to *)
  | Record of (string * expr) list * int list ref  (* indexes, once typed *)
  | With of expr * (string * expr) list * int list ref * int ref
      (* { e with l = e' }: the indexes and the number of fields *)
  | Dot of expr * string * int ref    (* e.l *)
  | SetDot of expr * string * int ref * expr
and case = pat * expr option * expr   (* a pattern, a guard, a body *)

(* IExt has a name, a type and a primitive. IAlias is module A = M. *)
type item =
  | ILet of rec_flag * (pat * expr) list
  | IExt of string * texpr * string
  | IExn of string
  | IOpen of string
  | IAlias of string * string

(* KConst numbers the constant constructors of a type, KBlock the others
 * (the block's tag). KExn names the unit that declares the exception,
 * so two units' Error differ. scheme is %c(result, arguments...). *)
type kind = KConst of int | KBlock of int | KExn of string
type cinfo = {
  kind : kind;
  arity : int;
  nconst : int;
  nblock : int;
  scheme : ty;
}
(* By M.C; the builtins are bare: (), [], ::, true, false. *)
val cons : (string, cinfo) Hashtbl.t

(* lscheme is %l(record, field). Several records may share a label. *)
type linfo = {
  lrec : string;
  idx : int;
  mut : bool;
  lnames : string list;
  lscheme : ty;
}
val record_labels : (string, linfo) Hashtbl.t

val generic : int                     (* the level of a scheme's variable *)
val level : int ref
val newvar : unit -> ty
val genvar : unit -> ty
val tcon : string -> ty
val arrow : ty -> ty -> ty
val int_t : ty
val bool_t : ty
val unit_t : ty
val string_t : ty

(* Names. A type, a constructor or a label is known to the program as
 * M.t or M.C. A bare name means the one in scope: the unit's own, then
 * those of the units it opens, then Stdlib's (Tree.ml's header). *)

val unit_name : string ref
val aliases : (string * string) list ref  (* module A = M *)
(* con_base gives C for M.C. qualified gives M.x for A.x. own gives U.x
 * for x. *)
val con_base : string -> string
val qualified : string -> string
val own : string -> string
(* type 'a t = ..., by its qualified name, with the parameters. *)
val abbreviations : (string * (string list * texpr)) list ref
val declared : (string, unit) Hashtbl.t
(* Bare names to qualified ones; scope_done ends the unit's scope. *)
val con_scope : (string, string) Hashtbl.t
val type_scope : (string, string) Hashtbl.t
val label_scope : (string, linfo) Hashtbl.t
val scope_done : unit -> unit
(* With Hashtbl.add, M's names stay in scope for good (Stdlib's);
 * open_unit brings them for the current unit only. *)
val bring :
  ((string, string) Hashtbl.t -> string -> string -> unit) ->
  ((string, linfo) Hashtbl.t -> string -> linfo -> unit) -> string -> unit
val open_unit : string -> unit
(* These declare the unit's own types, constructors and labels, and
 * bring them into scope. *)
val declare_type : string -> unit
val add_con : string -> cinfo -> unit
val add_label : string -> linfo -> unit
(* find_con takes the source name or the qualified one. *)
val resolve_type : string -> string
val resolve_con : string -> string
val find_con : string -> cinfo
(* vars maps the names of type variables to their types. *)
val of_texpr : (string * ty) list ref -> texpr -> ty
val var : string -> expr              (* its type is not known yet *)
