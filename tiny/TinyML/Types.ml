(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Types.mli *)
open Common

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let rec repr t = match t with Tree.TVar { contents = Tree.Link t } -> repr t
  | t -> t

let rec show t =
  match repr t with
  | Tree.TVar { contents = Tree.Unbound (n, _) } -> (Printf.sprintf "'_%d" n)
  | Tree.TCon ("->", [ a; b ]) ->
    (Printf.sprintf "(%s -> %s)" (show a) (show b))
  | Tree.TCon ("*", ts) -> "(" ^ String.concat " * " (List.map show ts) ^ ")"
  | Tree.TCon (c, []) -> c
  | Tree.TCon (c, ts) -> "(" ^ String.concat ", " (List.map show ts) ^ ") " ^ c
  | Tree.TVar _ -> "?"

(* x's variable in its own type is an error; a variable met at a lower
 * level takes it, so that it is generalized only where both are *)
let rec occurs r lv t =
  match repr t with
  | Tree.TVar r' when r == r' -> Lexer.error "a recursive type"
  | Tree.TVar ({ contents = Tree.Unbound (n, l) } as r') ->
      if l > lv then r' := Tree.Unbound (n, lv)
  | Tree.TCon (_, ts) -> List.iter (occurs r lv) ts
  | Tree.TVar _ -> ()

let rec unify a b =
  match repr a, repr b with
  | Tree.TVar r, Tree.TVar r' when r == r' -> ()
  (* (two cases: tiny-ml has no or-patterns with names) *)
  | Tree.TVar ({ contents = Tree.Unbound (_, l) } as r), t -> occurs r l t;
  r := Tree.Link t
  | t, Tree.TVar ({ contents = Tree.Unbound (_, l) } as r) -> occurs r l t;
  r := Tree.Link t
  | Tree.TCon (c, ts),
    Tree.TCon (d, us) when c = d && List.length ts = List.length us ->
      List.iter2 unify ts us
  | a, b ->
      (* a type's second name (abbreviations): the type in its place *)
      let named = function Tree.TCon (c, ts) -> Parser.abbreviation c ts
        | _ -> None in
      match named a, named b with
      | Some t, _ -> unify t b
      | _, Some t -> unify a t
      | None, None ->
          Lexer.error
            (Printf.sprintf "this has type %s but is used with type %s" (show a)
               (show b))

(* the variables deeper than the current let become parameters *)
let rec generalize t =
  match repr t with
  | Tree.TVar ({ contents = Tree.Unbound (n, l) } as r) when l > !Tree.level ->
      r := Tree.Unbound (n, Tree.generic)
  | Tree.TCon (_, ts) -> List.iter generalize ts
  | Tree.TVar _ -> ()

let instantiate t =
  let copies = Hashtbl.create 8 in
  let rec go t =
    match repr t with
    | Tree.TVar { contents = Tree.Unbound (n, l) } when l = Tree.generic -> (
        match Hashtbl.find_opt copies n with
        | Some v -> v
        | None -> let v = Tree.newvar () in Hashtbl.replace copies n v; v)
    | Tree.TCon (c, ts) -> Tree.TCon (c, List.map go ts)
    | t -> t
  in
  go t

(* the value restriction: only a value is generalized *)
let rec nonexpansive = function
  | Tree.Const _ | Tree.Var _ | Tree.Fun _ -> true
  | Tree.Con (_, l) -> List.for_all nonexpansive l
  | Tree.Tuple l -> List.for_all nonexpansive l
  | _ -> false

let con_type c =
  match instantiate (Tree.find_con c).scheme with
  | Tree.TCon (_, res :: args) -> res, args
  | _ -> invalid_arg "con_type"

(* the records that have a label among those f keeps, one each *)
let records l f =
  List.fold_left (fun acc (li : Tree.linfo) ->
      if f li && not (List.exists (fun (o : Tree.linfo) -> o.lrec = li.lrec) acc)
      then li :: acc else acc)
    [] (Hashtbl.find_all Tree.record_labels l)

(* l's label: of the record t already is when known (an annotation's,
 * a parameter's), type-directed, so that two records may share one;
 * else the one in scope (Tree's names: the unit's own, what it opens,
 * Stdlib's, the latest first); else the only record that has it *)
let label_for l t : Tree.linfo =
  match repr t with
  | Tree.TCon (n, _) ->
      (match records l (fun li -> li.lrec = n) with
       | li :: _ -> li
       | [] -> Lexer.error (Printf.sprintf "no field %s in %s" l n))
  | _ ->
      (match Hashtbl.find_opt Tree.label_scope l with
       | Some li -> li
       | None ->
           (match records l (fun _ -> true) with
            | [ li ] -> li
            | [] -> Lexer.error (Printf.sprintf "no field %s" l)
            | lis ->
                Lexer.error
                  (Printf.sprintf "the field %s of several records (%s): say which"
                     l (String.concat ", "
                          (List.sort compare
                             (List.map (fun (li : Tree.linfo) -> li.lrec) lis))))))
let label_type (li : Tree.linfo) =
  match instantiate li.lscheme with
  | Tree.TCon (_, [ r; f ]) -> r, f
  | _ -> invalid_arg "label_type"
let const_type = function
  | Tree.CInt _ -> Tree.int_t | Tree.CChar _ -> Tree.tcon "char"
    | Tree.CStr _ -> Tree.string_t

(* known: the type the value matched is already known to have (the
 * scrutinee's, an annotation's), so that a record pattern finds its
 * record when two records share a label; a fresh variable when none is
 * known. (A plain argument, not an optional one, which mini-ml, the
 * compiler mini-mk builds this file with, does not have) *)
let rec pat_type known p : Tree.ty * (string * Tree.ty) list =
  match p with
  | Tree.PAny -> Tree.newvar (), []
  | Tree.PVar x -> let t = Tree.newvar () in t, [ x, t ]
  | Tree.PConst c -> const_type c, []
  | Tree.PCon (c, ps) ->
      let res, args = con_type c in
      res,
      List.concat
        (List.map2
           (fun p t -> let pt, b = pat_type (Tree.newvar ()) p in unify pt t; b)
           ps args)
  | Tree.PTuple ps ->
      let l = List.map (fun p -> pat_type (Tree.newvar ()) p) ps in
      Tree.TCon ("*", List.map fst l), List.concat_map snd l
  | Tree.PAlias (p, x) -> let t, b = pat_type known p in t, (x, t) :: b
  | Tree.PAnnot (p, te) ->
      let ta = instantiate (Tree.of_texpr (ref []) te) in
      unify ta known;
      let t, b = pat_type ta p in unify t ta; t, b
  | Tree.PRecord (fs, idxs, n) ->
      let li0 = label_for (fst (List.hd fs)) known in
      let r = Tree.newvar () in
      let bs = List.map (fun (l, p) ->
        let li =
          match
            List.find_opt (fun (li : Tree.linfo) -> li.lrec = li0.lrec)
              (Hashtbl.find_all Tree.record_labels l)
          with
          | Some li -> li
          | None ->
            Lexer.error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r', f = label_type li in
        unify r r';
        let pt, b = pat_type f p in
        unify pt f; li.idx, b) fs in
      idxs := List.map fst bs; n := List.length li0.lnames;
      r, List.concat_map snd bs
  | Tree.POr (a, b) ->
      let t, ba = pat_type (Tree.newvar ()) a and u,
        bb = pat_type (Tree.newvar ()) b in
      unify t u;
      if ba <> [] || bb <> [] then Lexer.error "an or-pattern with variables";
      t, []

(* The names of the toplevel, by name, in a table: the units' before
 * this one, M.x, Stdlib's x too (open in all), and this unit's own and
 * what it opens, each added as it comes (a name added again hides the
 * one before, as OCaml's Hashtbl keeps them) and taken out at its end
 * ([unit_done]). The locals are a list, looked in first. Two of them,
 * the types' and the values' (below). *)
let tglobals : (string, Tree.ty) Hashtbl.t = Hashtbl.create 1024
let find_name env tbl x =
  match List.assoc_opt x env with
  | Some b -> Some b
  | None -> Hashtbl.find_opt tbl x

(* a name of this unit's toplevel, until its end *)
let unit_names = ref []
let add_name tbl x b =
  Hashtbl.add tbl x b;
  unit_names := (fun () -> Hashtbl.remove tbl x) :: !unit_names
let unit_done () =
  List.iter (fun f -> f ()) !unit_names; unit_names := [];
  Tree.scope_done ()

(*****************************************************************************)
(* Matches that miss a case, and cases that are never used *)
(*****************************************************************************)

(* A pattern as the check sees it, once typed: a variable is _, an
 * alias and an annotation are their pattern, a tuple is a constructor
 * "*" and a record one "{}" of all its fields (_ for those not named).
 * A constructor's name is the qualified one, so that Some and
 * Stdlib.Some are one. *)
type cpat = Any | Con of string * cpat list | Lit of Tree.const | Alt of cpat * cpat

let rec norm p =
  match p with
  | Tree.PAny -> Any
  | Tree.PVar _ -> Any
  | Tree.PAlias (p, _) -> norm p
  | Tree.PAnnot (p, _) -> norm p
  | Tree.PConst c -> Lit c
  | Tree.PCon (c, ps) -> Con (Tree.resolve_con c, List.map norm ps)
  | Tree.PTuple ps -> Con ("*", List.map norm ps)
  | Tree.PRecord (fs, idxs, n) ->
      let fields = Array.make !n Any in
      List.iter2 (fun (_, p) i -> fields.(i) <- norm p) fs !idxs;
      Con ("{}", Array.to_list fields)
  | Tree.POr (a, b) -> Alt (norm a, norm b)

let anys n = List.init n (fun _ -> Any)

(* a constructor's arguments, as many as it has: C _ stands for all of
 * them *)
let args_of c ps =
  if c = "*" || c = "{}" then ps
  else
    let a = (Tree.find_con c).arity in
    if List.length ps = a then ps else anys a

(* the rows with their or-patterns at the head made two rows *)
let rec expand rows =
  List.concat_map (fun r ->
    match r with
    | Alt (a, b) :: rest -> expand [ a :: rest; b :: rest ]
    | _ -> [ r ]) rows

(* the rows that a value made by constructor c (a arguments) can match,
 * its arguments first; the rows a literal k can match; the rows that a
 * value of none of the column's constructors can match *)
let specialize c a rows =
  List.concat_map (fun r ->
    match r with
    | Con (c', ps) :: rest -> if c' = c then [ args_of c ps @ rest ] else []
    | Any :: rest -> [ anys a @ rest ]
    | _ -> []) (expand rows)
let specialize_lit k rows =
  List.concat_map (fun r ->
    match r with
    | Lit k' :: rest -> if k' = k then [ rest ] else []
    | Any :: rest -> [ rest ]
    | _ -> []) (expand rows)
let default rows =
  List.concat_map (fun r ->
    match r with Any :: rest -> [ rest ] | _ -> []) (expand rows)

(* the constructors at the head of the rows, each once with its arity;
 * whether they are all of their type's (a tuple's and a record's one
 * always is; an exception's never, nor literals) *)
let heads rows =
  List.fold_left (fun acc r ->
    match r with
    | Con (c, ps) :: _ when not (List.mem_assoc c acc) ->
        acc @ [ c, List.length (args_of c ps) ]
    | _ -> acc) [] (expand rows)
let complete hs =
  match hs with
  | [] -> false
  | (c, _) :: _ ->
      c = "*" || c = "{}"
      || (let ci = Tree.find_con c in
          (match ci.kind with Tree.KExn _ -> false | _ -> true)
          && List.length hs = ci.nconst + ci.nblock)

(* Whether a row v of patterns matches a value that none of the rows
 * matches (Maranget's usefulness, as OCaml's warnings 8 and 11 are
 * found): a match misses a case when a row of _ is useful after its
 * cases, and a case is never used when it is not useful after those
 * before it. *)
let rec useful rows v =
  match v with
  | [] -> rows = []
  | Alt (a, b) :: rest -> useful rows (a :: rest) || useful rows (b :: rest)
  | Con (c, ps) :: rest ->
      let args = args_of c ps in
      useful (specialize c (List.length args) rows) (args @ rest)
  | Lit k :: rest -> useful (specialize_lit k rows) rest
  | Any :: rest ->
      let hs = heads rows in
      if complete hs then
        List.exists (fun (c, a) -> useful (specialize c a rows) (anys a @ rest)) hs
      else useful (default rows) rest

(* A match's cases, once typed, are an error if one is never used or if
 * a value matches none of them. A case with a guard may not match, so
 * it covers nothing for those after it. A try's cases are not checked:
 * the exceptions they do not name go on up. *)
let check_cases cases =
  let rows =
    List.fold_left (fun rows (p, g, _) ->
      let r = [ norm p ] in
      if not (useful rows r) then Lexer.error "a case that is never used";
      if g = None then rows @ [ r ] else rows) [] cases in
  if useful rows [ Any ] then Lexer.error "a match that misses a case"

let check_let p =
  if useful [ [ norm p ] ] [ Any ] then
    Lexer.error "a let whose pattern misses a case"

let rec infer env e : Tree.ty =
  match e with
  | Tree.Const c -> const_type c
  | Tree.Var (x, r) ->
      (match find_name env tglobals x with
       | Some t -> r := instantiate t; !r
       | None -> Lexer.error ("unbound " ^ x))
  | Tree.Con (c, args) ->
      let res, targs = con_type c in
      List.iter2 (fun a t -> unify (infer env a) t) args targs;
      res
  | Tree.Tuple es -> Tree.TCon ("*", List.map (infer env) es)
  | Tree.App (f, args) ->
      List.fold_left
        (fun tf a -> let r = Tree.newvar () in
          unify tf (Tree.arrow (infer env a) r); r)
        (infer env f) args
  | Tree.Fun (xs, b) ->
      let ts = List.map (fun _ -> Tree.newvar ()) xs in
      List.fold_right Tree.arrow ts
        (infer (List.rev (List.combine xs ts) @ env) b)
  | Tree.Let (Tree.Nonrecursive, bs, b) -> infer (let_types env bs) b
  | Tree.Let (Tree.Recursive, bs, b) -> infer (rec_types env bs) b
  | Tree.Match (e, cases) ->
      let t = cases_type env (infer env e) cases in
      check_cases cases;
      t
  | Tree.Try (e, cases) ->
      let t = infer env e in unify t (cases_type env (Tree.tcon "exn") cases); t
  | Tree.If (c, a, b) ->
      unify (infer env c) Tree.bool_t;
      let t = infer env a in
      unify t (infer env b);
      t
  | Tree.Seq (a, b) -> ignore (infer env a); infer env b
  | Tree.While (c, b) -> unify (infer env c) Tree.bool_t; ignore (infer env b);
  Tree.unit_t
  | Tree.For (x, a, b, _, body) ->
      unify (infer env a) Tree.int_t;
      unify (infer env b) Tree.int_t;
      ignore (infer ((x, Tree.int_t) :: env) body);
      Tree.unit_t
  | Tree.Dot (e, l, i) ->
      let t = infer env e in
      let li = label_for l t in
      let r, f = label_type li in
      i := li.idx; unify t r; f
  | Tree.SetDot (e, l, i, v) ->
      let t = infer env e in
      let li = label_for l t in
      if not li.mut then
        Lexer.error (Printf.sprintf "the field %s is not mutable" l);
      let r, f = label_type li in
      i := li.idx; unify t r; unify (infer env v) f; Tree.unit_t
  | Tree.Record (fs, order) ->
      (* the record whose labels are exactly these *)
      let names = List.sort compare (List.map fst fs) in
      let fits (li : Tree.linfo) = List.sort compare li.lnames = names in
      let l = fst (List.hd fs) in
      let li0 =
        match Hashtbl.find_opt Tree.label_scope l with
        | Some li when fits li -> li
        | _ ->
            (match records l fits with
             | [ li ] -> li
             | [] -> Lexer.error
                 ("no record has the fields " ^ String.concat ", " names)
             | _ -> Lexer.error
                 ("several records have the fields "
                  ^ String.concat ", " names ^ ": say which"))
      in
      let r = Tree.newvar () in
      order := List.map (fun (l, e) ->
        let li =
          List.find (fun (li : Tree.linfo) -> li.lrec = li0.lrec)
            (Hashtbl.find_all Tree.record_labels l)
        in
        let r', f = label_type li in
        unify r r'; unify (infer env e) f; li.idx) fs;
      r
  | Tree.With (e, fs, idxs, n) ->
      (* the copy has e's type: a field cannot change a type parameter *)
      let t = infer env e in
      let li0 = label_for (fst (List.hd fs)) t in
      idxs := List.map (fun (l, v) ->
        let li =
          match
            List.find_opt (fun (li : Tree.linfo) -> li.lrec = li0.lrec)
              (Hashtbl.find_all Tree.record_labels l)
          with
          | Some li -> li
          | None ->
            Lexer.error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r, f = label_type li in
        unify t r; unify (infer env v) f; li.idx) fs;
      n := List.length li0.lnames;
      t

and cases_type env t cases =
  let r = Tree.newvar () in
  List.iter (fun (p, g, e) ->
    let pt, bs = pat_type t p in
    unify pt t;
    let env = bs @ env in
    Option.iter (fun g -> unify (infer env g) Tree.bool_t) g;
    unify (infer env e) r) cases;
  r

and let_types env bs =
  List.concat_map (fun (p, e) ->
    incr Tree.level;
    let t = infer env e in
    decr Tree.level;
    match p with
    | Tree.PVar x ->
        if nonexpansive e then generalize t else unify (Tree.newvar ()) t;
        [ x, t ]
    | p -> let pt, b = pat_type t p in unify pt t; check_let p; b) bs
  @ env

and rec_types env bs =
  incr Tree.level;
  let vars =
    List.map
      (function Tree.PVar x, _ -> x, Tree.newvar ()
        | _ -> Lexer.error "let rec: a name expected")
      bs
  in
  List.iter2 (fun (_, t) (_, e) -> unify t (infer (vars @ env) e)) vars bs;
  decr Tree.level;
  List.iter (fun (_, t) -> generalize t) vars;
  vars @ env

let type_item env (it, l) =
  try
    match it with
    | Tree.ILet (Tree.Nonrecursive, bs) -> let_types env bs
    | Tree.ILet (Tree.Recursive, bs) -> rec_types env bs
    | Tree.IExt (x, t, _) -> (x, Tree.of_texpr (ref []) t) :: env
    | Tree.IExn _ | Tree.IOpen _ | Tree.IAlias _ -> env
  with Error m -> Lexer.error (Printf.sprintf "line %d: %s" l m)

(* Scopes. A unit's names are M.x for the units after it; open M gives
 * a unit M's names as x, for itself alone. Stdlib is open in every
 * unit. A name's env and a type's env are scoped alike, as the types,
 * the constructors and the labels are (Tree.ml's Names) *)
let implicit u = u = "Stdlib"
let qualify u x = u ^ "." ^ x
(* M.x as a ^ x too, for this unit *)
let renamed tbl u a =
  let p = u ^ "." in
  let n = String.length p in
  Hashtbl.fold (fun x b acc ->
      if String.length x > n && String.sub x 0 n = p then
        (a ^ String.sub x n (String.length x - n), b) :: acc
      else acc)
    tbl []
  |> List.iter (fun (x, b) -> add_name tbl x b)
(* open M: M.x as x too *)
let opened tbl u = renamed tbl u ""
(* module A = M: M.x as A.x too *)
let aliased tbl a u = renamed tbl u (a ^ ".")
(* a unit's names, M.x, into the table for the units after it (and
 * Stdlib's x) *)
let export tbl u defs =
  List.iter (fun (x, b) ->
      Hashtbl.replace tbl (qualify u x) b;
      if implicit u then Hashtbl.replace tbl x b)
    (List.rev defs)

(* a unit's items typed: the names it defined, each in the table as it
 * comes *)
let type_unit items =
  List.fold_left (fun defs (it, l) ->
    match it with
    | Tree.IOpen u -> opened tglobals u; defs
    | Tree.IAlias (a, u) -> aliased tglobals a u; defs
    | _ ->
        let added = type_item [] (it, l) in
        List.iter (fun (x, t) -> add_name tglobals x t) (List.rev added);
        added @ defs) [] items
