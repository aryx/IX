(* tiny-ml's tree: the types, the expressions and patterns the parser
 * builds, a unit's items; and the program's tables of constructors and
 * of record labels, filled by the parser as it reads a type, by
 * TinyML.ml from an interface, which the type checker and the compiler
 * read. *)

(* a type variable is a cell: unbound (its number and level), or linked
 * to what it became *)
type ty = TVar of tvar ref | TCon of string * ty list
and tvar = Unbound of int * int | Link of ty

type const = CInt of int | CChar of int | CStr of string

(* a type as it is written: a name and its arguments, a variable 'a *)
type texpr = TE of string * texpr list | TEVar of string

(* (p : t): an annotation, which makes a record's type known where its
 * labels are used. A record pattern names some of the fields; once
 * typed, it also knows their indexes and how many fields the record has *)
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
  | Var of string * ty ref            (* its type where it is used, which a
                                       * comparison reads *)
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  | Fun of string list * expr         (* a parameter's pattern is a let in
                                       * the body *)
  | Let of rec_flag * (pat * expr) list * expr
  | Match of expr * case list
  | Try of expr * case list
  | If of expr * expr * expr
  | Seq of expr * expr
  | While of expr * expr
  | For of string * expr * expr * bool * expr   (* up: to, not downto *)
  | Record of (string * expr) list * int list ref
      (* the fields' indexes, known once typed *)
  | With of expr * (string * expr) list * int list ref * int ref
      (* { e with l = e'; ... }: the fields' indexes and how many the
       * record has, known once typed *)
  | Dot of expr * string * int ref    (* e.l *)
  | SetDot of expr * string * int ref * expr
and case = pat * expr option * expr   (* a pattern, its guard, its body *)

(* a unit's toplevel: a let, an external (its name, type, primitive),
 * an exception, open M, module A = M *)
type item =
  | ILet of rec_flag * (pat * expr) list
  | IExt of string * texpr * string
  | IExn of string
  | IOpen of string
  | IAlias of string * string

(* a constructor: its number among its type's constant ones or among
 * the others (a block's tag), or an exception, of the unit that
 * declares it (its identity: two units' Error are two); its type as
 * %c(result, arguments...), generic in the type's parameters *)
type kind = KConst of int | KBlock of int | KExn of string
type cinfo = {
  kind : kind;
  arity : int;
  nconst : int;
  nblock : int;
  scheme : ty;
}
(* the constructors, each by its unit's name, M.C (a builtin's bare:
 * (), [], ::, true, false) *)
val cons : (string, cinfo) Hashtbl.t

(* a record's label: its field's index, and its type as %l(record,
 * field), as a constructor's; several records may have it *)
type linfo = {
  lrec : string;
  idx : int;
  mut : bool;
  lnames : string list;
  lscheme : ty;
}
val record_labels : (string, linfo) Hashtbl.t

(* a type variable's level, generic for one of a scheme; a new one *)
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

(* Names: a type, a constructor, a record's label is the program's by
 * its unit's name, M.t, M.C; a bare name in a unit is the one in scope:
 * the unit's own, what it opens, Stdlib's (Tree.ml's header) *)

(* the unit being compiled; its module A = M *)
val unit_name : string ref
val aliases : (string * string) list ref
(* C of M.C; M.x as M's, an alias's unit's; the unit's own x, U.x *)
val con_base : string -> string
val qualified : string -> string
val own : string -> string
(* type 'a t = ...: a second name for a type, by its qualified name,
 * its parameters' names *)
val abbreviations : (string * (string list * texpr)) list ref
(* the types declared, by their qualified names *)
val declared : (string, unit) Hashtbl.t
(* the bare names in scope (a label to its record's); in_scope adds one
 * for the unit's time, scope_done ends it *)
val con_scope : (string, string) Hashtbl.t
val type_scope : (string, string) Hashtbl.t
val label_scope : (string, linfo) Hashtbl.t
val scope_done : unit -> unit
(* [bring add add_label m]: M's names in scope, by add (for good,
 * Hashtbl.add: Stdlib's); open M, for the unit's time *)
val bring :
  ((string, string) Hashtbl.t -> string -> string -> unit) ->
  ((string, linfo) Hashtbl.t -> string -> linfo -> unit) -> string -> unit
val open_unit : string -> unit
(* a type, a constructor, a label the unit declares, in scope *)
val declare_type : string -> unit
val add_con : string -> cinfo -> unit
val add_label : string -> linfo -> unit
(* a type's, a constructor's name as the source says it, qualified;
 * a constructor's information, by its source's name or its own *)
val resolve_type : string -> string
val resolve_con : string -> string
val find_con : string -> cinfo
(* a type expression as a type, its variables' names in vars *)
val of_texpr : (string * ty) list ref -> texpr -> ty
(* a name, its type not known yet *)
val var : string -> expr
