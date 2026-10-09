(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Names_ml.mli *)
open Ast

type category = Highlight_code.category

(* the names in scope that are a function's or a let's *)
type env = (string * category) list

(* [tree found base items]: the names of a part of the text's tree,
 * the part starting at base in the text *)
let tree (found : (int, category) Hashtbl.t) (base : int) (items : structure) : unit =
  let mark (offset : int) (c : category) : unit = Hashtbl.replace found (base + offset) c in
  (* a pattern's variables, each c: marked, and in scope *)
  let rec pattern (c : category) (env : env) (p : pattern) : env =
    match p.p with
    | Pvar x -> mark (fst p.pspan) c; (x, c) :: env
    | Palias (q, x) -> (x, c) :: pattern c env q
    (* (~x: the variable's place is the label's) *)
    | Plabel (x, _) -> (x, c) :: env
    | Ptuple l -> List.fold_left (pattern c) env l
    | Precord l -> List.fold_left (fun (env : env) ((_, q) : longid * pattern) -> pattern c env q) env l
    | Por (a, b) -> pattern c (pattern c env a) b
    | Pconstruct (_, Some q) | Pconstraint (q, _) | Pexception q -> pattern c env q
    | Pany | Pconst _ | Prange _ | Pconstruct (_, None) | Pextension _ | Pusing _ -> env in
  let rec expr (env : env) (e : expr) : unit =
    match e.e with
    | Eident [ x ] -> (match List.assoc_opt x env with Some c -> mark (fst e.espan) c | None -> ())
    | Eident _ | Econst _ | Econstruct (_, None) | Eextension _ -> ()
    | Elet (rec_flag, bindings, body) ->
        let inside = List.fold_left (fun (env : env) ((p, _) : binding) -> pattern Highlight_code.Local env p) env bindings in
        List.iter (fun ((_, v) : binding) -> expr (if rec_flag = Rec then inside else env) v) bindings;
        expr inside body
    (* fun x -> e, and let f x = e: one clause, a parameter; function
     * A -> ... | B -> ...: the clauses' names are locals *)
    | Efunction [ (p, guard, body) ] -> clause Highlight_code.Parameter env (p, guard, body)
    | Efunction cases -> List.iter (clause Highlight_code.Local env) cases
    | Ematch (v, cases) | Etry (v, cases) -> expr env v; List.iter (clause Highlight_code.Local env) cases
    | Efor (x, first, last, _, body) -> expr env first; expr env last; expr ((x, Highlight_code.Local) :: env) body
    (* the field is the last name of r.l *)
    | Efield (r, l) ->
        mark (snd e.espan - String.length (List.nth l (List.length l - 1))) Highlight_code.Field;
        expr env r
    | Esetfield (r, _, v) -> expr env r; expr env v
    | Eapply (f, args) -> expr env f; List.iter (expr env) args
    | Etuple l | Earray l -> List.iter (expr env) l
    | Erecord l -> List.iter (fun ((_, v) : longid * expr) -> expr env v) l
    | Ewith (r, l) -> expr env r; List.iter (fun ((_, v) : longid * expr) -> expr env v) l
    | Eif (c, a, None) -> expr env c; expr env a
    | Eif (c, a, Some b) -> expr env c; expr env a; expr env b
    | Eseq (a, b) | Ewhile (a, b) -> expr env a; expr env b
    | Econstruct (_, Some v) | Econstraint (v, _) | Eassert v | Elabel (_, v) | Eopen (_, v) | Equote (_, v, _) | Egenerator (_, v) ->
        expr env v
  and clause (c : category) (env : env) ((p, guard, body) : case) : unit =
    let env = pattern c env p in
    (match guard with Some g -> expr env g | None -> ());
    expr env body in
  (* an item's own names (let f, let x at the top) are the guess's: a
   * definition; what is in them is looked at *)
  let rec item (i : item) : unit =
    match i.i with
    | Ieval e -> expr [] e
    | Ivalue (_, bindings, _) -> List.iter (fun ((_, v) : binding) -> expr [] v) bindings
    | Imodule (_, m) -> module_expr m
    | Iexternal _ | Itype _ | Iexception _ | Iopen _ -> ()
  and module_expr (m : module_expr) : unit =
    match m with
    | Mstruct items -> List.iter item items
    | Mconstraint (m, _) -> module_expr m
    | Mident _ -> () in
  List.iter item items

(* where the items of the text start: 0, and after an empty line a line
 * that does not start with a space (nor with and, which continues one) *)
let starts (src : string) : int list =
  let n = String.length src in
  let rec go (i : int) (acc : int list) : int list =
    match String.index_from_opt src i '\n' with
    | Some j when j + 2 < n ->
        if src.[j + 1] = '\n' && not (String.contains " \t\n" src.[j + 2]) && not (j + 6 < n && String.sub src (j + 2) 4 = "and ")
        then go (j + 2) (j + 2 :: acc) else go (j + 1) acc
    | _ -> List.rev acc in
  go 0 [ 0 ]

let names (src : string) : (int, category) Hashtbl.t =
  let found = Hashtbl.create 256 in
  let rec parts (starts : int list) : unit =
    match starts with
    | [] -> ()
    | first :: rest ->
        let upto = (match rest with next :: _ -> next | [] -> String.length src) in
        (* (a part that does not parse, or whose tree is not what is
         * expected: nothing is said of it) *)
        (match Parser.implementation Lexer.token (Lexing.from_string (String.sub src first (upto - first))) with
         | items -> (try tree found first items with _ -> ())
         | exception _ -> ());
        parts rest in
  parts (starts src);
  found
