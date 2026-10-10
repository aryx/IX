(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Names resolved (plan_ml.md, decision 3; the tutorial's section 5).
 * Modules have no functors, so a module is only a name space known at
 * compile time: Scope flattens them, nested (module R = struct ... end)
 * and aliased (module P = Machine.Phys) ones included, and replaces
 * each name by what it denotes:
 *
 * - a value by a local variable (a unique number), a global (a module's
 *   toplevel value, a symbol), or a primitive (an external);
 * - a constructor by its number among its type's constant ones or its
 *   tag among the others, and its arity; an exception by its global;
 * - a label by its field's position, the record's size, whether it is
 *   mutable: the last type declared with that label, as 1.07's.
 *
 * Another unit's names come from its .mli, read as source when the unit
 * is first named (its .ml when it has none), as a C compiler reads a
 * header: no compiled interface. Pervasives is opened first. *)

(* a type, resolved: a constructor is its declaration, which an
 * abbreviation (type t = int * int) expands to, its parameters named *)

(* (No Scope.mli: the module is the scoped tree's types, and how they
 * are printed; the pass that makes the tree is Resolve.) *)

(* a type, resolved: a constructor is its declaration, which an
 * abbreviation (type t = int * int) expands to, its parameters named *)
type ty = Tvar of string | Tarrow of ty * ty | Ttuple of ty list | Tconstr of tdecl * ty list
and tdecl = { tpath : string; tparams : string list; mutable tabbrev : ty option }

type var = { vname : string; vid : int }
(* a function's parameters, in order: Some l for ~l, None for one
 * without label. Labels are Scope's: a call's arguments are put in
 * their parameters' order, and nothing after knows of labels *)
type params = string option list
(* gsym, the symbol: M.x, or M.x/2 for a toplevel value a later one of
 * the same name shadows (the last is the one exported) *)
type global = { gpath : string list; gname : string; mutable gsym : string; gtype : ty option; mutable glabels : params }

(* -dscope's printers are derived (dune: ppx_deriving; mini-ml: mlpp),
 * but of what a name stands for, which is said by hand: a variable
 * x/3, a global its symbol, a type not at all (they are graphs). The
 * stub is what a compiler without deriving is left with, as xix does. *)
let show_item _ = "NO DERIVING"
[@@warning "-32"]
let pp_var fmt v = Format.fprintf fmt "%s/%d" v.vname v.vid
let pp_global fmt g = Format.pp_print_string fmt g.gsym
let pp_ty fmt (_ : ty) = Format.pp_print_string fmt "_"

type value =
  | Local of var
  | Global of global
  | Prim of string * int * ty   (* an external: its primitive, its arity (its type's arrows), its type *)
[@@deriving show]
(* a constructor: its kind, its arity, and its type's numbers of
 * constant and non-constant constructors (a switch's size) *)
type kind = Const of int | Block of int | Exn of global
(* ltype: its type's parameters, the field's type, the record's *)
type label = { lname : string; mutable pos : int; mut : bool; size : int; ltype : string list * ty * ty; llabels : params (* a function's in the field *) }
(* ctype: its type's parameters, its arguments' types, its result's.
 * cinline, for C of { l : t; ... }: C has one argument, a record of a
 * type of its own (t.C), whose labels are these, known by C only: the
 * same label may be many constructors'. Where OCaml puts the fields in
 * C's block, here C points to the record. *)
type cons = {
  cname : string; kind : kind; arity : int; nconst : int; nblock : int; ctype : string list * ty list * ty;
  cinline : (string * label) list;
}


(* a constructor C#2 (constant), C[1] (a block's tag), C!sym (an
 * exception); a field l.0 *)
let pp_cons fmt c =
  match c.kind with
  | Const n -> Format.fprintf fmt "%s#%d" c.cname n
  | Block t -> Format.fprintf fmt "%s[%d]" c.cname t
  | Exn g -> Format.fprintf fmt "%s!%s" c.cname g.gsym
let pp_label fmt l = Format.fprintf fmt "%s.%d" l.lname l.pos

type pattern =
  | Pany
  | Pvar of var
  | Palias of pattern * var
  | Pconst of Ast.constant
  | Prange of char * char
  | Ptuple of pattern list
  | Pcons of cons * pattern list
  | Precord of (label * pattern) list
  | Por of pattern * pattern
  | Pconstraint of pattern * ty
[@@deriving show]

(* mlpp: span, where the expression is in the text: a class's dictionary
 * is written after a name (Typing) *)
type expr = { e : exp; loc : int; span : Ast.span }

and exp =
  | Evar of value
  | Econst of Ast.constant
  | Elet of bool * (pattern * expr) list * expr
  | Efunction of case list
  | Eapply of expr * expr list
  | Ematch of expr * case list
  | Etry of expr * case list
  | Etuple of expr list
  | Econs of cons * expr list
  | Erecord of int * (label * expr) list          (* the record's size *)
  | Ewith of expr * int * (label * expr) list
  | Efield of expr * label
  | Esetfield of expr * label * expr
  | Earray of expr list
  | Eif of expr * expr * expr option
  | Eseq of expr * expr
  | Ewhile of expr * expr
  | Efor of var * expr * expr * Ast.dir * expr
  | Eassert of expr
  | Econstraint of expr * ty

and case = pattern * expr option * expr [@@deriving show]

(* a unit's toplevel, in order: a let's variables then stored in their
 * globals; an exception's global made *)
type item =
  | Ieval of expr
  | Ivalue of bool * (pattern * expr) list * (var * global) list
  | Iexception of global * string
  | Iexternal of global * string * int * ty   (* a global too, for an importer whose .mli says val *)
[@@deriving show]

(* the unit's source, by module name: its interface (.mli), or its
 * implementation when it has none; None if not found *)
type loader = string -> Ast.source option
