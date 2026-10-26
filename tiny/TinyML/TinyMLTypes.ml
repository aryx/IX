(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLTypes.mli *)
open TinyMLLexer
open TinyMLTree
open TinyMLParser

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let rec repr t = match t with TVar { contents = Link t } -> repr t | t -> t

let rec show t =
  match repr t with
  | TVar { contents = Unbound (n, _) } -> (Printf.sprintf "'_%d" n)
  | TCon ("->", [ a; b ]) -> (Printf.sprintf "(%s -> %s)" (show a) (show b))
  | TCon ("*", ts) -> "(" ^ String.concat " * " (List.map show ts) ^ ")"
  | TCon (c, []) -> c
  | TCon (c, ts) -> "(" ^ String.concat ", " (List.map show ts) ^ ") " ^ c
  | TVar _ -> "?"

(* x's variable in its own type is an error; a variable met at a lower
 * level takes it, so that it is generalized only where both are *)
let rec occurs r lv t =
  match repr t with
  | TVar r' when r == r' -> error "a recursive type"
  | TVar ({ contents = Unbound (n, l) } as r') ->
      if l > lv then r' := Unbound (n, lv)
  | TCon (_, ts) -> List.iter (occurs r lv) ts
  | TVar _ -> ()

let rec unify a b =
  match repr a, repr b with
  | TVar r, TVar r' when r == r' -> ()
  (* (old: one case, an or-pattern with names) *)
  | TVar ({ contents = Unbound (_, l) } as r), t -> occurs r l t; r := Link t
  | t, TVar ({ contents = Unbound (_, l) } as r) -> occurs r l t; r := Link t
  | TCon (c, ts), TCon (d, us) when c = d && List.length ts = List.length us ->
      List.iter2 unify ts us
  | a, b ->
      (* a type's second name (abbreviations): the type in its place *)
      let named = function TCon (c, ts) -> abbreviation c ts | _ -> None in
      match named a, named b with
      | Some t, _ -> unify t b
      | _, Some t -> unify a t
      | None, None ->
          error
            (Printf.sprintf "this has type %s but is used with type %s" (show a)
               (show b))

(* the variables deeper than the current let become parameters *)
let rec generalize t =
  match repr t with
  | TVar ({ contents = Unbound (n, l) } as r) when l > !level ->
      r := Unbound (n, generic)
  | TCon (_, ts) -> List.iter generalize ts
  | TVar _ -> ()

let instantiate t =
  let copies = Hashtbl.create 8 in
  let rec go t =
    match repr t with
    | TVar { contents = Unbound (n, l) } when l = generic -> (
        match Hashtbl.find_opt copies n with
        | Some v -> v
        | None -> let v = newvar () in Hashtbl.replace copies n v; v)
    | TCon (c, ts) -> TCon (c, List.map go ts)
    | t -> t
  in
  go t

(* the value restriction: only a value is generalized *)
let rec nonexpansive = function
  | Const _ | Var _ | Fun _ -> true
  | Con (_, l) -> List.for_all nonexpansive l
  | Tuple l -> List.for_all nonexpansive l
  | _ -> false

let con_type c =
  match instantiate (find_con c).scheme with
  | TCon (_, res :: args) -> res, args
  | _ -> invalid_arg "con_type"

(* l's label, in the record t already is when known (an annotation's,
 * a parameter's): type-directed, so that two records may share one;
 * else the latest record's, as OCaml's (a unit's own are read after the
 * interfaces of those before it)
 * (old: an error, "a field of several records: annotate which", when
 * a program was its files compiled whole) *)
let label_for l t =
  let known = match repr t with TCon (n, _) -> Some n | _ -> None in
  match
    List.filter (fun li -> known = None || known = Some li.lrec)
      (Hashtbl.find_all record_labels l)
  with
  | li :: _ -> li
  | [] ->
      error
        (Printf.sprintf "no field %s%s" l
           (match known with Some n -> " in " ^ n | None -> ""))
let label_type li =
  match instantiate li.lscheme with
  | TCon (_, [ r; f ]) -> r, f
  | _ -> invalid_arg "label_type"
let const_type = function
  | CInt _ -> int_t | CChar _ -> tcon "char" | CStr _ -> string_t

(* known: the type the value matched is already known to have (the
 * scrutinee's, an annotation's), so that a record pattern finds its
 * record when two records share a label; a fresh variable when none is
 * known. (A plain argument, not an optional one, which mini-ml, the
 * compiler mini-mk builds this file with, does not have) *)
let rec pat_type known p : ty * (string * ty) list =
  match p with
  | PAny -> newvar (), []
  | PVar x -> let t = newvar () in t, [ x, t ]
  | PConst c -> const_type c, []
  | PCon (c, ps) ->
      let res, args = con_type c in
      res,
      List.concat
        (List.map2
           (fun p t -> let pt, b = pat_type (newvar ()) p in unify pt t; b)
           ps args)
  | PTuple ps ->
      let l = List.map (fun p -> pat_type (newvar ()) p) ps in
      TCon ("*", List.map fst l), List.concat_map snd l
  | PAlias (p, x) -> let t, b = pat_type known p in t, (x, t) :: b
  | PAnnot (p, te) ->
      let ta = instantiate (of_texpr (ref []) te) in
      unify ta known;
      let t, b = pat_type ta p in unify t ta; t, b
  | PRecord (fs, idxs, n) ->
      let li0 = label_for (fst (List.hd fs)) known in
      let r = newvar () in
      let bs = List.map (fun (l, p) ->
        let li =
          match
            List.find_opt (fun li -> li.lrec = li0.lrec)
              (Hashtbl.find_all record_labels l)
          with
          | Some li -> li
          | None -> error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r', f = label_type li in
        unify r r';
        let pt, b = pat_type f p in
        unify pt f; li.idx, b) fs in
      idxs := List.map fst bs; n := List.length li0.lnames;
      r, List.concat_map snd bs
  | POr (a, b) ->
      let t, ba = pat_type (newvar ()) a and u, bb = pat_type (newvar ()) b in
      unify t u;
      if ba <> [] || bb <> [] then error "an or-pattern with variables";
      t, []

(* The names of the toplevel, by name, in a table: the units' before
 * this one, M.x, Stdlib's x too (open in all), and this unit's own and
 * what it opens, each added as it comes (a name added again hides the
 * one before, as OCaml's Hashtbl keeps them) and taken out at its end
 * ([unit_done]). The locals are a list, looked in first. Two of them,
 * the types' and the values' (below).
 * (old: all of them one list, Stdlib's at its end: each +, = or ^ found
 * after the whole program's names, most of a compilation's time) *)
let tglobals : (string, ty) Hashtbl.t = Hashtbl.create 1024
let find_name env tbl x =
  match List.assoc_opt x env with
  | Some b -> Some b
  | None -> Hashtbl.find_opt tbl x

(* a name of this unit's toplevel, until its end *)
let unit_names = ref []
let add_name tbl x b =
  Hashtbl.add tbl x b;
  unit_names := (fun () -> Hashtbl.remove tbl x) :: !unit_names
let unit_done () = List.iter (fun f -> f ()) !unit_names; unit_names := []

let rec infer env e : ty =
  match e with
  | Const c -> const_type c
  | Var (x, r) ->
      (match find_name env tglobals x with
       | Some t -> r := instantiate t; !r
       | None -> error ("unbound " ^ x))
  | Con (c, args) ->
      let res, targs = con_type c in
      List.iter2 (fun a t -> unify (infer env a) t) args targs;
      res
  | Tuple es -> TCon ("*", List.map (infer env) es)
  | App (f, args) ->
      List.fold_left
        (fun tf a -> let r = newvar () in unify tf (arrow (infer env a) r); r)
        (infer env f) args
  | Fun (xs, b) ->
      let ts = List.map (fun _ -> newvar ()) xs in
      List.fold_right arrow ts (infer (List.rev (List.combine xs ts) @ env) b)
  | Let (false, bs, b) -> infer (let_types env bs) b
  | Let (true, bs, b) -> infer (rec_types env bs) b
  | Match (e, cases) -> cases_type env (infer env e) cases
  | Try (e, cases) ->
      let t = infer env e in unify t (cases_type env (tcon "exn") cases); t
  | If (c, a, b) ->
      unify (infer env c) bool_t;
      let t = infer env a in
      unify t (infer env b);
      t
  | Seq (a, b) -> ignore (infer env a); infer env b
  | While (c, b) -> unify (infer env c) bool_t; ignore (infer env b); unit_t
  | For (x, a, b, _, body) ->
      unify (infer env a) int_t;
      unify (infer env b) int_t;
      ignore (infer ((x, int_t) :: env) body);
      unit_t
  | Dot (e, l, i) ->
      let t = infer env e in
      let li = label_for l t in
      let r, f = label_type li in
      i := li.idx; unify t r; f
  | SetDot (e, l, i, v) ->
      let t = infer env e in
      let li = label_for l t in
      if not li.mut then error (Printf.sprintf "the field %s is not mutable" l);
      let r, f = label_type li in
      i := li.idx; unify t r; unify (infer env v) f; unit_t
  | Record (fs, order) ->
      (* the record whose labels are exactly these *)
      let names = List.sort compare (List.map fst fs) in
      let li0 =
        match
          List.filter (fun li -> List.sort compare li.lnames = names)
            (Hashtbl.find_all record_labels (fst (List.hd fs)))
        with
        | li :: _ -> li
        | [] -> error ("no record has the fields " ^ (String.concat ", " names))
      in
      let r = newvar () in
      order := List.map (fun (l, e) ->
        let li =
          List.find (fun li -> li.lrec = li0.lrec)
            (Hashtbl.find_all record_labels l)
        in
        let r', f = label_type li in
        unify r r'; unify (infer env e) f; li.idx) fs;
      r
  | With (e, fs, idxs, n) ->
      (* the copy has e's type: a field cannot change a type parameter *)
      let t = infer env e in
      let li0 = label_for (fst (List.hd fs)) t in
      idxs := List.map (fun (l, v) ->
        let li =
          match
            List.find_opt (fun li -> li.lrec = li0.lrec)
              (Hashtbl.find_all record_labels l)
          with
          | Some li -> li
          | None -> error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r, f = label_type li in
        unify t r; unify (infer env v) f; li.idx) fs;
      n := List.length li0.lnames;
      t

and cases_type env t cases =
  let r = newvar () in
  List.iter (fun (p, g, e) ->
    let pt, bs = pat_type t p in
    unify pt t;
    let env = bs @ env in
    Option.iter (fun g -> unify (infer env g) bool_t) g;
    unify (infer env e) r) cases;
  r

and let_types env bs =
  List.concat_map (fun (p, e) ->
    incr level;
    let t = infer env e in
    decr level;
    match p with
    | PVar x ->
        if nonexpansive e then generalize t else unify (newvar ()) t; [ x, t ]
    | p -> let pt, b = pat_type t p in unify pt t; b) bs
  @ env

and rec_types env bs =
  incr level;
  let vars =
    List.map
      (function PVar x, _ -> x, newvar () | _ -> error "let rec: a name expected")
      bs
  in
  List.iter2 (fun (_, t) (_, e) -> unify t (infer (vars @ env) e)) vars bs;
  decr level;
  List.iter (fun (_, t) -> generalize t) vars;
  vars @ env

let type_item env (it, l) =
  try
    match it with
    | ILet (false, bs) -> let_types env bs
    | ILet (true, bs) -> rec_types env bs
    | IExt (x, t, _) -> (x, of_texpr (ref []) t) :: env
    | IExn _ | IOpen _ -> env
  with Failure m -> error (Printf.sprintf "line %d: %s" l m)

(* Scopes. A unit's names are M.x for the units after it; open M gives
 * a unit M's names as x, for itself alone. Stdlib is open in every
 * unit. A name's env and a type's env are scoped alike; the types, the
 * constructors and the labels are the program's, one name space
 * (old: every name the program's, open M read and left, List.map a
 * name with a dot) *)
let implicit u = u = "Stdlib"
let qualify u x = u ^ "." ^ x
(* open M: M.x as x too, for this unit *)
let opened tbl u =
  let p = u ^ "." in
  let n = String.length p in
  Hashtbl.fold (fun x b acc ->
      if String.length x > n && String.sub x 0 n = p then
        (String.sub x n (String.length x - n), b) :: acc
      else acc)
    tbl []
  |> List.iter (fun (x, b) -> add_name tbl x b)
(* a unit's names, M.x, into the table for the units after it (and
 * Stdlib's x); the list for them is the one before it *)
let export tbl u defs before =
  List.iter (fun (x, b) ->
      Hashtbl.replace tbl (qualify u x) b;
      if implicit u then Hashtbl.replace tbl x b)
    (List.rev defs);
  before

(* a unit's items typed: the env then, and the names it defined, each
 * in the table as it comes *)
let type_unit env items =
  List.fold_left (fun (env, defs) (it, l) ->
    match it with
    | IOpen u -> opened tglobals u; env, defs
    | _ ->
        let added = type_item [] (it, l) in
        List.iter (fun (x, t) -> add_name tglobals x t) (List.rev added);
        env, added @ defs) (env, []) items
