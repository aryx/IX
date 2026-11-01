(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower_il.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types
open Il_functions
open Il_exprs

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

(* a function's method declared (a let rec's all first, so that each
 * calls the others), its body made later *)
let declare (c : c) (env : env) (globals : (Scope.var * Scope.global) list) (v : Scope.var) (d : Scope.expr) : fn =
  let ps, cases, body = params d in
  let rty = match cases with Some ((_, _, b) :: _) -> type_of b | _ -> type_of body in
  (* its type's variables: a generic method's parameters, !!0... *)
  let gvars = tvars_of (List.fold_right (fun ((_, a) : Scope.var option * Scope.ty) (b : Scope.ty) -> Scope.Tarrow (a, b)) ps rty) in
  c.tvars <- List.mapi (fun (i : int) (n : string) -> (n, S.MVar i)) gvars;
  let params = List.map (fun ((v, ty) : Scope.var option * Scope.ty) -> (v, cts c d.loc ty)) ps in
  (* (void: a function whose body is a raise, not one whose first case is) *)
  let ret = if cases = None && is_raise body then S.Void else cts c body.loc rty in
  let sg = { (static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret) with generic = List.length gvars } in
  c.tvars <- [];
  let tok = W.method_def c.w c.cls v.vname 0x0096 sg in
  List.iteri (fun (i : int) (_ : string) -> W.generic_param c.w tok i (Printf.sprintf "T%d" i)) gvars;
  let f = { tok; fname = v.vname; params; ptys = List.map snd ps; rty; cases; body; gvars } in
  Hashtbl.replace env.by_var v.vid f;
  (match global_of globals v with Some g -> Hashtbl.replace env.by_sym g.gsym f | None -> ());
  f

let is_function_type (t : Scope.ty) : bool = match t with Tarrow _ -> true | _ -> false

