(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Scope.mli *)

open Common

type ty = Tvar of string | Tarrow of ty * ty | Ttuple of ty list | Tconstr of tdecl * ty list
and tdecl = { tpath : string; tparams : string list; mutable tabbrev : ty option }

type var = { vname : string; vid : int }
type params = string option list
type global = { gpath : string list; gname : string; mutable gsym : string; gtype : ty option; mutable glabels : params }
type value = Local of var | Global of global | Prim of string * int * ty
type kind = Const of int | Block of int | Exn of global
type label = { lname : string; pos : int; mut : bool; size : int; ltype : string list * ty * ty; llabels : params }
type cons = {
  cname : string; kind : kind; arity : int; nconst : int; nblock : int; ctype : string list * ty list * ty;
  cinline : (string * label) list;
}

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

type expr = { e : exp; loc : int }

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
  | Erecord of int * (label * expr) list
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

and case = pattern * expr option * expr

type item =
  | Ieval of expr
  | Ivalue of bool * (pattern * expr) list * (var * global) list
  | Iexception of global * string
  | Iexternal of global * string * int * ty

exception Error of int * string

type loader = string -> Ast.source option

let error loc fmt = Printf.ksprintf (fun m -> raise (Error (loc, m))) fmt


(*****************************************************************************)
(* Environments *)
(*****************************************************************************)

(* a module's environment, computed when first needed: another unit's
 * .mli read then (OCaml's lazy, which mini-ml hasn't) *)
type 'a delayed = { mutable value : 'a option; compute : unit -> 'a }

(* each list the innermost name first; a module's env its exports,
 * computed when first named *)
type env = {
  values : (string * value) list;
  conses : (string * cons) list;
  labels : (string * label) list;
  types : (string * tdecl) list;
  modules : (string * modl) list;
}

and modl = { mpath : string list; menv : env delayed }

let delay compute = { value = None; compute }
let ready v = { value = Some v; compute = (fun () -> v) }
let force d = match d.value with Some v -> v | None -> let v = d.compute () in d.value <- Some v; v

let empty = { values = []; conses = []; labels = []; types = []; modules = [] }

(* inner's names in front of outer's: an open *)
let add inner outer =
  { values = inner.values @ outer.values; conses = inner.conses @ outer.conses; labels = inner.labels @ outer.labels;
    types = inner.types @ outer.types; modules = inner.modules @ outer.modules }

let add_value x v env = { env with values = (x, v) :: env.values }
let add_module m md env = { env with modules = (m, md) :: env.modules }
let symbol path x = String.concat "." (path @ [ x ])
let global_with ty path x = { gpath = path; gname = x; gsym = symbol path x; gtype = ty; glabels = [] }

(* the labels of a function's parameters (params), from its type, x:t
 * -> u -> ..., or from its definition, fun ~x y -> ... *)
let rec type_labels (t : Ast.ty) : params =
  match t with
  | Tarrow (Tlabel (l, _), r) -> Some l :: type_labels r
  | Tarrow (_, r) -> None :: type_labels r
  | _ -> []

let rec fun_labels (e : Ast.expr) : params =
  match e.e with
  | Efunction [ ({ p = Plabel (l, _); _ }, None, body) ] -> Some l :: fun_labels body
  | Efunction [ (_, None, body) ] -> None :: fun_labels body
  (* let f : x:t -> u = ... *)
  | Econstraint (e, t) -> (match type_labels t with [] -> fun_labels e | ls -> ls)
  | _ -> []

