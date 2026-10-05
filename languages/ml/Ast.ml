(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The tree of ocaml-light's ML, as the parser builds it: the subset
 * mini-ml compiles (plan_ml.md, "The subset, counted"), names still
 * names. Scope then resolves them.
 *
 * A multi-argument function is what the parser makes of it, as
 * ocaml-light's: fun x y -> e is a function of x whose body is a
 * function of y; the arities are found later. The sugar is gone: e.(i)
 * is Array.get e i, s.[i] String.get s i, [a; b] a :: b :: [], and
 * x :: l the constructor "::" of the pair.
 *
 * Each node has its line (the file is the unit's). *)

(* -dast's printers are derived (dune: ppx_deriving; mini-ml: mlpp); these
 * are what a compiler without deriving is left with, as xix does *)
let show_item _ = "NO DERIVING"
[@@warning "-32"]
let show_sig_item _ = "NO DERIVING"
[@@warning "-32"]

type loc = int [@@deriving show]

(* mlpp: a stretch of the source, in characters: [start, stop); what
 * mlpp needs to rewrite a construct in the text (pp/) *)
type span = int * int [@@deriving show]

(* M.N.x is [ "M"; "N"; "x" ] *)
type longid = string list [@@deriving show]

(* 3l, an int32, and 3L, an int64: the literal's digits *)
type constant = Int of int | Char of char | String of string | Float of string | Int32 of string | Int64 of string
[@@deriving show]

type rec_flag = Nonrec | Rec [@@deriving show]
type dir = Upto | Downto [@@deriving show]

(* _ is Tvar "_", a variable of its own; x:t -> ... an arrow whose
 * domain is Tlabel; C of { l : t } a constructor's one argument Trecord *)
type ty =
  | Tvar of string
  | Tarrow of ty * ty
  | Ttuple of ty list
  | Tconstr of longid * ty list
  | Tlabel of string * ty
  | Trecord of (string * bool * ty) list
  (* mlpp: [%using: 'a show], a parameter's type: a dictionary a call doesn't write *)
  | Tusing of ty * span
[@@deriving show]

(* a constructor's arguments are one pattern, a tuple for several, as
 * the parser can't tell C (a, b) from C p; Scope splits them *)
type pattern = { p : pat; ploc : loc }

and pat =
  | Pany
  | Pvar of string
  | Palias of pattern * string
  | Pconst of constant
  | Prange of char * char
  | Ptuple of pattern list
  | Pconstruct of longid * pattern option
  | Precord of (longid * pattern) list
  | Por of pattern * pattern
  | Pconstraint of pattern * ty
  (* a function's parameter ~x, ~x:p *)
  | Plabel of string * pattern
  (* | exception E -> in a match, which the parser rewrites *)
  | Pexception of pattern
  (* mlpp: [%bits "..."], the extension's name, its payload *)
  | Pextension of string * string * span
  (* mlpp: [%using: 'a show], a parameter without a name *)
  | Pusing of ty * span
[@@deriving show]

(* mlpp: espan, where a [%bits] clause's guard and body are *)
type expr = { e : exp; eloc : loc; espan : span }

and exp =
  | Eident of longid
  | Econst of constant
  | Elet of rec_flag * binding list * expr
  | Efunction of case list
  | Eapply of expr * expr list
  | Ematch of expr * case list
  | Etry of expr * case list
  | Etuple of expr list
  | Econstruct of longid * expr option
  | Erecord of (longid * expr) list
  | Ewith of expr * (longid * expr) list    (* { e with l = v } *)
  | Efield of expr * longid
  | Esetfield of expr * longid * expr
  | Earray of expr list
  | Eif of expr * expr * expr option
  | Eseq of expr * expr
  | Ewhile of expr * expr
  | Efor of string * expr * expr * dir * expr
  | Econstraint of expr * ty
  | Eassert of expr
  (* an argument ~x, ~x:e *)
  | Elabel of string * expr
  (* M.(e) *)
  | Eopen of longid * expr
  (* mlpp: [%bits "..."] *)
  | Eextension of string * string * span
  (* mlpp: [%list e || x <- xs; c], the extension's name and its payload,
   * an expression; x <- xs, a generator in it *)
  | Equote of string * expr * span
  | Egenerator of string * expr

and binding = pattern * expr

(* a clause: the pattern, its guard, its body *)
and case = pattern * expr option * expr [@@deriving show]

(* mlpp: tspan, its "= ..." (empty for an abstract type), where mlpp finds the
 * text of a .mli's declaration and puts it in the .ml's type t = [%mli];
 * tattrs: the [@@...] after it, as OCaml's tree has them, after the
 * last of a group *)
type type_decl = {
  tname : string; tparams : string list; tkind : tkind; tmanifest : ty option; tloc : loc; tspan : span;
  tattrs : attribute list;
}

(* mlpp: [@@deriving show], [@@class]; its end, where mlpp puts the code;
 * and a value's [@@instance] *)
and attribute = { aname : string; aargs : string list; aloc : loc; aend : int }

and tkind =
  | Hole                                    (* mlpp: type t = [%mli] *)
  | Abstract
  | Variant of (string * ty list) list
  | Record of (string * bool * ty) list     (* a label, mutable, its type *)
[@@deriving show]

type structure = item list
and item = { i : it; iloc : loc }

and it =
  | Ieval of expr
  | Ivalue of rec_flag * binding list * attribute list
  | Iexternal of string * ty * string list
  | Itype of type_decl list
  | Iexception of string * ty list
  | Imodule of string * module_expr
  | Iopen of longid

and module_expr = Mident of longid | Mstruct of structure | Mconstraint of module_expr * module_type
and module_type = MTident of longid | MTsig of signature
and signature = sig_item list
and sig_item = { s : sg; sloc : loc }

and sg =
  | Sval of string * ty * attribute list
  | Sexternal of string * ty * string list
  | Stype of type_decl list
  | Sexception of string * ty list
  | Smodule of string * module_type
  | Sopen of longid
[@@deriving show]

(* a file's tree: a .ml's, or a .mli's *)
type source = Structure of structure | Signature of signature [@@deriving show]

(* a qualified name, as written: in a message *)
let name l = String.concat "." l