(* a pattern's variables *)
let rec pattern_vars (p : Scope.pattern) : Scope.var list =
  match p with
  | Pany | Pconst _ | Prange _ -> []
  | Pvar v -> [ v ]
  | Palias (p, v) -> v :: pattern_vars p
  | Ptuple ps | Pcons (_, ps) -> List.concat_map pattern_vars ps
  | Precord fs -> List.concat_map (fun ((_, p) : Scope.label * Scope.pattern) -> pattern_vars p) fs
  | Por (p, _) | Pconstraint (p, _) -> pattern_vars p

let define (c : c) (env : env) (f : fn) : unit =
  c.tvars <- List.mapi (fun (i : int) (n : string) -> (n, S.MVar i)) f.gvars;
  let k = new_code () in
  let n = ref 0 and last = ref (-1) in
  List.iter
    (fun ((v, ty) : Scope.var option * S.t) ->
      if ty <> S.Void then begin
        (match v with Some v -> Hashtbl.replace k.args v.vid !n | None -> ());
        last := !n;
        incr n
      end)
    f.params;
  (match f.cases with
   | None -> tail_expr c env k f.body false
   | Some cases ->
       (* (the last argument matched: the function's cases a match's) *)
       let arg = !last in
       (* (its argument's own type: a constructor's pattern says the
        * declared one, 'a tree, not int tree) *)
       let pty = match List.rev f.ptys with t :: _ -> t | [] -> (match cases with (p, _, _) :: _ -> pattern_type p | [] -> Resolve.unit_t) in
       tail_cases c env k (fun () -> if arg >= 0 then emit k (Il.Ldarg arg)) pty cases false);
  finish c k f.tok;
  c.tvars <- []

(* an assembly being made: its writer, what its units share (the
 * members made, the functions and values by symbol), its units' init
 * methods in order *)
type assembly = {
  w : W.t;
  runtime : int;
  console : int;
  obj : int;
  memo : (string, int) Hashtbl.t;
  env : env;
  mutable inits : int list;             (* reversed *)
}

let start (name : string) : assembly =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console = W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  let memo = Hashtbl.create 64 in
  Hashtbl.replace memo "type Object" obj;
  Il_types.reset ();
  Hashtbl.reset levels;
  closures := 0;
  { w; runtime; console; obj; memo; env = { by_var = Hashtbl.create 16; by_sym = Hashtbl.create 16; fields = Hashtbl.create 16;
          externals = Hashtbl.create 16 };
    inits = [] }

(* a unit: a static class (abstract, sealed; not beforefieldinit: its
 * initializer runs before its first use, no sooner); its toplevel its
 * type initializer (.cctor), which the runtime runs before the class is
 * first used, by C# too (F#'s way: a C# program using a unit finds its
 * values made); an empty init, which <Program>.Main calls in link order
 * so that the units' toplevels run in OCaml's order *)
let unit_ (a : assembly) (name : string) (items : Scope.item list) : unit =
  let w = a.w and env = a.env in
  (* (a unit's own types: their paths unqualified, or of its name;
   * Resolve's table has the interfaces' it read too, A.t in B) *)
  List.iter
    (fun (d : Scope.tdecl) ->
      let p = d.tpath and pre = name ^ "." in
      if not (String.contains p '.') then Hashtbl.replace implementations (pre ^ p) d
      else if String.length p > String.length pre && String.sub p 0 (String.length pre) = pre then Hashtbl.replace implementations p d)
    (Resolve.own_types_all ());
  let cls = W.type_def w "" name 0x00000181 a.obj in
  Hashtbl.replace a.memo ("unit " ^ name) cls;
  let c = { w; runtime = a.runtime; console = a.console; cls; uname = name; memo = a.memo; tvars = [] } in
  let cctor = W.method_def w cls ".cctor" 0x1891 (static [] S.Void) in
  let init = W.method_def w cls "init" 0x0096 (static [] S.Void) in
  W.set_body w init [] [| Il.Ret |] [];
  a.inits <- init :: a.inits;
  let k = new_code () in
  let item (it : Scope.item) : unit =
    match it with
    | Ieval e -> drop c env k e
    | Ivalue (_, bs, globals) ->
        (* (a function's alias, let sort = stable_sort: the same method or
         * primitive, so polymorphic as it, where a Func would be one
         * instance, F#'s way) *)
        let alias ((p, d) : Scope.pattern * Scope.expr) : bool =
          match p, d.e with
          | (Pvar v | Pconstraint (Pvar v, _)), Evar target when is_function_type (type_of d) -> (
              match global_of globals v, target with
              | Some g, Global t when Hashtbl.mem env.by_sym t.gsym ->
                  Hashtbl.replace env.by_sym g.gsym (Hashtbl.find env.by_sym t.gsym); true
              | Some g, Global t when Hashtbl.mem env.externals t.gsym ->
                  Hashtbl.replace env.externals g.gsym (Hashtbl.find env.externals t.gsym); true
              | Some g, Prim (p, n, ty) -> Hashtbl.replace env.externals g.gsym (p, n, ty); true
              | _ -> false)
          | _ -> false in
        let bs = List.filter (fun (b : Scope.pattern * Scope.expr) -> not (alias b)) bs in
        let fns =
          List.filter_map
            (fun ((p, d) : Scope.pattern * Scope.expr) ->
              match p with
              | (Pvar v | Pconstraint (Pvar v, _)) when is_function d -> Some (declare c env globals v d)
              | _ -> None)
            bs in
        List.iter (define c env) fns;
        List.iter
          (fun ((p, d) : Scope.pattern * Scope.expr) ->
            match p with
            | (Pvar v | Pconstraint (Pvar v, _)) when not (is_function d) -> (
                let ty = cts_of c d in
                expr c env k d;
                if ty <> S.Void then
                  match global_of globals v with
                  | Some g ->
                      let f = W.field_def w cls v.vname 0x0016 ty in
                      Hashtbl.replace env.fields g.gsym (f, ty);
                      emit k (Il.Stsfld f)
                  | None -> emit k Il.Pop)
            | Pvar _ | Pconstraint (Pvar _, _) -> ()
            | Pany | Pcons ({ cname = "()"; _ }, []) -> drop c env k d
            (* (a pattern, let (a, b) = ...: matched as a local let's, its
             * variables in locals, then each its unit's field) *)
            | p ->
                let v = local k (cts_of c d) and fail = label k and ok = label k in
                expr c env k d;
                emit k (Il.Stloc v);
                Il_patterns.pattern c k (fun () -> emit k (Il.Ldloc v)) (type_of d) p fail;
                emit k (Il.Br ok);
                place k fail;
                match_failure c k;
                place k ok;
                List.iter
                  (fun (x : Scope.var) ->
                    match Hashtbl.find_opt k.slots x.vid, global_of globals x with
                    | Some slot, Some g ->
                        let ty = match Il_types.var_type x.vid with Some t -> cts c d.loc t | None -> S.Object in
                        if ty <> S.Void then begin
                          let f = W.field_def w cls x.vname 0x0016 ty in
                          Hashtbl.replace env.fields g.gsym (f, ty);
                          emit k (Il.Ldloc slot);
                          emit k (Il.Stsfld f)
                        end
                    | _ -> ())
                  (pattern_vars p))
          bs
    (* (an exception's class is made when it is first raised or matched) *)
    | Iexception _ -> ()
    (* (an external's declaration: its uses are its primitive's IL, its
     * .NET member's call, or the runtime unit's function of its name) *)
    | Iexternal (g, p, n, ty) -> Hashtbl.replace env.externals g.gsym (p, n, ty) in
  List.iter item items;
  emit k Il.Ret;
  finish c k cctor

(* an overlay's functions in place of its unit's (Printf_dotnet's over
 * Printf's: lib_core/dotnet/, where .NET wants another way, formats
 * as values): the units after it call them *)
let moved (pre : string) (onto : string) (tbl : (string, 'v) Hashtbl.t) : (string * 'v) list =
  Hashtbl.fold
    (fun (sym : string) (v : 'v) (acc : (string * 'v) list) ->
      if String.length sym > String.length pre && String.sub sym 0 (String.length pre) = pre then
        (onto ^ "." ^ String.sub sym (String.length pre) (String.length sym - String.length pre), v) :: acc
      else acc)
    tbl []

let overlay (a : assembly) (from : string) (onto : string) : unit =
  let pre = from ^ "." in
  List.iter (fun ((s, v) : string * fn) -> Hashtbl.replace a.env.by_sym s v) (moved pre onto a.env.by_sym);
  List.iter (fun ((s, v) : string * (int * S.t)) -> Hashtbl.replace a.env.fields s v) (moved pre onto a.env.fields);
  List.iter (fun ((s, v) : string * (string * int * Scope.ty)) -> Hashtbl.replace a.env.externals s v) (moved pre onto a.env.externals)

(* the entry point, <Program>.Main: each unit's init, in order; with
 * Pervasives compiled, its do_at_exit after them, in a finally (the
 * channels flushed, even when an exception ends the program, as
 * OCaml's runtime does at its exit) *)
let finish (a : assembly) : string =
  let cls = W.type_def a.w "" "<Program>" 0x00100181 a.obj in
  let main = W.method_def a.w cls "Main" 0x0096 (static [] S.Void) in
  let calls = List.rev_map (fun (i : int) -> Il.Call i) a.inits in
  (match Hashtbl.find_opt a.env.by_sym "Pervasives.do_at_exit" with
   | None -> W.set_body a.w main [] (Array.of_list (calls @ [ Il.Ret ])) []
   | Some f ->
       let n = List.length calls in
       let clause : W.clause = { kind = 2; try_start = 0; try_end = n + 1; handler_start = n + 1; handler_end = n + 3; catch = 0 } in
       W.set_body a.w main [] (Array.of_list (calls @ [ Il.Leave (n + 3); Il.Call f.tok; Il.Endfinally; Il.Ret ])) [ clause ]);
  W.set_entry_point a.w main;
  W.write a.w
