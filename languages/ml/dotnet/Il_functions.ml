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
  gvars : string list;                  (* its type's variables: its generic parameters *)
  lifted : (Scope.var * S.t) list;      (* a local function lifted: what it captured *)
}

(* the unit's closures' classes, numbered *)
let closures = ref 0

(* by variable (inside its definition, a let rec's) and by symbol
 * (after it, from the toplevel's later items); a value's field by
 * symbol *)
type env = {
  by_var : (int, fn) Hashtbl.t;
  by_sym : (string, fn) Hashtbl.t;
  fields : (string, int * S.t) Hashtbl.t;
  (* a unit's externals by symbol: another's use of one its .mli says
   * val of (Uchar.unsafe_of_int), compiled as the primitive *)
  externals : (string, string * int * Scope.ty) Hashtbl.t;
}

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
      let arg = match unabbrev (type_of e) with Tarrow (a, _) -> a | _ -> refuse e.loc "a function" "1a" in
      (match cases with
       | [ (p, None, body) ] when simple p <> None ->
           let v = match simple p with Some v -> v | None -> None in
           let rest, cs, body = params body in
           ((v, arg) :: rest, cs, body)
       | (_, _, body) :: _ -> ([ (None, arg) ], Some cases, body)
       | [] -> refuse e.loc "a function of no case" "1a")
  | _ -> ([], None, e)

(* a function whose method returns nothing: its body a raise (not its
 * first case's only: List.assoc's [] -> raise Not_found) *)
let raises_always (f : fn) : bool = f.cases = None && is_raise f.body

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

(* a type's variables, each once, in order *)
let tvars_of (t : Scope.ty) : string list =
  let acc = ref [] in
  let rec go (t : Scope.ty) : unit =
    match t with
    | Tvar n -> if not (List.mem n !acc) then acc := n :: !acc
    | Tarrow (a, b) -> go a; go b
    | Ttuple ts | Tconstr (_, ts) -> List.iter go ts in
  go t;
  List.rev !acc

(* the generic type's variables, as the instance gives them (the same
 * shape, walked together) *)
let instantiation (gen : Scope.ty) (inst : Scope.ty) : (string * Scope.ty) list =
  let acc = ref [] in
  let rec go (g : Scope.ty) (i : Scope.ty) : unit =
    match g, i with
    | Tvar n, t -> if not (List.mem_assoc n !acc) then acc := (n, t) :: !acc
    | Tarrow (a, b), Tarrow (a', b') -> go a a'; go b b'
    | Ttuple xs, Ttuple ys when List.length xs = List.length ys -> List.iter2 go xs ys
    | Tconstr (_, xs), Tconstr (_, ys) when List.length xs = List.length ys -> List.iter2 go xs ys
    | _ -> () in
  go gen inst;
  !acc

(* the expressions naming a variable, in an expression *)
let uses (vid : int) (e : Scope.expr) : Scope.expr list =
  let acc = ref [] in
  let rec go (e : Scope.expr) : unit =
    match e.e with
    | Evar (Local v) -> if v.vid = vid then acc := e :: !acc
    | Evar _ | Econst _ -> ()
    | Elet (_, bs, body) -> List.iter (fun ((_, d) : Scope.pattern * Scope.expr) -> go d) bs; go body
    | Efunction cases -> List.iter (fun ((_, g, b) : Scope.case) -> (match g with Some g -> go g | None -> ()); go b) cases
    | Ematch (x, cases) | Etry (x, cases) ->
        go x;
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
  !acc

(* every use of a variable a call of it with n arguments, none inside
 * a lambda: a local function that can be a method (Il_exprs.lift) *)
let applied_only (vid : int) (n : int) (e : Scope.expr) : bool =
  let ok = ref true in
  let rec go (e : Scope.expr) : unit =
    match e.e with
    | Evar (Local v) -> if v.vid = vid then ok := false
    | Eapply ({ e = Evar (Local v); _ }, args) when v.vid = vid ->
        if List.length args <> n then ok := false;
        List.iter go args
    | Efunction _ -> if uses vid e <> [] then ok := false
    | Evar _ | Econst _ -> ()
    | Elet (_, bs, body) -> List.iter (fun ((_, d) : Scope.pattern * Scope.expr) -> go d) bs; go body
    | Ematch (x, cases) | Etry (x, cases) ->
        go x;
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
  !ok

(* a function's type after its first i arguments: the arrows of the
 * rest, to its result *)
let rest (f : fn) (i : int) : Scope.ty =
  List.fold_right (fun (a : Scope.ty) (b : Scope.ty) -> Scope.Tarrow (a, b)) (List.filteri (fun (j : int) (_ : Scope.ty) -> j >= i) f.ptys) f.rty

(* the class of a function of the unit given i arguments: its fields
 * those (unit's an object, null), its constructor, its Invoke *)
(* the levels made, by function and number of arguments *)
let levels : (string, tclass * int * S.meth) Hashtbl.t = Hashtbl.create 16

let rec level (c : c) (f : fn) (i : int) : tclass * int * S.meth =
  let key = Printf.sprintf "level %d %d" f.tok i in
  match Hashtbl.find_opt levels key with
  | Some x -> x
  | None ->
      (* (a polymorphic function's: generic in its type variables, its
       * own !0... there, the method called at them) *)
      let saved = c.tvars in
      let me = List.mapi (fun (j : int) (_ : string) -> S.Var j) f.gvars in
      c.tvars <- List.combine f.gvars me;
      let n = List.length f.ptys in
      let given = List.filteri (fun (j : int) (_ : Scope.ty) -> j < i) f.ptys in
      let fields = List.mapi (fun (j : int) (t : Scope.ty) -> (Printf.sprintf "arg%d" (j + 1), arg_type c 0 t)) given in
      let t = helper_class c (Printf.sprintf "%s_%d" f.fname i) (List.length f.gvars) fields in
      let p = List.nth f.ptys i in
      let sg = instance [ arg_type c 0 p ] (arg_type c 0 (rest f (i + 1))) in
      let inv = W.method_def c.w t.tok "Invoke" 0x0086 sg in
      Hashtbl.replace levels key (t, inv, sg);
      let k = new_code () in
      if i + 1 = n then begin
        List.iteri
          (fun (j : int) (_ : Scope.ty) ->
            if cts c 0 (List.nth f.ptys j) <> S.Void then (emit k (Il.Ldarg 0); emit k (Il.Ldfld (field_tok c t me j))))
          given;
        if cts c 0 p <> S.Void then emit k (Il.Ldarg 1);
        emit k (Il.Call (if f.gvars = [] then f.tok else W.method_spec c.w f.tok me));
        if cts c 0 f.rty = S.Void then emit k Il.Ldnull
        (* (a function that always raises, its method void: a value of
         * its result's type, T's default, never reached) *)
        else if raises_always f then begin
          let t' = arg_type c 0 f.rty in
          let l = local k t' in
          emit k (Il.Ldloca l);
          emit k (Il.Initobj (type_token c t'));
          emit k (Il.Ldloc l)
        end
      end
      else begin
        List.iteri (fun (j : int) (_ : Scope.ty) -> emit k (Il.Ldarg 0); emit k (Il.Ldfld (field_tok c t me j))) given;
        emit k (Il.Ldarg 1);
        let t', inv', sg' = level c f (i + 1) in
        emit k (Il.Newobj (ctor_tok c t' me));
        emit k (Il.Ldftn (method_tok c t' me "Invoke" inv' sg'));
        emit k (Il.Newobj (func_ctor c (cts c 0 (rest f (i + 1)))))
      end;
      emit k Il.Ret;
      finish c k inv;
      c.tvars <- saved;
      (t, inv, sg)

let is_function (e : Scope.expr) : bool = match e.e with Efunction _ -> true | Econstraint ({ e = Efunction _; _ }, _) -> true | _ -> false

(* a toplevel variable's global *)
let global_of (globals : (Scope.var * Scope.global) list) (v : Scope.var) : Scope.global option =
  Option.map snd (List.find_opt (fun ((v', _) : Scope.var * Scope.global) -> v'.vid = v.vid) globals)

(* a function's argument's type, from its first case's pattern: its
 * variable's, its constructor's, its record's *)
let rec pattern_type (p : Scope.pattern) : Scope.ty =
  match p with
  | Pvar v | Palias (_, v) -> (match Il_types.var_type v.vid with Some t -> t | None -> Resolve.unit_t)
  | Pcons (k, _) -> let _, _, res = k.ctype in res
  | Precord ((l, _) :: _) -> let _, _, r = l.ltype in r
  | Pconstraint (p, _) | Por (p, _) -> pattern_type p
  | Pconst (Int _) -> Resolve.int_t
  | Pconst (String _) -> Resolve.string_t
  | Pconst (Char _) | Prange _ -> Resolve.char_t
  | _ -> Resolve.unit_t