(* a local variable's, by its number *)
let var_labels : (int, params) Hashtbl.t = Hashtbl.create 64
let global path x = global_with None path x
let rec arity = function Ast.Tarrow (_, r) -> 1 + arity r | _ -> 0

let tdecl path x params = { tpath = symbol path x; tparams = params; tabbrev = None }
let int_d = tdecl [] "int" [] and char_d = tdecl [] "char" [] and string_d = tdecl [] "string" []
let float_d = tdecl [] "float" [] and bool_d = tdecl [] "bool" [] and unit_d = tdecl [] "unit" []
let exn_d = tdecl [] "exn" [] and array_d = tdecl [] "array" [ "a" ] and list_d = tdecl [] "list" [ "a" ]
let format_d = tdecl [] "format" [ "a"; "b"; "c" ]
(* every object type, < Cap.stdout; .. > (ix's capabilities): one type,
 * so that any two unify (plan_ml_bootstrap.md, decision 4, its first
 * step: OCaml checks the same code, for now) *)
let object_d = tdecl [] "< .. >" []
let int_t = Tconstr (int_d, []) and char_t = Tconstr (char_d, []) and string_t = Tconstr (string_d, [])
let float_t = Tconstr (float_d, []) and bool_t = Tconstr (bool_d, []) and unit_t = Tconstr (unit_d, [])
let exn_t = Tconstr (exn_d, [])

let exn_cons c g ts = c, { cname = c; kind = Exn g; arity = List.length ts; nconst = 0; nblock = 0; ctype = [], ts, exn_t; cinline = [] }

(* the predefined: the base types, bool, unit, list, and the runtime's
 * exceptions *)
let predef =
  let bool c k = c, { cname = c; kind = k; arity = 0; nconst = 2; nblock = 0; ctype = [], [], bool_t; cinline = [] } in
  let list = Tconstr (list_d, [ Tvar "a" ]) in
  let exn c ts = exn_cons c { gpath = []; gname = c; gsym = "caml_exn_" ^ c; gtype = None; glabels = [] } ts in
  { empty with
    types = List.map (fun d -> d.tpath, d) [ int_d; char_d; string_d; float_d; bool_d; unit_d; exn_d; array_d; list_d; format_d; object_d ];
    conses =
      [ bool "false" (Const 0); bool "true" (Const 1);
        "()", { cname = "()"; kind = Const 0; arity = 0; nconst = 1; nblock = 0; ctype = [], [], unit_t; cinline = [] };
        "[]", { cname = "[]"; kind = Const 0; arity = 0; nconst = 1; nblock = 1; ctype = [ "a" ], [], list; cinline = [] };
        "::", { cname = "::"; kind = Block 0; arity = 2; nconst = 1; nblock = 1; ctype = [ "a" ], [ Tvar "a"; list ], list; cinline = [] } ]
      @ [ exn "Match_failure" [ Ttuple [ string_t; int_t; int_t ] ]; exn "Assert_failure" [ Ttuple [ string_t; int_t; int_t ] ];
          exn "Out_of_memory" []; exn "Stack_overflow" []; exn "Invalid_argument" [ string_t ]; exn "Failure" [ string_t ];
          exn "Not_found" []; exn "Sys_error" [ string_t ]; exn "End_of_file" []; exn "Division_by_zero" [] ] }

(*****************************************************************************)
(* Units: another file's names, from its source *)
(*****************************************************************************)

let units : (string, modl option) Hashtbl.t = Hashtbl.create 16

(* the current unit's type declarations (not its interface's) *)
let own_types : (string, tdecl) Hashtbl.t = Hashtbl.create 16
let declaring = ref false
let loader : loader ref = ref (fun _ -> None)

(* x among a kind of the environment's names (qualified, below): outside
 * the definitions that follow, which use it at the types' and, after
 * them, at the others' *)
let found (env, x) loc id field what =
  match List.assoc_opt x (field env) with Some v -> v | None -> error loc "unbound %s %s" what (Ast.name id)

let rec unit_modl name =
  match Hashtbl.find_opt units name with
  | Some m -> m
  | None ->
      let m =
        Option.map (fun src ->
          { mpath = [ name ];
            menv = delay (fun () -> let scope = base name in match src with Ast.Signature s -> sig_env [ name ] scope s | Ast.Structure s -> str_env [ name ] scope s) })
          (!loader name)
      in
      Hashtbl.replace units name m;
      m

(* a unit's scope before its first item: the predefined, and
 * Pervasives's names, but in Pervasives *)
and base name =
  if name = "Pervasives" then predef
  else match unit_modl "Pervasives" with Some md -> add (force md.menv) predef | None -> error 0 "no Pervasives (-I the stdlib)"

(* what an interface exports; its types resolved in its scope *)
and sig_env path scope (items : Ast.signature) =
  snd
    (List.fold_left (fun (scope, exports) (it : Ast.sig_item) ->
      let both f = f scope, f exports in
      match it.s with
      | Sval (x, t) ->
          let g = global_with (Some (resolve scope it.sloc t)) path x in
          g.glabels <- type_labels t;
          both (add_value x (Global g))
      | Sexternal (x, t, p :: _) -> both (add_value x (Prim (p, arity t, resolve scope it.sloc t)))
      | Sexternal (x, _, []) -> error it.sloc "%s: an external without a primitive" x
      | Stype ds -> let d = decls path scope ds in both (add d)
      | Sexception (c, ts) ->
          let c = exn_cons c (global path c) (List.map (resolve scope it.sloc) ts) in
          both (fun env -> { env with conses = c :: env.conses })
      | Smodule (m, MTsig s) ->
          let md = { mpath = path @ [ m ]; menv = delay (fun () -> sig_env (path @ [ m ]) scope s) } in
          both (add_module m md)
      | Smodule (m, MTident _) -> error it.sloc "module %s: a module type's name (none in the subset)" m
      | Sopen id -> add (force (find_module scope it.sloc id).menv) scope, exports) (scope, empty) items)

(* what an implementation without an interface exports: its toplevel *)
and str_env path scope (items : Ast.structure) =
  let rec pvars (p : Ast.pattern) =
    match p.p with
    | Pvar x -> [ x ]
    | Palias (p, x) -> x :: pvars p
    | Ptuple ps -> List.concat_map pvars ps
    | Pconstruct (_, Some p) | Pconstraint (p, _) | Plabel (_, p) | Pexception p -> pvars p
    | Precord fs -> List.concat_map (fun (_, p) -> pvars p) fs
    | Por (p, _) -> pvars p
    | Pany | Pconst _ | Prange _ | Pconstruct (_, None) | Pextension _ -> []
  in
  snd
    (List.fold_left (fun (scope, exports) (it : Ast.item) ->
      let both f = f scope, f exports in
      match it.i with
      | Ieval _ -> scope, exports
      | Ivalue (_, bs) ->
          List.fold_left (fun acc (x, ls) ->
            let g = global path x in
            g.glabels <- ls;
            let f = add_value x (Global g) in
            f (fst acc), f (snd acc)) (scope, exports)
            (List.concat_map (fun ((p : Ast.pattern), e) ->
              List.map (fun x -> x, match p.p with Ast.Pvar _ -> fun_labels e | _ -> []) (pvars p)) bs)
      | Iexternal (x, t, p :: _) -> both (add_value x (Prim (p, arity t, resolve scope it.iloc t)))
      | Iexternal (x, _, []) -> error it.iloc "%s: an external without a primitive" x
      | Itype ds -> let d = decls path scope ds in both (add d)
      | Iexception (c, ts) ->
          let c = exn_cons c (global path c) (List.map (resolve scope it.iloc) ts) in
          both (fun env -> { env with conses = c :: env.conses })
      | Imodule (m, me) ->
          let rec md = function
            | Ast.Mstruct s -> { mpath = path @ [ m ]; menv = delay (fun () -> str_env (path @ [ m ]) scope s) }
            | Mident id -> find_module scope it.iloc id
            | Mconstraint (me, _) -> md me
          in
          both (add_module m (md me))
      | Iopen id -> add (force (find_module scope it.iloc id).menv) scope, exports) (scope, empty) items)

and find_module env loc (id : Ast.longid) =
  match id with
  | [] -> assert false
  | m :: rest ->
      let md =
        match List.assoc_opt m env.modules with
        | Some md -> md
        | None -> (match unit_modl m with Some md -> md | None -> error loc "unbound module %s" m)
      in
      List.fold_left (fun md m ->
        match List.assoc_opt m (force md.menv).modules with
        | Some md -> md
        | None -> error loc "unbound module %s" (symbol md.mpath m)) md rest

(* M.N.x: the environment x is looked up in, M.N's or env, and x *)
and qualified env loc (id : Ast.longid) =
  match List.rev id with
  | [] -> assert false
  | x :: rmods -> (if rmods = [] then env else force (find_module env loc (List.rev rmods)).menv), x

(* a type expression's constructors resolved *)
and resolve env loc (t : Ast.ty) =
  match t with
  | Tvar v -> Tvar v
  | Tlabel (_, t) -> resolve env loc t
  | Trecord _ -> error loc "an inline record: only a constructor's argument, C of { ... }"
  | Tarrow (a, b) -> Tarrow (resolve env loc a, resolve env loc b)
  | Ttuple ts -> Ttuple (List.map (resolve env loc) ts)
  (* int64 and int32, OCaml's names of the stdlib's Int64.t and Int32.t *)
  | Tconstr ([ ("int64" | "int32") as x ], []) when not (List.mem_assoc x env.types) ->
      resolve env loc (Tconstr ([ String.capitalize_ascii x; "t" ], []))
  | Tconstr (id, args) ->
      let d = found (qualified env loc id) loc id (fun e -> e.types) "type" in
      if List.length args <> List.length d.tparams then error loc "the type %s expects %d argument(s)" (Ast.name id) (List.length d.tparams);
      Tconstr (d, List.map (resolve env loc) args)

(* a group of type declarations (type a = ... and b = ...): each its
 * declaration first, then, all in scope, their abbreviations,
 * constructors (numbered) and labels; what the group adds *)
and decls path env (ds : Ast.type_decl list) =
  let tds = List.map (fun (d : Ast.type_decl) -> d, tdecl path d.tname d.tparams) ds in
  List.iter (fun (_, (td : tdecl)) -> if !declaring then Hashtbl.replace own_types td.tpath td) tds;
  let delta = { empty with types = List.rev_map (fun ((d : Ast.type_decl), td) -> d.tname, td) tds } in
  let env = add delta env in
  List.fold_left (fun delta ((d : Ast.type_decl), td) ->
    td.tabbrev <- Option.map (resolve env d.tloc) d.tmanifest;
    let res = Tconstr (td, List.map (fun v -> Tvar v) d.tparams) in
    match d.tkind with
    (* mlpp: *)
    | Hole -> error d.tloc "type %s = _: mlpp's, mini-ml rewrites it before (CLI's parse)" d.tname
    | Abstract -> delta
    | Variant cs ->
        let nconst = List.length (List.filter (fun (_, a) -> a = []) cs) in
        let nblock = List.length cs - nconst in
        let _, _, conses =
          List.fold_left (fun (ic, ib, acc) (c, args) ->
            let kind, ic, ib = if args = [] then Const ic, ic + 1, ib else Block ib, ic, ib + 1 in
            (* C of { ... }: one argument, a record of the type t.C, its labels C's (cinline) *)
            let cinline, args =
              match args with
              | [ Ast.Trecord ls ] ->
                  let h = tdecl path (d.tname ^ "." ^ c) d.tparams in
                  if !declaring then Hashtbl.replace own_types h.tpath h;
                  let hres = Tconstr (h, List.map (fun v -> Tvar v) d.tparams) and size = List.length ls in
                  List.mapi (fun pos (l, mut, t) ->
                    l, { lname = l; pos; mut; size; ltype = d.tparams, resolve env d.tloc t, hres; llabels = type_labels t }) ls, [ hres ]
              | _ -> [], List.map (resolve env d.tloc) args
            in
            let ctype = d.tparams, args, res in
            ic, ib, (c, { cname = c; kind; arity = List.length args; nconst; nblock; ctype; cinline }) :: acc) (0, 0, []) cs
        in
        { delta with conses = conses @ delta.conses }
    | Record ls ->
        let size = List.length ls in
        let labels = List.mapi (fun pos (l, mut, t) -> l, { lname = l; pos; mut; size; ltype = d.tparams, resolve env d.tloc t, res; llabels = type_labels t }) ls in
        { delta with labels = List.rev labels @ delta.labels }) delta tds

(* the type of a literal 3l or 3L: Int32's or Int64's t *)
let boxed_int_type m = resolve predef 0 (Tconstr ([ m; "t" ], []))

let lookup env loc id field what = found (qualified env loc id) loc id field what
let value env loc id = lookup env loc id (fun e -> e.values) "value"
let cons env loc id = lookup env loc id (fun e -> e.conses) "constructor"

(* a label; unqualified and not in scope, in the module of the record's
 * other labels ({ Dev.dname = n; dqid = q }) *)
let label env loc (ls : Ast.longid list) id =
  try lookup env loc id (fun e -> e.labels) "label"
  with Error _ as e -> (
    match id, List.find_opt (fun l -> List.length l > 1) ls with
    | [ x ], Some q -> lookup env loc (List.rev (x :: List.tl (List.rev q))) (fun e -> e.labels) "label"
    | _ -> raise e)

(* a label of C's inline record *)
let inline_label loc (c : cons) (l : Ast.longid) =
  let x = List.nth l (List.length l - 1) in
  match List.assoc_opt x c.cinline with Some l -> l | None -> error loc "%s has no field %s" c.cname x

(* a variable a pattern C r binds to C's inline record, by its number:
 * r.l, r.l <- v and { r with ... } take their labels there *)
let var_inline : (int, cons) Hashtbl.t = Hashtbl.create 64

(*****************************************************************************)
(* Patterns and expressions *)
(*****************************************************************************)

let fresh = ref 0
let new_var x = incr fresh; { vname = x; vid = !fresh }

(* C (a, b) of a constructor of 2 arguments; C _ of any *)
let split loc (c : cons) arg untuple any =
  match arg with
  | None when c.arity = 0 -> []
  | Some a when c.arity = 1 -> [ a ]
  | Some a when c.arity > 1 -> (
      match untuple a with
      | Some l when List.length l = c.arity -> l
      | _ -> if any a then List.init c.arity (fun _ -> a) else error loc "%s expects %d arguments" c.cname c.arity)
  | _ -> error loc "%s expects %d argument(s)" c.cname c.arity

(* a pattern, and the variables it binds *)
let rec pattern env (p : Ast.pattern) : pattern * (string * var) list =
  let many ps = let l = List.map (pattern env) ps in List.map fst l, List.concat_map snd l in
  match p.p with
  | Pany -> Pany, []
  | Pvar x -> let v = new_var x in Pvar v, [ x, v ]
  | Palias (p, x) -> let p, bs = pattern env p in let v = new_var x in Palias (p, v), (x, v) :: bs
  | Pconst c -> Pconst c, []
  | Plabel (_, q) -> pattern env q
  | Pexception _ -> error p.ploc "| exception: only a match's clause"
  | Prange (a, b) -> Prange (a, b), []
  | Ptuple ps -> let ps, bs = many ps in Ptuple ps, bs
  | Pconstruct (id, arg) -> (
      let c = cons env p.ploc id in
      match c.cinline, arg with
      (* C { l = p; ... }: the labels C's *)
      | _ :: _, Some { p = Precord fs; ploc } ->
          let fs = List.map (fun (l, q) -> let q, bs = pattern env q in (inline_label ploc c l, q), bs) fs in
          Pcons (c, [ Precord (List.map fst fs) ]), List.concat_map snd fs
      | _ ->
          let args = split p.ploc c arg (function { Ast.p = Ptuple l; _ } -> Some l | _ -> None) (fun a -> a.Ast.p = Pany) in
          let ps, bs = many args in
          (match c.cinline, ps with _ :: _, [ Pvar v ] -> Hashtbl.replace var_inline v.vid c | _ -> ());
          Pcons (c, ps), bs)
  | Precord fs ->
      let ls = List.map fst fs in
      let fs = List.map (fun (l, q) -> let q, bs = pattern env q in (label env p.ploc ls l, q), bs) fs in
      Precord (List.map fst fs), List.concat_map snd fs
  | Por (a, b) ->
      let a, ba = pattern env a and b, bb = pattern env b in
      if List.sort compare (List.map fst ba) <> List.sort compare (List.map fst bb) then error p.ploc "the two sides of | bind different variables";
      (* the right side's variables are the left's *)
      Por (a, rename (List.map (fun (x, v) -> v, List.assoc x ba) bb) b), ba
  | Pconstraint (q, t) ->
      let q, bs = pattern env q in
      (* (f : x:t -> u): a function given, its labels its type's *)
      (match q, type_labels t with Pvar v, (_ :: _ as ls) -> Hashtbl.replace var_labels v.vid ls | _ -> ());
      Pconstraint (q, resolve env p.ploc t), bs
  (* mlpp: *)
  | Pextension (n, _, _) -> error p.ploc "[%%%s]: mlpp's, as a clause's whole pattern" n

and rename m = function
  | Pvar v -> Pvar (List.assq v m)
  | Palias (p, v) -> Palias (rename m p, List.assq v m)
  | Ptuple ps -> Ptuple (List.map (rename m) ps)
  | Pcons (c, ps) -> Pcons (c, List.map (rename m) ps)
  | Precord fs -> Precord (List.map (fun (l, p) -> l, rename m p) fs)
  | Por (a, b) -> Por (rename m a, rename m b)
  | Pconstraint (p, t) -> Pconstraint (rename m p, t)
  | (Pany | Pconst _ | Prange _) as p -> p

let bind env bs = List.fold_left (fun env (x, v) -> add_value x (Local v) env) env bs

(* the labels of the function called, when it is a name's or a field's *)
let callee_labels env (f : Ast.expr) : params =
  match f.e with
  | Eident id -> (match value env f.eloc id with Local v -> (Hashtbl.find_opt var_labels v.vid ||| []) | Global g -> g.glabels | Prim _ -> [])
  | Efield (_, l) -> (label env f.eloc [ l ] l).llabels
  | _ -> []

(* the labels of a function's value: its definition's (fun ~x y ->),
 * the function's it names (let g = f), or what a call leaves of its
 * callee's (let g = f ~x:1) *)
let rec expr_labels env (e : Ast.expr) : params =
  let known f = try callee_labels env f with Error _ -> [] in
  match e.e with
  | Eident _ | Efield _ -> known e
  | Eapply (f, args) -> List.filteri (fun i _ -> i >= List.length args) (known f)
  | Econstraint (e', t) when type_labels t = [] -> expr_labels env e'
  | _ -> fun_labels e

(* let f ~x y = ...: f's labels *)
let defined_labels env (p : Ast.pattern) (e : Ast.expr) = match p.p with Pvar x -> [ x, expr_labels env e ] | _ -> []
let note_labels env p e vs =
  List.iter (fun (x, ls) -> match List.assoc_opt x vs with Some (v : var) when ls <> [] -> Hashtbl.replace var_labels v.vid ls | _ -> ())
    (defined_labels env p e)

(* a call's arguments in the order of the callee's parameters ps: one
 * with a label to the first free parameter of that label, another to
 * the first free one without; those beyond are in their order (the
 * result's arguments). As written when the callee has no label, and,
 * OCaml's rule, when no argument has a label and all are given.
 * Refused: a label for a callee Scope knows none of (a function's
 * value: only its type says its arguments' order, so it is written,
 * (f : x:t -> u), and the types stay without labels); a parameter
 * skipped (the call would be a function of it). *)
let arguments loc (ps : params) (args : Ast.expr list) : Ast.expr list =
  let split (a : Ast.expr) = match a.e with Elabel (l, e) -> Some l, e | _ -> None, a in
  let labeled = List.exists (fun a -> fst (split a) <> None) args in
  if not (List.exists Option.is_some ps) then begin
    List.iter (fun a -> match fst (split a) with
      | Some l -> error loc "~%s: the function's labels are not known here: give it its type, (f : %s:... -> ...)" l l
      | None -> ()) args;
    args
  end
  else if (not labeled) && List.length args >= List.length ps then args
  else begin
    let slots = Array.of_list (List.map (fun p -> p, None) ps) and beyond = ref [] in
    List.iter (fun a ->
      let l, e = split a in
      let rec place i =
        if i = Array.length slots then
          (match l with Some l -> error loc "~%s: the function has no such parameter left" l | None -> beyond := e :: !beyond)
        else match slots.(i) with p, None when p = l -> slots.(i) <- (p, Some e) | _ -> place (i + 1)
      in
      place 0) args;
    let rec given = function
      | (_, Some e) :: rest -> e :: given rest
      | (p, None) :: rest when List.exists (fun (_, e) -> Option.is_some e) rest ->
          error loc "the parameter %s is not given and a later one is: rewrite as a function of it"
            (match p with Some l -> "~" ^ l | None -> "without label")
      | _ -> []
    in
    given (Array.to_list slots) @ List.rev !beyond
  end

let rec expr env (x : Ast.expr) : expr =
  let mk e = { e; loc = x.eloc } in
  let ex = expr env in
  let fields fs = let ls = List.map fst fs in List.map (fun (l, e) -> label env x.eloc ls l, ex e) fs in
  let size = function ((l : label), _) :: _ -> l.size | [] -> error x.eloc "a record without fields" in
  (* r.l: l of the record's type, or, r bound by C r, of C's inline record *)
  let field (r : Ast.expr) l =
    let inline =
      match r.e with
      | Eident [ v ] -> (match List.assoc_opt v env.values with Some (Local v) -> Hashtbl.find_opt var_inline v.vid | _ -> None)
      | _ -> None
    in
    match inline with Some c -> inline_label x.eloc c l | None -> label env x.eloc [ l ] l
  in
  match x.e with
  | Eident id -> mk (Evar (value env x.eloc id))
  | Econst c -> mk (Econst c)
  | Elabel (l, _) -> error x.eloc "~%s: a labeled argument outside a call" l
  (* M.(e): M's names in front of the others, a variable's too, as open's *)
  | Eopen (m, e) -> expr (add (force (find_module env x.eloc m).menv) env) e
  | Elet (Nonrec, bs, body) ->
      let bs = List.map (fun (p, e) -> let e' = ex e in let p', vs = pattern env p in note_labels env p e vs; (p', e'), vs) bs in
      mk (Elet (false, List.map fst bs, expr (bind env (List.concat_map snd bs)) body))
  | Elet (Rec, bs, body) ->
      let bs, _, env = recursive env bs in
      mk (Elet (true, bs, expr env body))
  | Efunction cs -> mk (Efunction (cases env cs))
  | Eapply (f, args) ->
      mk (Eapply (ex f, List.map ex (arguments x.eloc (callee_labels env f) args)))
  | Ematch (e, cs) -> mk (Ematch (ex e, cases env cs))
  | Etry (e, cs) -> mk (Etry (ex e, cases env cs))
  | Etuple es -> mk (Etuple (List.map ex es))
  | Econstruct (id, arg) -> (
      let c = cons env x.eloc id in
      let own fs = List.map (fun (l, e) -> inline_label x.eloc c l, ex e) fs in
      match c.cinline, arg with
      (* C { l = e; ... }, C { r with l = e }: the labels C's *)
      | _ :: _, Some ({ e = Erecord fs; _ } as r) -> let fs = own fs in mk (Econs (c, [ { e = Erecord (size fs, fs); loc = r.eloc } ]))
      | _ :: _, Some ({ e = Ewith (r0, fs); _ } as r) -> let fs = own fs in mk (Econs (c, [ { e = Ewith (ex r0, size fs, fs); loc = r.eloc } ]))
      | _ ->
          let args = split x.eloc c arg (function { Ast.e = Etuple l; _ } -> Some l | _ -> None) (fun _ -> false) in
          mk (Econs (c, List.map ex args)))
  | Erecord fs -> let fs = fields fs in mk (Erecord (size fs, fs))
  | Ewith (e, fs) -> let fs = fields fs in mk (Ewith (ex e, size fs, fs))
  | Efield (e, l) -> mk (Efield (ex e, field e l))
  | Esetfield (e, l, v) ->
      let l = field e l in
      if not l.mut then error x.eloc "the field %s is not mutable" l.lname;
      mk (Esetfield (ex e, l, ex v))
  | Earray es -> mk (Earray (List.map ex es))
  | Eif (c, a, b) -> mk (Eif (ex c, ex a, Option.map ex b))
  | Eseq (a, b) -> mk (Eseq (ex a, ex b))
  | Ewhile (c, b) -> mk (Ewhile (ex c, ex b))
  | Efor (i, a, b, d, body) -> let v = new_var i in mk (Efor (v, ex a, ex b, d, expr (bind env [ i, v ]) body))
  | Econstraint (e, t) -> mk (Econstraint (ex e, resolve env x.eloc t))
  | Eassert e -> mk (Eassert (ex e))
  (* mlpp: *)
  | Eextension (n, _, _) -> error x.eloc "[%%%s]: mlpp's, mini-ml rewrites it before (CLI's parse)" n

and cases env cs =
  List.map (fun (p, g, e) ->
    let p, vs = pattern env p in
    let env = bind env vs in
    p, Option.map (expr env) g, expr env e) cs

(* let rec: the names first, each a variable *)
and recursive env bs =
  let vs = List.map (fun ((p : Ast.pattern), _) -> match p.p with Pvar x -> x, new_var x | _ -> error p.ploc "let rec: a name expected") bs in
  List.iter (fun (p, e) -> note_labels env p e vs) bs;
  let env = bind env vs in
  List.map2 (fun (_, v) (_, e) -> Pvar v, expr env e) vs bs, vs, env

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

(* the current unit's globals by symbol, the last defined; an earlier
 * one renamed M.x/2 *)
let defined : (string, global) Hashtbl.t = Hashtbl.create 64
let shadowed = ref 0

let define path x =
  let sym = symbol path x in
  (match Hashtbl.find_opt defined sym with
   | Some g -> incr shadowed; g.gsym <- Printf.sprintf "%s/%d" sym !shadowed
   | None -> ());
  let g = global path x in
  Hashtbl.replace defined sym g;
  g

(* a structure at path, in env: its items, and the names it exports *)
let rec structure path env (items : Ast.structure) : item list * env * env =
  let out = ref [] in
  let emit i = out := i :: !out in
  let env, exports =
    List.fold_left (fun (env, exports) (it : Ast.item) ->
      let both f = f env, f exports in
      match it.i with
      | Ieval e -> emit (Ieval (expr env e)); env, exports
      | Ivalue (r, bs) ->
          let labels = List.concat_map (fun (p, e) -> defined_labels env p e) bs in
          let bs, vs =
            if r = Rec then (let bs, vs, _ = recursive env bs in bs, vs)
            else (let l = List.map (fun (p, e) -> let e = expr env e in let p, vs = pattern env p in (p, e), vs) bs in List.map fst l, List.concat_map snd l)
          in
          let gs = List.map (fun (x, v) -> let g = define path x in g.glabels <- List.assoc_opt x labels ||| []; x, v, g) vs in
          emit (Ivalue (r = Rec, bs, List.map (fun (_, v, g) -> v, g) gs));
          List.fold_left (fun (env, exports) (x, _, g) -> add_value x (Global g) env, add_value x (Global g) exports) (env, exports) (List.rev gs)
      | Iexternal (x, t, p :: _) ->
          (* its own unit calls the primitive; another may name it by a val *)
          let ty = resolve env it.iloc t in
          emit (Iexternal (define path x, p, arity t, ty));
          both (add_value x (Prim (p, arity t, ty)))
      | Iexternal (x, _, []) -> error it.iloc "%s: an external without a primitive" x
      | Itype ds -> let d = decls path env ds in both (add d)
      | Iexception (c, ts) ->
          let g = define path c in
          emit (Iexception (g, c));
          let c = exn_cons c g (List.map (resolve env it.iloc) ts) in
          both (fun env -> { env with conses = c :: env.conses })
      | Imodule (m, me) ->
          let rec md = function
            | Ast.Mstruct s ->
                let items, _, sub = structure (path @ [ m ]) env s in
                List.iter emit items;
                { mpath = path @ [ m ]; menv = ready sub }
            | Mident id -> find_module env it.iloc id
            | Mconstraint (me, _) -> md me
          in
          let md = md me in
          both (add_module m md)
      | Iopen id -> add (force (find_module env it.iloc id).menv) env, exports) (env, empty) items
  in
  List.rev !out, env, exports

let own = ref None

let implementation load name items =
  loader := load;
  Hashtbl.reset units;
  Hashtbl.reset defined;
  own := None;
  Hashtbl.reset own_types;
  let scope = base name in
  declaring := true;
  let items, _, _ = structure [ name ] scope items in
  declaring := false;
  (* the unit's interface: its values' types, which Typing checks *)
  (match load name with
   | Some (Ast.Signature s) ->
       let exports = sig_env [ name ] (base name) s in
       own := Some (List.rev (List.filter_map (function x, Global { gtype = Some t; _ } | x, Prim (_, _, t) -> Some (x, t) | _ -> None) exports.values))
   | _ -> ());
  items

let interface () = !own
let own_type p = Hashtbl.find_opt own_types p

let units_named () = List.sort compare (Hashtbl.fold (fun n m acc -> if m <> None then n :: acc else acc) units [])

(*****************************************************************************)
(* -dscope *)
(*****************************************************************************)

let list f l = String.concat " " (List.map f l)
let var v = Printf.sprintf "%s/%d" v.vname v.vid

let show_value = function
  | Local v -> var v
  | Global g -> g.gsym
  | Prim (p, n, _) -> Printf.sprintf "%s/%d" p n

let show_cons c =
  match c.kind with
  | Const n -> Printf.sprintf "%s#%d" c.cname n
  | Block t -> Printf.sprintf "%s[%d]" c.cname t
  | Exn g -> Printf.sprintf "%s!%s" c.cname g.gsym

let show_label l = Printf.sprintf "%s.%d" l.lname l.pos

let rec show_pat = function
  | Pany -> "_"
  | Pvar v -> var v
  | Palias (p, v) -> Printf.sprintf "(as %s %s)" (show_pat p) (var v)
  | Pconst c -> Ast.const c
  | Prange (a, b) -> Printf.sprintf "(.. %C %C)" a b
  | Ptuple ps -> Printf.sprintf "(, %s)" (list show_pat ps)
  | Pcons (c, []) -> show_cons c
  | Pcons (c, ps) -> Printf.sprintf "(%s %s)" (show_cons c) (list show_pat ps)
  | Precord fs -> Printf.sprintf "{%s}" (list (fun (l, p) -> Printf.sprintf "(%s %s)" (show_label l) (show_pat p)) fs)
  | Por (a, b) -> Printf.sprintf "(| %s %s)" (show_pat a) (show_pat b)
  | Pconstraint (p, _) -> show_pat p

let rec show e =
  let fields fs = list (fun (l, e) -> Printf.sprintf "(%s %s)" (show_label l) (show e)) fs in
  match e.e with
  | Evar v -> show_value v
  | Econst c -> Ast.const c
  | Elet (r, bs, b) -> Printf.sprintf "(let%s (%s) %s)" (if r then "rec" else "") (bindings bs) (show b)
  | Efunction cs -> Printf.sprintf "(function %s)" (cases cs)
  | Eapply (f, args) -> Printf.sprintf "(%s %s)" (show f) (list show args)
  | Ematch (e, cs) -> Printf.sprintf "(match %s %s)" (show e) (cases cs)
  | Etry (e, cs) -> Printf.sprintf "(try %s %s)" (show e) (cases cs)
  | Etuple es -> Printf.sprintf "(, %s)" (list show es)
  | Econs (c, []) -> show_cons c
  | Econs (c, es) -> Printf.sprintf "(%s %s)" (show_cons c) (list show es)
  | Erecord (n, fs) -> Printf.sprintf "{%d %s}" n (fields fs)
  | Ewith (e, n, fs) -> Printf.sprintf "{%d %s with %s}" n (show e) (fields fs)
  | Efield (e, l) -> Printf.sprintf "(. %s %s)" (show e) (show_label l)
  | Esetfield (e, l, v) -> Printf.sprintf "(<- %s %s %s)" (show e) (show_label l) (show v)
  | Earray es -> Printf.sprintf "[|%s|]" (list show es)
  | Eif (c, a, None) -> Printf.sprintf "(if %s %s)" (show c) (show a)
  | Eif (c, a, Some b) -> Printf.sprintf "(if %s %s %s)" (show c) (show a) (show b)
  | Eseq (a, b) -> Printf.sprintf "(seq %s %s)" (show a) (show b)
  | Ewhile (c, b) -> Printf.sprintf "(while %s %s)" (show c) (show b)
  | Efor (v, a, b, d, body) -> Printf.sprintf "(for %s %s %s %s %s)" (var v) (show a) (if d = Upto then "to" else "downto") (show b) (show body)
  | Eassert e -> Printf.sprintf "(assert %s)" (show e)
  | Econstraint (e, _) -> show e

and bindings bs = list (fun (p, e) -> Printf.sprintf "(%s %s)" (show_pat p) (show e)) bs

and cases cs =
  list (fun (p, g, e) ->
    match g with
    | None -> Printf.sprintf "(%s %s)" (show_pat p) (show e)
    | Some g -> Printf.sprintf "(%s when %s %s)" (show_pat p) (show g) (show e)) cs

let show_item = function
  | Ieval e -> show e
  | Ivalue (r, bs, gs) ->
      Printf.sprintf "(let%s %s) -> %s" (if r then "rec" else "") (bindings bs) (list (fun (v, g) -> var v ^ ":" ^ g.gsym) gs)
  | Iexception (g, c) -> Printf.sprintf "(exception %s %s)" c g.gsym
  | Iexternal (g, p, n, _) -> Printf.sprintf "(external %s %s/%d)" g.gsym p n
