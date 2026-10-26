(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLTree.mli *)
open TinyMLLexer

(*****************************************************************************)
(* The tree *)
(*****************************************************************************)

(* a type variable is a cell: unbound (its number and level), or linked
 * to what it became *)
type ty = TVar of tvar ref | TCon of string * ty list
and tvar = Unbound of int * int | Link of ty

type const = CInt of int | CChar of int | CStr of string

type texpr = TE of string * texpr list | TEVar of string

(* (p : t): an annotation, which makes a record's type known where its
 * labels are used. A record pattern names some of the fields; once
 * typed, it also knows their indexes and how many fields the record has *)
type pat = PAny | PVar of string | PConst of const | PCon of string * pat list
  | PTuple of pat list | PAlias of pat * string | POr of pat * pat
  | PAnnot of pat * texpr
  | PRecord of (string * pat) list * int list ref * int ref

type expr =
  | Const of const
  (* its type where it is used, which a comparison reads *)
  | Var of string * ty ref
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  (* a parameter's pattern is a let in the body *)
  | Fun of string list * expr
  | Let of bool * (pat * expr) list * expr
  | Match of expr * case list
  | Try of expr * case list
  | If of expr * expr * expr
  | Seq of expr * expr
  | While of expr * expr
  | For of string * expr * expr * bool * expr
  (* the fields' indexes, known once typed *)
  | Record of (string * expr) list * int list ref
  (* { e with l = e'; ... }: the fields' indexes and how many the record
   * has, known once typed *)
  | With of expr * (string * expr) list * int list ref * int ref
  | Dot of expr * string * int ref    (* e.l *)
  | SetDot of expr * string * int ref * expr

and case = pat * expr option * expr

type item =
  | ILet of bool * (pat * expr) list | IExt of string * texpr * string
  | IExn of string | IOpen of string

(* a constructor: its number among its type's constant ones or among
 * the others (a block's tag), or an exception; its type as
 * %c(result, arguments...), generic in the type's parameters *)
type kind = KConst of int | KBlock of int | KExn
type cinfo = { kind : kind; arity : int; nconst : int; nblock : int; scheme : ty }

let cons : (string, cinfo) Hashtbl.t = Hashtbl.create 64

(* a record's label: its field's index, and its type as %l(record,
 * field), as a constructor's; several records may have it *)
type linfo =
  { lrec : string; idx : int; mut : bool; lnames : string list; lscheme : ty }
let record_labels : (string, linfo) Hashtbl.t = Hashtbl.create 64
let find_con c =
  match Hashtbl.find_opt cons c with
  | Some ci -> ci
  | None -> error ("unknown constructor " ^ c)

let generic = max_int
let level = ref 1 and counter = ref 0
let newvar () = incr counter; TVar (ref (Unbound (!counter, !level)))
let genvar () = incr counter; TVar (ref (Unbound (!counter, generic)))
let tcon c = TCon (c, [])
let arrow a b = TCon ("->", [ a; b ])
let int_t = tcon "int" and bool_t = tcon "bool" and unit_t = tcon "unit"
and string_t = tcon "string"

let () =
  let a = genvar () in
  let add c kind arity nconst nblock res args =
    Hashtbl.replace cons c
      { kind; arity; nconst; nblock; scheme = TCon ("%c", res :: args) }
  in
  add "()" (KConst 0) 0 1 0 unit_t [];
  add "false" (KConst 0) 0 2 0 bool_t [];
  add "true" (KConst 1) 0 2 0 bool_t [];
  add "[]" (KConst 0) 0 1 1 (TCon ("list", [ a ])) [];
  add "::" (KBlock 0) 2 1 1 (TCon ("list", [ a ])) [ a; TCon ("list", [ a ]) ]

(* the unit being compiled (a file: its name, the prefix of its
 * symbols), and the units whose interfaces it read: M.t in a type is
 * t when M is one of them (a type's name is the program's, one name
 * space, as the constructors' and the values') *)
let unit_name = ref "Stdlib"
let known_units : string list ref = ref []

let rec of_texpr vars = function
  | TEVar v ->
      (match List.assoc_opt v !vars with
       | Some t -> t
       | None -> let t = genvar () in vars := (v, t) :: !vars; t)
  | TE (c, args) ->
      let c =
        match String.index_opt c '.' with
        | Some i when List.mem (String.sub c 0 i) !known_units ->
            String.sub c (i + 1) (String.length c - i - 1)
        | _ -> c
      in
      TCon (c, List.map (of_texpr vars) args)
(* a name, its type not known yet *)
let var x = Var (x, ref (tcon "?"))
