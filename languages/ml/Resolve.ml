(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Resolve.mli *)
open Common
open Scope

exception Error of int * string


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

(* Type-directed fields, the poor man's (as ocaml-light's): r.l and
 * r.l <- v take l in r's type when Typing knows it by then (an
 * annotation, (r : M.t), or what came before), whatever is in scope. So
 * a record type's labels are kept by the type's path, and a field of
 * no type in scope is left to Typing, without a position (deferred). *)
let fields_of_type : (string, (string * label) list) Hashtbl.t = Hashtbl.create 64
let conses_of_type : (string, (string * cons) list) Hashtbl.t = Hashtbl.create 64

let rec type_field (d : tdecl) x =
  match Hashtbl.find_opt fields_of_type d.tpath, d.tabbrev with
  | Some ls, _ -> List.assoc_opt x ls
  | None, Some (Tconstr (d', _)) -> type_field d' x
  | None, _ -> None

let deferred x = { lname = x; pos = -1; mut = true; size = 0; ltype = [], Tvar "_", Tvar "_"; llabels = [] }

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
(* OCaml's: ('a, 'b, 'c, 'd) format4, 'd what the function gives in the
 * end (ksprintf's continuation's), 'c a %a printer's; and format, the
 * two the same *)
let format4_d = tdecl [] "format4" [ "a"; "b"; "c"; "d" ]
let format_d =
  { (tdecl [] "format" [ "a"; "b"; "c" ]) with tabbrev = Some (Tconstr (format4_d, [ Tvar "a"; Tvar "b"; Tvar "c"; Tvar "c" ])) }
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
    types = List.map (fun d -> d.tpath, d) [ int_d; char_d; string_d; float_d; bool_d; unit_d; exn_d; array_d; list_d; format_d; format4_d; object_d ];
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
        (match res with Tconstr (td, _) -> Hashtbl.replace conses_of_type td.tpath conses | _ -> ());
        { delta with conses = conses @ delta.conses }
    | Record ls ->
        let size = List.length ls in
        let labels = List.mapi (fun pos (l, mut, t) -> l, { lname = l; pos; mut; size; ltype = d.tparams, resolve env d.tloc t, res; llabels = type_labels t }) ls in
        (match res with Tconstr (td, _) -> Hashtbl.replace fields_of_type td.tpath labels | _ -> ());
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
(*****************************************************************************)
(* The expected type *)
(*****************************************************************************)

(* Type-directed constructors and records, the poor man's. OCaml takes
 * Tree in Object.hash (Tree []), or the fields of { vname = x; vid = n }
 * under : Scope.var, from the type it expects there, whatever is in
 * scope. Here the expected type (want, when one is written) comes down with
 * the expression or the pattern, and is only what is written: an
 * annotation, a val's type, a field's or a constructor's argument's.
 * Nothing is inferred (Typing is after, and checks the choice): where
 * no type is written, the name is the scope's, or unbound, and the
 * answer is an annotation, on a parameter or a function's result. *)

(* a declared type's parameters replaced: 'a list's 'a *)
let rec subst m = function
  | Tvar v -> (match List.assoc_opt v m with Some t -> t | None -> Tvar v)
  | Tarrow (a, b) -> Tarrow (subst m a, subst m b)
  | Ttuple ts -> Ttuple (List.map (subst m) ts)
  | Tconstr (d, ts) -> Tconstr (d, List.map (subst m) ts)

(* a type's abbreviations opened, at its head *)
let rec head = function
  | Tconstr ({ tabbrev = Some t; tparams; _ }, args) when List.length tparams = List.length args -> head (subst (List.combine tparams args) t)
  | t -> t

(* the type's own constructor or label named x (table: which), with the
 * values of the type's parameters *)
let in_type table (want : ty option) x =
  match Option.map head want with
  | Some (Tconstr (d, args)) -> (
      match Option.bind (Hashtbl.find_opt table d.tpath) (List.assoc_opt x) with
      | Some c -> Some (c, if List.length d.tparams = List.length args then List.combine d.tparams args else [])
      | None -> None)
  | _ -> None

(* what is written of a variable's type (by its number), of a global's
 * of this unit (by its symbol) *)
let var_types : (int, ty) Hashtbl.t = Hashtbl.create 64
let global_types : (string, ty) Hashtbl.t = Hashtbl.create 64
let note_type (v : var) = function Some t -> Hashtbl.replace var_types v.vid t | None -> ()

let tuple_types (want : ty option) l =
  match Option.map head want with
  | Some (Ttuple ts) when List.length ts = List.length l -> List.map Option.some ts
  | _ -> List.map (fun _ -> None) l

(* a constructor: the expected type's when it has one of that name,
 * else the scope's; and its arguments' types, the type's parameters
 * replaced when the expected type gives them *)
let cons_in env loc (want : ty option) (id : Ast.longid) : cons * ty option list =
  let c =
    match id with
    | [ x ] -> (
        match in_type conses_of_type want x, Option.map head want with
        | Some (c, _), _ -> c
        (* an exception wanted: the scope's last of that name, not a type's constructor *)
        | None, Some (Tconstr (d, _)) when d.tpath = exn_d.tpath && List.exists (fun (y, (c : cons)) -> y = x && (match c.kind with Exn _ -> true | _ -> false)) env.conses ->
            snd (List.find (fun (y, (c : cons)) -> y = x && (match c.kind with Exn _ -> true | _ -> false)) env.conses)
        | None, _ -> (try cons env loc id with Error _ ->
            error loc "unbound constructor %s: if it is another module's, its type is not written here: annotate (a parameter, the function's result), or write M.%s" x x))
    | _ -> cons env loc id
  in
  let params, args, res = c.ctype in
  let m =
    match Option.map head want, res with
    | Some (Tconstr (d, ts)), Tconstr (d', _) when d.tpath = d'.tpath && List.length ts = List.length params -> List.combine params ts
    | _ -> []
  in
  c, List.map (fun a -> Some (subst m a)) args

(* a record's label: the expected type's when it has that field; else,
 * in { M.l = ...; l' = ... }, M.l's type's; else the scope's.
 * And the field's type *)
let label_in env loc ~closed (want : ty option) (ls : Ast.longid list) (l : Ast.longid) : label * ty option =
  let of_type want = match l with [ x ] -> in_type fields_of_type want x | _ -> None in
  let sibling () =
    match List.find_opt (fun l -> List.length l > 1) ls with
    | Some q -> (try let _, _, res = (label env loc ls q).ltype in of_type (Some res) with Error _ -> None)
    | None -> None
  in
  match (match of_type want with Some r -> Some r | None -> sibling ()) with
  | Some (lb, m) -> let _, t, _ = lb.ltype in lb, Some (subst m t)
  | None ->
      (* no type to go by: of the scope's types with that label, the last
       * declared that has all the record's, and no other when the record
       * is written whole (closed); OCaml's rule. Else the last *)
      let has_all (lb : label) =
        match lb.ltype with
        | _, _, Tconstr (d, _) ->
            List.for_all (function [ x ] -> type_field d x <> None | _ -> true) ls && ((not closed) || lb.size = List.length ls)
        | _ -> true
      in
      let lb =
        match l, List.find_opt (fun (y, lb) -> [ y ] = l && has_all lb) env.labels with
        | [ _ ], Some (_, lb) -> lb
        | _ -> label env loc ls l
      in
      let _, t, _ = lb.ltype in
      lb, Some t

(* M.C ... | C' ...: where no type is expected, M.C's for what follows
 * it, an or-pattern's other side or a match's next clauses *)
let rec after (want : ty option) = function
  | Pcons ({ ctype = _, _, res; _ }, _) when (match Option.map head want with Some (Tconstr _) -> false | _ -> true) -> Some res
  | Por (a, _) | Palias (a, _) -> after want a
  | _ -> want

let split loc (c : cons) arg untuple any =
  match arg with
  | None when c.arity = 0 -> []
  | Some a when c.arity = 1 -> [ a ]
  | Some a when c.arity > 1 -> (
      match untuple a with
      | Some l when List.length l = c.arity -> l
      | _ -> if any a then List.init c.arity (fun _ -> a) else error loc "%s expects %d arguments" c.cname c.arity)
  | _ -> error loc "%s expects %d argument(s)" c.cname c.arity

(* a pattern, and the variables it binds; want: the type expected, where written *)
let rec pattern env (want : ty option) (p : Ast.pattern) : pattern * (string * var) list =
  let many wants ps = let l = List.map2 (pattern env) wants ps in List.map fst l, List.concat_map snd l in
  match p.p with
  | Pany -> Pany, []
  | Pvar x -> let v = new_var x in note_type v want; Pvar v, [ x, v ]
  | Palias (p, x) -> let p, bs = pattern env want p in let v = new_var x in note_type v want; Palias (p, v), (x, v) :: bs
  | Pconst c -> Pconst c, []
  | Plabel (_, q) -> pattern env want q
  | Pexception _ -> error p.ploc "| exception: only a match's clause"
  | Prange (a, b) -> Prange (a, b), []
  | Ptuple ps -> let ps, bs = many (tuple_types want ps) ps in Ptuple ps, bs
  | Pconstruct (id, arg) -> (
      let c, wants = cons_in env p.ploc want id in
      match c.cinline, arg with
      (* C { l = p; ... }: the labels C's *)
      | _ :: _, Some { p = Precord fs; ploc } ->
          let fs = List.map (fun (l, q) -> let q, bs = pattern env None q in (inline_label ploc c l, q), bs) fs in
          Pcons (c, [ Precord (List.map fst fs) ]), List.concat_map snd fs
      | _ ->
          let args = split p.ploc c arg (function { Ast.p = Ptuple l; _ } -> Some l | _ -> None) (fun a -> a.Ast.p = Pany) in
          let ps, bs = many wants args in
          (match c.cinline, ps with _ :: _, [ Pvar v ] -> Hashtbl.replace var_inline v.vid c | _ -> ());
          Pcons (c, ps), bs)
  | Precord fs ->
      let ls = List.map fst fs in
      let fs = List.map (fun (l, q) -> let lb, t = label_in env p.ploc ~closed:false want ls l in let q, bs = pattern env t q in (lb, q), bs) fs in
      Precord (List.map fst fs), List.concat_map snd fs
  | Por (a, b) ->
      let a, ba = pattern env want a in
      let b, bb = pattern env (after want a) b in
      if List.sort compare (List.map fst ba) <> List.sort compare (List.map fst bb) then error p.ploc "the two sides of | bind different variables";
      (* the right side's variables are the left's *)
      Por (a, rename (List.map (fun (x, v) -> v, List.assoc x ba) bb) b), ba
  | Pconstraint (q, t) ->
      let ty = resolve env p.ploc t in
      let q, bs = pattern env (Some ty) q in
      (* (f : x:t -> u): a function given, its labels its type's *)
      (match q, type_labels t with Pvar v, (_ :: _ as ls) -> Hashtbl.replace var_labels v.vid ls | _ -> ());
      Pconstraint (q, ty), bs
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
  | Efield (_, l) -> (try (label env f.eloc [ l ] l).llabels with Error _ -> [])
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

(* a parameter's type variables, from what is written of its argument's
 * type: 'a ref against t ref gives 'a (the first found is kept) *)
let rec matched m (p : ty) (a : ty option) =
  let both m ps ts = if List.length ps = List.length ts then List.fold_left2 (fun m p t -> matched m p (Some t)) m ps ts else m in
  match p, Option.map head a with
  (* another variable says nothing ('a against a parameter's own 'a) *)
  | Tvar v, Some t when v <> "_" && (match t with Tvar _ -> false | _ -> true) && not (List.mem_assoc v m) -> (v, t) :: m
  | Tconstr (d, ps), Some (Tconstr (d', ts)) when d.tpath = d'.tpath -> both m ps ts
  | Ttuple ps, Some (Ttuple ts) -> both m ps ts
  | Tarrow (p1, p2), Some (Tarrow (a1, a2)) -> both m [ p1; p2 ] [ a1; a2 ]
  | _ -> m

(* The type written for an expression, if any, read on the expression
 * once its names are resolved: a name's, a call's result, a field's, a
 * constructor's, a function's from its parameters' annotations; a
 * match's, an if's, a let's from their first result *)
let rec type_of (e : expr) : ty option =
  let unknown = Tvar "_" in
  match e.e with
  | Evar (Local v) -> Hashtbl.find_opt var_types v.vid
  | Evar (Global { gtype = Some t; _ }) | Evar (Prim (_, _, t)) | Econstraint (_, t) -> Some t
  | Evar (Global g) -> Hashtbl.find_opt global_types g.gsym
  | Eapply (f, args) ->
      (* a type variable is what an argument's type says of it (!r: 'a ref against r's) *)
      let rec go m t = function
        | [] -> Option.map (subst m) t
        | a :: rest -> (match Option.map head t with Some (Tarrow (p, r)) -> go (matched m p (type_of a)) (Some r) rest | _ -> None)
      in
      go [] (type_of f) args
  | Efield (r, l) -> field_type (type_of r) l
  | Etuple es -> Some (Ttuple (List.map (fun e -> type_of e ||| unknown) es))
  (* its type's parameters what its arguments' types say: Some x is of x's type option *)
  | Econs ({ ctype = _, targs, res; _ }, args) when List.length targs = List.length args ->
      Some (subst (List.fold_left2 (fun m t a -> matched m t (type_of a)) [] targs args) res)
  | Econs ({ ctype = _, _, res; _ }, _) -> Some res
  | Efunction ((p, _, body) :: rest) ->
      let rec param = function
        | Pconstraint (_, t) -> t
        | Pcons ({ ctype = _, _, res; _ }, _) -> res
        | Pvar v -> Hashtbl.find_opt var_types v.vid ||| unknown
        | Palias (p, _) | Por (p, _) -> param p
        | Ptuple ps -> Ttuple (List.map param ps)
        | _ -> unknown
      in
      Some (Tarrow (param p, if rest = [] then type_of body ||| unknown else unknown))
  | Erecord (_, (l, _) :: _) | Ewith (_, _, (l, _) :: _) -> let _, _, res = l.ltype in Some res
  | Ematch (_, (_, _, b) :: _) | Etry (b, _) | Eif (_, b, _) | Eseq (_, b) | Elet (_, _, b) -> type_of b
  | _ -> None

(* r.l's type, r's type being t: the field's in t when it has it, else
 * the label's own *)
and field_type (t : ty option) (l : label) =
  match in_type fields_of_type t l.lname with
  | Some (l, m) -> let _, ft, _ = l.ltype in Some (subst m ft)
  | None -> if l.pos < 0 then None else (let _, ft, _ = l.ltype in Some ft)

(* a function's type as its definition writes it, before its body is
 * resolved (a let rec's names): its parameters' annotations, its result's *)
let rec written env (e : Ast.expr) : ty =
  let resolved loc t = try resolve env loc t with Error _ -> Tvar "_" in
  match e.e with
  | Efunction [ (p, None, body) ] ->
      let rec param (p : Ast.pattern) = match p.p with Pconstraint (_, t) -> resolved p.ploc t | Plabel (_, q) -> param q | _ -> Tvar "_" in
      Tarrow (param p, written env body)
  | Econstraint (_, t) -> resolved e.eloc t
  | _ -> Tvar "_"

(* an expression; want: the type expected, where written *)
let rec expr env (want : ty option) (x : Ast.expr) : expr =
  let mk e = { e; loc = x.eloc } in
  let ex = expr env None in
  let fields ~closed want fs = let ls = List.map fst fs in List.map (fun (l, e) -> let lb, t = label_in env x.eloc ~closed want ls l in lb, expr env t e) fs in
  let size = function ((l : label), _) :: _ -> l.size | [] -> error x.eloc "a record without fields" in
  (* r.l: l of the record's type, or, r bound by C r, of C's inline record *)
  let field (r : Ast.expr) l =
    let inline =
      match r.e with
      | Eident [ v ] -> (match List.assoc_opt v env.values with Some (Local v) -> Hashtbl.find_opt var_inline v.vid | _ -> None)
      | _ -> None
    in
    (* a copy: Typing writes there the position of the record's type's field *)
    match inline, l with
    | Some c, _ -> inline_label x.eloc c l
    | None, [ name ] -> (try { (label env x.eloc [ l ] l) with lname = name } with Error _ -> deferred name)
    | None, _ -> label env x.eloc [ l ] l
  in
  match x.e with
  | Eident id -> mk (Evar (value env x.eloc id))
  | Econst c -> mk (Econst c)
  | Elabel (l, _) -> error x.eloc "~%s: a labeled argument outside a call" l
  (* M.(e): M's names in front of the others, a variable's too, as open's *)
  | Eopen (m, e) -> expr (add (force (find_module env x.eloc m).menv) env) want e
  | Elet (Nonrec, bs, body) ->
      let bs = List.map (fun (p, e) -> let p', e', vs = binding env p e in note_labels env p e vs; (p', e'), vs) bs in
      mk (Elet (false, List.map fst bs, expr (bind env (List.concat_map snd bs)) want body))
  | Elet (Rec, bs, body) ->
      let bs, _, env = recursive env bs in
      mk (Elet (true, bs, expr env want body))
  | Efunction cs -> (
      match Option.map head want with
      | Some (Tarrow (a, r)) -> mk (Efunction (cases env (Some a) (Some r) cs))
      | _ -> mk (Efunction (cases env None None cs)))
  | Eapply (f, args) ->
      let args = arguments x.eloc (callee_labels env f) args in
      let f = ex f in
      (* each argument under its parameter's type, a type variable what an
       * earlier argument says of it (k = Commit: 'a is k's type) *)
      let rec go m t = function
        | [] -> []
        | a :: rest -> (
            match Option.map head t with
            | Some (Tarrow (p, r)) -> let a = expr env (Some (subst m p)) a in a :: go (matched m p (type_of a)) (Some r) rest
            | _ -> ex a :: go m None rest)
      in
      mk (Eapply (f, go [] (type_of f) args))
  | Ematch (e, cs) -> let e = ex e in mk (Ematch (e, cases env (type_of e) want cs))
  | Etry (e, cs) -> mk (Etry (expr env want e, cases env (Some exn_t) want cs))
  | Etuple es -> mk (Etuple (List.map2 (expr env) (tuple_types want es) es))
  | Econstruct (id, arg) -> (
      let c, wants = cons_in env x.eloc want id in
      let own fs = List.map (fun (l, e) -> inline_label x.eloc c l, ex e) fs in
      match c.cinline, arg with
      (* C { l = e; ... }, C { r with l = e }: the labels C's *)
      | _ :: _, Some ({ e = Erecord fs; _ } as r) -> let fs = own fs in mk (Econs (c, [ { e = Erecord (size fs, fs); loc = r.eloc } ]))
      | _ :: _, Some ({ e = Ewith (r0, fs); _ } as r) -> let fs = own fs in mk (Econs (c, [ { e = Ewith (ex r0, size fs, fs); loc = r.eloc } ]))
      | _ ->
          let args = split x.eloc c arg (function { Ast.e = Etuple l; _ } -> Some l | _ -> None) (fun _ -> false) in
          match c.cname, wants, args with
          (* [ M.C; C'; ... ]: where no type is expected, M.C's for the elements after *)
          | "::", [ w; _ ], [ a; rest ] ->
              let a = expr env w a in
              let rest_want = match type_of a, Option.map head w with
                | Some t, (None | Some (Tvar _)) -> Some (Tconstr (list_d, [ t ]))
                | _ -> List.nth wants 1 in
              mk (Econs (c, [ a; expr env rest_want rest ]))
          | _ -> mk (Econs (c, List.map2 (expr env) wants args)))
  | Erecord fs -> let fs = fields ~closed:true want fs in mk (Erecord (size fs, fs))
  | Ewith (e, fs) ->
      let e = expr env want e in
      let fs = fields ~closed:false (match Option.map head want with Some (Tconstr _) -> want | _ -> type_of e) fs in
      mk (Ewith (e, size fs, fs))
  | Efield (e, l) -> mk (Efield (ex e, field e l))
  | Esetfield (e, l, v) ->
      let r = ex e and l = field e l in
      mk (Esetfield (r, l, expr env (field_type (type_of r) l) v))
  | Earray es -> mk (Earray (List.map ex es))
  | Eif (c, a, b) ->
      let c = ex c and a = expr env want a in
      (* then M.C else C': where no type is expected, the first's for the second *)
      let want = match Option.map head want with None | Some (Tvar _) -> type_of a | _ -> want in
      mk (Eif (c, a, Option.map (expr env want) b))
  | Eseq (a, b) -> mk (Eseq (ex a, expr env want b))
  | Ewhile (c, b) -> mk (Ewhile (ex c, ex b))
  | Efor (i, a, b, d, body) -> let v = new_var i in mk (Efor (v, ex a, ex b, d, expr (bind env [ i, v ]) None body))
  | Econstraint (e, t) -> let t = resolve env x.eloc t in mk (Econstraint (expr env (Some t) e, t))
  | Eassert e -> mk (Eassert (ex e))
  (* mlpp: *)
  | Eextension (n, _, _) -> error x.eloc "[%%%s]: mlpp's, mini-ml rewrites it before (CLI's parse)" n

(* clauses: want_pat the type expected of their patterns, want of their results *)
and cases env want_pat want cs =
  let want_pat = ref want_pat and want = ref want in
  List.map (fun (p, g, e) ->
    let p, vs = pattern env !want_pat p in
    want_pat := after !want_pat p;
    let env = bind env vs in
    let g = Option.map (expr env None) g in
    let e = expr env !want e in
    (* -> M.C | ... -> C': where no type is expected, the first result's for those after *)
    (match Option.map head !want with None | Some (Tvar _) -> want := type_of e | _ -> ());
    p, g, e) cs

(* let p = e: e under p's annotation; p under it, or under what is
 * written of e's type (a function's parameters, a call's result) *)
and binding env (p : Ast.pattern) (e : Ast.expr) =
  let want = match p.p with Pconstraint (_, t) -> Some (resolve env p.ploc t) | _ -> None in
  let e' = expr env want e in
  let p', vs = pattern env (match want with Some _ -> want | None -> type_of e') p in
  p', e', vs

(* let rec: the names first, each a variable *)
and recursive env bs =
  let vs = List.map (fun ((p : Ast.pattern), _) -> match p.p with Pvar x -> x, new_var x | _ -> error p.ploc "let rec: a name want") bs in
  List.iter (fun (p, e) -> note_labels env p e vs) bs;
  List.iter2 (fun (_, v) (_, e) -> note_type v (Some (written env e))) vs bs;
  let env = bind env vs in
  List.map2 (fun (_, v) (_, e) -> Pvar v, expr env None e) vs bs, vs, env

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
      | Ieval e -> emit (Ieval (expr env None e)); env, exports
      | Ivalue (r, bs) ->
          let labels = List.concat_map (fun (p, e) -> defined_labels env p e) bs in
          let bs, vs =
            if r = Rec then (let bs, vs, _ = recursive env bs in bs, vs)
            else (let l = List.map (fun (p, e) -> let p, e, vs = binding env p e in (p, e), vs) bs in List.map fst l, List.concat_map snd l)
          in
          let gs = List.map (fun (x, (v : var)) ->
            let g = define path x in
            g.glabels <- List.assoc_opt x labels ||| [];
            (match Hashtbl.find_opt var_types v.vid with Some t -> Hashtbl.replace global_types g.gsym t | None -> ());
            x, v, g) vs in
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
