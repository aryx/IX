(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_functions.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types

(*****************************************************************************)
(* The unit's functions and values *)
(*****************************************************************************)

(* a function of the unit: its method, its arguments' variables (None:
 * unit's, or _), and when its last argument is a pattern or several
 * (function A -> ... | B -> ...), the cases on it; its body otherwise *)
type fn = {
  tok : int;
  fname : string;
  params : (Scope.var option * S.t) list;
  ptys : Scope.ty list;                 (* the arguments' types, ML's *)
  rty : Scope.ty;                       (* the result's, after them all *)
  cases : Scope.case list option;
  body : Scope.expr;
}

(* the unit's closures' classes, numbered *)
let closures = ref 0

(* by variable (inside its definition, a let rec's) and by symbol
 * (after it, from the toplevel's later items); a value's field by
 * symbol *)
type env = { by_var : (int, fn) Hashtbl.t; by_sym : (string, fn) Hashtbl.t; fields : (string, int * S.t) Hashtbl.t }

let rec simple (p : Scope.pattern) : Scope.var option option =
  match p with
  | Pvar v -> Some (Some v)
  | Pany -> Some None
  | Pcons (k, []) when k.cname = "()" -> Some None
  | Pconstraint (p, _) -> simple p
  | _ -> None

(* a function's arguments, as its Efunction's nest; the last's cases
 * if it is matched *)
let rec params (e : Scope.expr) : (Scope.var option * Scope.ty) list * Scope.case list option * Scope.expr =
  match e.e with
  | Efunction cases ->
      let arg = match type_of e with Tarrow (a, _) -> a | _ -> refuse e.loc "a function" "1a" in
      (match cases with
       | [ (p, None, body) ] when simple p <> None ->
           let v = match simple p with Some v -> v | None -> None in
           let rest, cs, body = params body in
           ((v, arg) :: rest, cs, body)
       | (_, _, body) :: _ -> ([ (None, arg) ], Some cases, body)
       | [] -> refuse e.loc "a function of no case" "1a")
  | _ -> ([], None, e)

(*****************************************************************************)
(* Closures *)
(*****************************************************************************)

(* the variables an expression names, each once: those a closure made
 * of it captures are among them (the others are its own) *)
let named (e : Scope.expr) : int list =
  let seen : (int, unit) Hashtbl.t = Hashtbl.create 16 and order = ref [] in
  let rec go (e : Scope.expr) : unit =
    match e.e with
    | Evar (Local v) -> if not (Hashtbl.mem seen v.vid) then (Hashtbl.replace seen v.vid (); order := v.vid :: !order)
    | Evar _ | Econst _ -> ()
    | Elet (_, bs, body) -> List.iter (fun ((_, d) : Scope.pattern * Scope.expr) -> go d) bs; go body
    | Efunction cases | Ematch (_, cases) | Etry (_, cases) ->
        (match e.e with Ematch (x, _) | Etry (x, _) -> go x | _ -> ());
        List.iter (fun ((_, g, b) : Scope.case) -> (match g with Some g -> go g | None -> ()); go b) cases
    | Eapply (f, args) -> go f; List.iter go args
    | Etuple es | Econs (_, es) | Earray es -> List.iter go es
    | Erecord (_, fs) -> List.iter (fun ((_, x) : Scope.label * Scope.expr) -> go x) fs
    | Ewith (r, _, fs) -> go r; List.iter (fun ((_, x) : Scope.label * Scope.expr) -> go x) fs
    | Efield (r, _) -> go r
    | Esetfield (r, _, x) -> go r; go x
    | Eif (a, b, c) -> go a; go b; (match c with Some c -> go c | None -> ())
    | Eseq (a, b) | Ewhile (a, b) -> go a; go b
    | Efor (_, a, b, _, body) -> go a; go b; go body
    | Eassert x | Econstraint (x, _) -> go x in
  go e;
  List.rev !order

(* a function's type after its first i arguments: the arrows of the
 * rest, to its result *)
let rest (f : fn) (i : int) : Scope.ty =
  List.fold_right (fun (a : Scope.ty) (b : Scope.ty) -> Scope.Tarrow (a, b)) (List.filteri (fun (j : int) (_ : Scope.ty) -> j >= i) f.ptys) f.rty

(* the class of a function of the unit given i arguments: its fields
 * those (unit's an object, null), its constructor, its Invoke *)
let rec level (c : c) (f : fn) (i : int) : int * int * int =
  let key = Printf.sprintf "level %d %d" f.tok i in
  match Hashtbl.find_opt c.memo key with
  | Some cls -> (cls, Hashtbl.find c.memo (key ^ " ctor"), Hashtbl.find c.memo (key ^ " invoke"))
  | None ->
      let n = List.length f.ptys in
      let given = List.filteri (fun (j : int) (_ : Scope.ty) -> j < i) f.ptys in
      let fields = List.mapi (fun (j : int) (t : Scope.ty) -> (Printf.sprintf "arg%d" (j + 1), arg_type c 0 t)) given in
      let cls, ctor, toks =
        new_class c "" (Printf.sprintf "%s_%d" f.fname i) 0x00100102 (sys c "Object") (object_ctor c) [] fields in
      W.nest c.w cls c.cls;
      let p = List.nth f.ptys i in
      let inv = W.method_def c.w cls "Invoke" 0x0086 (instance [ arg_type c 0 p ] (arg_type c 0 (rest f (i + 1)))) in
      Hashtbl.replace c.memo key cls;
      Hashtbl.replace c.memo (key ^ " ctor") ctor;
      Hashtbl.replace c.memo (key ^ " invoke") inv;
      let k = new_code () in
      if i + 1 = n then begin
        List.iteri
          (fun (j : int) (fld : int) ->
            if cts c 0 (List.nth f.ptys j) <> S.Void then (emit k (Il.Ldarg 0); emit k (Il.Ldfld fld)))
          toks;
        if cts c 0 p <> S.Void then emit k (Il.Ldarg 1);
        emit k (Il.Call f.tok);
        if cts c 0 f.rty = S.Void then emit k Il.Ldnull
      end
      else begin
        List.iter (fun (fld : int) -> emit k (Il.Ldarg 0); emit k (Il.Ldfld fld)) toks;
        emit k (Il.Ldarg 1);
        let _, ctor', inv' = level c f (i + 1) in
        emit k (Il.Newobj ctor');
        emit k (Il.Ldftn inv');
        emit k (Il.Newobj (func_ctor c (cts c 0 (rest f (i + 1)))))
      end;
      emit k Il.Ret;
      finish c k inv;
      (cls, ctor, inv)

let is_function (e : Scope.expr) : bool = match e.e with Efunction _ -> true | Econstraint ({ e = Efunction _; _ }, _) -> true | _ -> false

(* a toplevel variable's global *)
let global_of (globals : (Scope.var * Scope.global) list) (v : Scope.var) : Scope.global option =
  Option.map snd (List.find_opt (fun ((v', _) : Scope.var * Scope.global) -> v'.vid = v.vid) globals)

(* a function's argument's type, from its first case's pattern: its
 * variable's, its constructor's, its record's *)
let rec pattern_type (p : Scope.pattern) : Scope.ty =
  match p with
  | Pvar v | Palias (_, v) -> (match Typing.var_type v.vid with Some t -> t | None -> Resolve.unit_t)
  | Pcons (k, _) -> let _, _, res = k.ctype in res
  | Precord ((l, _) :: _) -> let _, _, r = l.ltype in r
  | Pconstraint (p, _) | Por (p, _) -> pattern_type p
  | Pconst (Int _) -> Resolve.int_t
  | Pconst (String _) -> Resolve.string_t
  | Pconst (Char _) | Prange _ -> Resolve.char_t
  | _ -> Resolve.unit_t

