(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tree.mli *)

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

(* a let's: let rec, or not (OCaml's names) *)
type rec_flag = Nonrecursive | Recursive

type expr =
  | Const of const
  (* its type where it is used, which a comparison reads *)
  | Var of string * ty ref
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  (* a parameter's pattern is a let in the body *)
  | Fun of string list * expr
  | Let of rec_flag * (pat * expr) list * expr
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
  | ILet of rec_flag * (pat * expr) list | IExt of string * texpr * string
  | IExn of string | IOpen of string
  | IAlias of string * string          (* module A = M *)

(* a constructor: its number among its type's constant ones or among
 * the others (a block's tag), or an exception, of the unit that
 * declares it (its identity: two units' Error are two); its type as
 * %c(result, arguments...), generic in the type's parameters *)
type kind = KConst of int | KBlock of int | KExn of string
type cinfo = { kind : kind; arity : int; nconst : int; nblock : int; scheme : ty }

let cons : (string, cinfo) Hashtbl.t = Hashtbl.create 64

(* a record's label: its field's index, and its type as %l(record,
 * field), as a constructor's; several records may have it *)
type linfo =
  { lrec : string; idx : int; mut : bool; lnames : string list; lscheme : ty }
let record_labels : (string, linfo) Hashtbl.t = Hashtbl.create 64

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

(*****************************************************************************)
(* Names *)
(*****************************************************************************)

(* A type, a constructor and a record's label are the program's by their
 * unit's name, M.t, M.C, l of M.t, whatever was read before or after:
 * cons, record_labels, abbreviations and declared hold them so. In a
 * unit a bare name is found in scope: the unit's own, then what it
 * opens, the latest first, then Stdlib's, open in all; a primitive type
 * (int, bytes...) and a builtin constructor ((), [], ::, true, false)
 * are bare. M.x is M's, or an alias's unit's (module A = M). Caml
 * Light's names (a unit and a name, the opened units), and the values'
 * here (Types' tables). *)

(* the unit being compiled (a file: its name, the prefix of its
 * symbols and of its names) *)
let unit_name = ref "Stdlib"

(* module A = M in the current unit *)
let aliases : (string * string) list ref = ref []

(* C of M.C, t of M.t *)
let con_base c =
  match String.rindex_opt c '.' with
  | Some k -> String.sub c (k + 1) (String.length c - k - 1)
  | None -> c

(* M's unit: M, or the one M is an alias of *)
let unit_of m = match List.assoc_opt m !aliases with Some u -> u | None -> m

(* M.x as M's: an alias's unit's x *)
let qualified x =
  match String.rindex_opt x '.' with
  | Some k -> unit_of (String.sub x 0 k) ^ "." ^ con_base x
  | None -> x

(* the unit's own name for x *)
let own x = !unit_name ^ "." ^ x

(* type word = piece list, type 'a t = unit -> 'a node: a second name
 * for a type, by its qualified name, its parameters' names; unify puts
 * the type in the name's place when the two differ. A name and its
 * number of parameters say which *)
let abbreviations : (string * (string list * texpr)) list ref = ref []

(* the types declared, a variant's, a record's, an abbreviation's: what
 * open M brings in scope *)
let declared : (string, unit) Hashtbl.t = Hashtbl.create 64

(* the bare names in scope, each to its qualified one (a label to its
 * record's); the unit's own and what it opens for its time
 * (scope_done), Stdlib's for good *)
let con_scope : (string, string) Hashtbl.t = Hashtbl.create 64
let type_scope : (string, string) Hashtbl.t = Hashtbl.create 64
let label_scope : (string, linfo) Hashtbl.t = Hashtbl.create 64
let scoped : (unit -> unit) list ref = ref []
let in_scope tbl x v =
  Hashtbl.add tbl x v;
  scoped := (fun () -> Hashtbl.remove tbl x) :: !scoped
let scope_done () =
  List.iter (fun f -> f ()) !scoped; scoped := []; aliases := []

(* M's names bare, its constructors, its types, its records' labels (of
 * M itself, not of its modules: M.N.C stays M.N.C), by add: for the
 * unit's time (open M), or for good (Stdlib) *)
let bring add_name add_label m =
  let p = m ^ "." in
  let n = String.length p in
  let mine x =
    String.length x > n && String.sub x 0 n = p
    && not (String.contains (String.sub x n (String.length x - n)) '.') in
  let keys tbl =
    List.sort_uniq compare (Hashtbl.fold (fun k _ acc -> k :: acc) tbl []) in
  List.iter (fun c -> if mine c then add_name con_scope (con_base c) c)
    (keys cons);
  List.iter (fun t -> if mine t then add_name type_scope (con_base t) t)
    (keys declared);
  (* (a label of two of M's records: the latest declared) *)
  List.iter (fun l ->
      List.iter (fun (li : linfo) -> if mine li.lrec then add_label label_scope l li)
        (List.rev (Hashtbl.find_all record_labels l)))
    (keys record_labels)
let open_unit m = bring in_scope in_scope (unit_of m)

(* a type, a constructor, a record's label the unit declares: its name
 * in scope *)
let declare_type t =
  let q = own t in
  if Hashtbl.find_opt type_scope t <> Some q then begin
    Hashtbl.replace declared q (); in_scope type_scope t q end
let add_con c (ci : cinfo) =
  Hashtbl.replace cons (own c) ci; in_scope con_scope c (own c)
let add_label l (li : linfo) =
  Hashtbl.add record_labels l li; in_scope label_scope l li

(* a type's name as the source says it: M.t, M's; t, the one in scope,
 * else the one of a unit not open when it is the only one of that name
 * (Int64.mli's int32, Int32's, which OCaml's own names as int32); else
 * a primitive's, bare *)
let resolve_type t =
  if String.contains t '.' then qualified t
  else match Hashtbl.find_opt type_scope t with
    | Some q -> q
    | None ->
        (match Hashtbl.fold (fun q () acc ->
             if con_base q = t && not (List.mem q acc) then q :: acc else acc)
             declared [] with
         | [ q ] -> q
         | _ -> t)

(* a constructor as the source names it: M.C, M's; C, the one in
 * scope, a builtin, else the one of a unit not open when it is the
 * only one of that name (OCaml finds it by its type) *)
let resolve_con c =
  if String.contains c '.' then qualified c
  else match Hashtbl.find_opt con_scope c with
    | Some q -> q
    | None when Hashtbl.mem cons c -> c
    | None ->
        let qs = Hashtbl.fold (fun q _ acc ->
            if String.contains q '.' && con_base q = c && not (List.mem q acc)
            then q :: acc else acc) cons [] in
        (match qs with
         | [ q ] -> q
         | [] -> Lexer.error ("unknown constructor " ^ c)
         | _ ->
             Lexer.error
               ("constructor " ^ c ^ " of several units ("
                ^ String.concat ", " (List.sort compare qs)
                ^ "): say which, M." ^ c ^ ", or open M"))
let find_con c =
  match Hashtbl.find_opt cons (resolve_con c) with
  | Some ci -> ci
  | None -> Lexer.error ("unknown constructor " ^ c)

let rec of_texpr vars = function
  | TEVar v ->
      (match List.assoc_opt v !vars with
       | Some t -> t
       | None -> let t = genvar () in vars := (v, t) :: !vars; t)
  | TE (c, args) -> TCon (c, List.map (of_texpr vars) args)
(* a name, its type not known yet *)
let var x = Var (x, ref (tcon "?"))
