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
  let ret = if is_raise body then S.Void else cts c body.loc rty in
  let sg = { (static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret) with generic = List.length gvars } in
  c.tvars <- [];
  let tok = W.method_def c.w c.cls v.vname 0x0096 sg in
  List.iteri (fun (i : int) (_ : string) -> W.generic_param c.w tok i (Printf.sprintf "T%d" i)) gvars;
  let f = { tok; fname = v.vname; params; ptys = List.map snd ps; rty; cases; body; gvars } in
  Hashtbl.replace env.by_var v.vid f;
  (match global_of globals v with Some g -> Hashtbl.replace env.by_sym g.gsym f | None -> ());
  f

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
  { w; runtime; console; obj; memo; env = { by_var = Hashtbl.create 16; by_sym = Hashtbl.create 16; fields = Hashtbl.create 16 };
    inits = [] }

(* a unit: a static class (abstract, sealed; not beforefieldinit: its
 * initializer runs before its first use, no sooner); its toplevel its
 * type initializer (.cctor), which the runtime runs before the class is
 * first used, by C# too (F#'s way: a C# program using a unit finds its
 * values made); an empty init, which <Program>.Main calls in link order
 * so that the units' toplevels run in OCaml's order *)
let unit_ (a : assembly) (name : string) (items : Scope.item list) : unit =
  let w = a.w and env = a.env in
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
            | _ -> refuse d.loc "a toplevel let of a pattern" "1d")
          bs
    (* (an exception's class is made when it is first raised or matched) *)
    | Iexception _ -> ()
    (* (an external's declaration: its uses are its primitive's IL, or
     * its .NET member's call; a C function's, not yet) *)
    | Iexternal (g, p, _, _) ->
        if not (String.length p > 0 && p.[0] = '%') && not (Il_externals.is_dotnet p) then
          refuse 0 ("the external " ^ g.gname ^ " (" ^ p ^ "), a C function of the native runtime") "3b" in
  List.iter item items;
  emit k Il.Ret;
  finish c k cctor

(* the entry point, <Program>.Main: each unit's init, in order *)
let finish (a : assembly) : string =
  let cls = W.type_def a.w "" "<Program>" 0x00100181 a.obj in
  let main = W.method_def a.w cls "Main" 0x0096 (static [] S.Void) in
  W.set_body a.w main [] (Array.of_list (List.rev_map (fun (i : int) -> Il.Call i) a.inits @ [ Il.Ret ])) [];
  W.set_entry_point a.w main;
  W.write a.w
