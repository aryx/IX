(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Summary.mli *)

type entry = { global : string; params : Scope.pattern list; body : Scope.expr; size : int }

type t = {
  digest : string;
  entries : entry list;
  immediates : Ast.span list;
  strings : Ast.span list;
  floats : Ast.span list;
  min_max : (string * string) list;
  constants : (string * Scope.expr) list;
}

(*****************************************************************************)
(* The types taken out *)
(*****************************************************************************)

let none : Scope.ty = Tvar "_"

(* (each global met, for uses) *)
let note : (string -> unit) ref = ref ignore

let rec label (l : Scope.label) : Scope.label = { l with ltype = [], none, none }

and cons (c : Scope.cons) : Scope.cons =
  { c with ctype = [], [], none; cinline = List.map (fun (x, l) -> x, label l) c.cinline;
    kind = (match c.kind with Exn g -> Exn (global g) | k -> k) }

and global (g : Scope.global) : Scope.global = !note g.gsym; { g with gtype = None }

let rec strip_pattern (p : Scope.pattern) : Scope.pattern =
  match p with
  | Pany | Pvar _ | Pconst _ | Prange _ -> p
  | Palias (p, v) -> Palias (strip_pattern p, v)
  | Ptuple ps -> Ptuple (List.map strip_pattern ps)
  | Pcons (c, ps) -> Pcons (cons c, List.map strip_pattern ps)
  | Precord fs -> Precord (List.map (fun (l, p) -> label l, strip_pattern p) fs)
  | Por (a, b) -> Por (strip_pattern a, strip_pattern b)
  | Pconstraint (p, _) -> strip_pattern p

(* (one walk for both: the types out, and the places moved) *)
let map (f : Ast.span -> Ast.span) (e : Scope.expr) : Scope.expr =
  let rec re (e : Scope.expr) : Scope.expr =
    match e.e with
    (* (a constraint is its expression: its type is all it adds) *)
    | Econstraint (x, _) -> re x
    | _ ->
    let cases cs = List.map (fun (p, g, b) -> strip_pattern p, Option.map re g, re b) cs in
    let fields fs = List.map (fun (l, e) -> label l, re e) fs in
    let e' : Scope.exp =
      match e.e with
      | Evar (Global g) -> Evar (Global (global g))
      | Evar (Prim (p, n, _)) -> Evar (Prim (p, n, none))
      | Evar (Local _) | Econst _ -> e.e
      | Elet (r, bs, b) -> Elet (r, List.map (fun (p, e) -> strip_pattern p, re e) bs, re b)
      | Efunction cs -> Efunction (cases cs)
      | Eapply (g, es) -> Eapply (re g, List.map re es)
      | Ematch (x, cs) -> Ematch (re x, cases cs)
      | Etry (x, cs) -> Etry (re x, cases cs)
      | Etuple es -> Etuple (List.map re es)
      | Econs (c, es) -> Econs (cons c, List.map re es)
      | Erecord (n, fs) -> Erecord (n, fields fs)
      | Ewith (x, n, fs) -> Ewith (re x, n, fields fs)
      | Efield (x, l) -> Efield (re x, label l)
      | Esetfield (a, l, b) -> Esetfield (re a, label l, re b)
      | Earray es -> Earray (List.map re es)
      | Eif (c, a, b) -> Eif (re c, re a, Option.map re b)
      | Eseq (a, b) -> Eseq (re a, re b)
      | Ewhile (a, b) -> Ewhile (re a, re b)
      | Efor (v, a, b, d, body) -> Efor (v, re a, re b, d, re body)
      | Eassert x -> Eassert (re x)
      | Econstraint _ -> assert false
    in
    { e with e = e'; span = f e.span }
  in
  re e

let strip e = map Fun.id e
let respan f e = map f e

(* the units whose globals the items name, values or exceptions: a
 * unit's are X.f, X.R.g (a module in it) *)
let uses (items : Scope.item list) : string list =
  let us = Hashtbl.create 16 in
  note := (fun s -> match String.index_opt s '.' with Some i -> Hashtbl.replace us (String.sub s 0 i) () | None -> ());
  List.iter (fun (it : Scope.item) ->
    match it with
    | Ieval e -> ignore (strip e)
    | Ivalue (_, bs, _) -> List.iter (fun (p, e) -> ignore (strip_pattern p); ignore (strip e)) bs
    | Iexception _ | Iexternal _ -> ()) items;
  note := ignore;
  List.sort compare (Hashtbl.fold (fun u () acc -> u :: acc) us [])

(*****************************************************************************)
(* The file *)
(*****************************************************************************)

(* (a word first, so that another file, or one of an older format, is
 * not taken for one) *)
(* (2: with Fold's constants) *)
let magic = "mini-ml summary 2\n"

(* No_sharing: the bytes the value's alone, not which of its parts are
 * one block, which depends on the compiler that built mini-ml (as
 * Asm.save's objects; make self compares the card's with Linux's)
 * old: magic ^ Marshal.to_string s [] *)
let to_string (s : t) = magic ^ Marshal.to_string s [ Marshal.No_sharing ]

let of_string (text : string) : t option =
  let n = String.length magic in
  if String.length text > n && String.sub text 0 n = magic then Some (Marshal.from_string text n) else None
