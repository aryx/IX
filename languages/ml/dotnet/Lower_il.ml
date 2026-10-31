(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower_il.mli *)

module S = Signature
module W = Writer

exception Refused of int * string

let refuse (loc : int) (what : string) (stage : string) : 'a =
  raise (Refused (loc, Printf.sprintf "%s: not compiled to .NET yet (plan_dotnet_languages.md, stage %s)" what stage))

(*****************************************************************************)
(* The assembly's classes and members, each made when first needed *)
(*****************************************************************************)

type c = {
  w : W.t;
  runtime : int;                        (* the assembly System.Runtime *)
  console : int;                        (* System.Console, in its own assembly *)
  cls : int;                            (* the unit's class *)
  memo : (string, int) Hashtbl.t;       (* what is made, by a name of ours *)
}

let memo (c : c) (key : string) (make : unit -> int) : int =
  match Hashtbl.find_opt c.memo key with
  | Some x -> x
  | None ->
      let x = make () in
      Hashtbl.replace c.memo key x;
      x

let static (ps : S.t list) (r : S.t) : S.meth = { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps }
let instance (ps : S.t list) (r : S.t) : S.meth = { (static ps r) with has_this = true }

let sys (c : c) (name : string) : int =
  memo c ("type " ^ name) (fun () -> if name = "Console" then c.console else W.type_ref c.w c.runtime "System" name)

(* a member of .NET's library: its class, name and signature *)
let lib (c : c) (cls : string) (name : string) (m : S.meth) : int =
  memo c (cls ^ "::" ^ name ^ S.encode_method m) (fun () -> W.member_ref c.w (sys c cls) name m)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let decl (t : Scope.ty) : Scope.tdecl = match t with Tconstr (d, _) -> d | _ -> assert false
let int_d = decl Resolve.int_t and bool_d = decl Resolve.bool_t and unit_d = decl Resolve.unit_t
let char_d = decl Resolve.char_t and float_d = decl Resolve.float_t and string_d = decl Resolve.string_t

(* an ML type's .NET type; unit's Void (no value) *)
let rec cts (loc : int) (t : Scope.ty) : S.t =
  match t with
  | Tconstr (d, []) when d == int_d -> S.I8
  | Tconstr (d, []) when d == bool_d -> S.Bool
  | Tconstr (d, []) when d == char_d -> S.I4
  | Tconstr (d, []) when d == float_d -> S.R8
  | Tconstr (d, []) when d == string_d -> S.String
  | Tconstr (d, []) when d == unit_d -> S.Void
  | Tconstr ({ tabbrev = Some t; _ }, []) -> cts loc t
  | Tvar _ -> refuse loc "a polymorphic value" "1d"
  | Tarrow _ -> refuse loc "a function as a value" "1c"
  | Ttuple _ -> refuse loc "a tuple" "1d"
  | Tconstr (d, _) -> refuse loc ("a value of type " ^ d.tpath) "1b"

let type_of (e : Scope.expr) : Scope.ty =
  match Typing.expr_type e.span with Some t -> t | None -> refuse e.loc "an expression whose type was not kept" "1a"

let cts_of (e : Scope.expr) : S.t = cts e.loc (type_of e)

(*****************************************************************************)
(* A method's code: the instructions, their labels, the locals *)
(*****************************************************************************)

type code = {
  mutable ops : Il.op list;             (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;        (* a label to its instruction *)
  mutable nlabels : int;
  mutable locals : S.t list;            (* reversed *)
  mutable nlocals : int;
  args : (int, int) Hashtbl.t;          (* a variable's argument *)
  slots : (int, int) Hashtbl.t;         (* a variable's local *)
}

let new_code () : code =
  { ops = []; n = 0; labels = Hashtbl.create 8; nlabels = 0; locals = []; nlocals = 0; args = Hashtbl.create 4;
    slots = Hashtbl.create 8 }

let emit (k : code) (op : Il.op) : unit =
  k.ops <- op :: k.ops;
  k.n <- k.n + 1

let label (k : code) : int =
  k.nlabels <- k.nlabels + 1;
  k.nlabels

let place (k : code) (l : int) : unit = Hashtbl.replace k.labels l k.n

let local (k : code) (ty : S.t) : int =
  k.locals <- ty :: k.locals;
  k.nlocals <- k.nlocals + 1;
  k.nlocals - 1

(* the labels made instructions' numbers, and the body set *)
let finish (c : c) (k : code) (meth : int) : unit =
  let at (l : int) : int = Hashtbl.find k.labels l in
  let ops =
    Array.of_list
      (List.rev_map
         (fun (op : Il.op) ->
           match op with
           | Il.Br l -> Il.Br (at l)
           | Il.Brfalse l -> Il.Brfalse (at l)
           | Il.Brtrue l -> Il.Brtrue (at l)
           | op -> op)
         k.ops) in
  W.set_body c.w meth (List.rev k.locals) ops []

(*****************************************************************************)
(* The unit's functions and values *)
(*****************************************************************************)

(* a function of the unit: its method, and its arguments' variables
 * (None: unit's, or _) *)
type fn = { tok : int; params : (Scope.var option * S.t) list; body : Scope.expr }

(* by variable (inside its definition, a let rec's) and by symbol
 * (after it, from the toplevel's later items); a value's field by
 * symbol *)
type env = { by_var : (int, fn) Hashtbl.t; by_sym : (string, fn) Hashtbl.t; fields : (string, int * S.t) Hashtbl.t }

(* a function's arguments, as its Efunction's nest of one case each *)
let rec params (e : Scope.expr) : (Scope.var option * Scope.ty) list * Scope.expr =
  match e.e with
  | Efunction [ (p, None, body) ] ->
      let arg = match type_of e with Tarrow (a, _) -> a | _ -> refuse e.loc "a function" "1a" in
      let rec var (p : Scope.pattern) : Scope.var option =
        match p with
        | Pvar v -> Some v
        | Pany -> None
        | Pcons (k, []) when k.cname = "()" -> None
        | Pconstraint (p, _) -> var p
        | _ -> refuse e.loc "a function's argument as a pattern" "1b" in
      let v = var p in
      let rest, body = params body in
      ((v, arg) :: rest, body)
  | Efunction _ -> refuse e.loc "a function of several cases" "1b"
  | _ -> ([], e)

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

(* the calls of Pervasives this stage has, as .NET's library's *)
let builtin (c : c) (sym : string) : (Il.op list) option =
  let write (t : S.t) = Il.Call (lib c "Console" "Write" (static [ t ] S.Void)) in
  match sym with
  | "Pervasives.print_int" -> Some [ write S.I8 ]
  | "Pervasives.print_string" -> Some [ write S.String ]
  | "Pervasives.print_char" -> Some [ Il.Conv (Il.K_u2, false, false); write S.Char ]
  | "Pervasives.print_endline" -> Some [ Il.Call (lib c "Console" "WriteLine" (static [ S.String ] S.Void)) ]
  | "Pervasives.print_newline" -> Some [ Il.Call (lib c "Console" "WriteLine" (static [] S.Void)) ]
  | "Pervasives.^" -> Some [ Il.Call (lib c "String" "Concat" (static [ S.String; S.String ] S.String)) ]
  (* (an int64 boxed, its ToString: Int64's own, by the object's class) *)
  | "Pervasives.string_of_int" -> Some [ Il.Box (sys c "Int64"); Il.Callvirt (lib c "Object" "ToString" (instance [] S.String)) ]
  | _ -> None

let rec expr (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  match e.e with
  | Econst (Int n) -> emit k (Il.Ldc_i8 (Int64.of_int n))
  | Econst (Char ch) -> emit k (Il.Ldc_i4 (Int32.of_int (Char.code ch)))
  | Econst (String s) -> emit k (Il.Ldstr (W.user_string c.w s))
  | Econst (Float f) -> emit k (Il.Ldc_r (float_of_string f))
  | Econst _ -> refuse e.loc "an int32 or int64 constant" "1d"
  | Econs (k', []) when k'.cname = "()" -> ()
  | Econs (k', []) when k'.cname = "true" -> emit k (Il.Ldc_i4 1l)
  | Econs (k', []) when k'.cname = "false" -> emit k (Il.Ldc_i4 0l)
  | Evar (Local v) -> (
      match Hashtbl.find_opt k.args v.vid, Hashtbl.find_opt k.slots v.vid with
      | Some i, _ -> emit k (Il.Ldarg i)
      | None, Some i -> emit k (Il.Ldloc i)
      | None, None -> if cts_of e = S.Void then () else refuse e.loc (v.vname ^ ", a function as a value") "1c")
  | Evar (Global g) -> (
      match Hashtbl.find_opt env.fields g.gsym, g.gsym with
      | Some (f, ty), _ -> if ty <> S.Void then emit k (Il.Ldsfld f)
      | None, "Pervasives.nan" -> emit k (Il.Ldc_r nan)
      | None, "Pervasives.infinity" -> emit k (Il.Ldc_r infinity)
      | None, "Pervasives.neg_infinity" -> emit k (Il.Ldc_r neg_infinity)
      | None, _ -> (
          match type_of e with
          | Tarrow _ -> refuse e.loc (g.gsym ^ ", a function as a value") "1c"
          | _ -> refuse e.loc (g.gsym ^ ", a value of another unit") "1e"))
  | Evar (Prim (p, _, _)) -> refuse e.loc (p ^ ", a primitive as a value") "1c"
  | Eapply ({ e = Evar (Prim (p, _, _)); _ }, args) -> prim c env k e p args
  | Eapply ({ e = Evar (Global g); _ }, args) when Hashtbl.mem env.by_sym g.gsym -> call c env k e (Hashtbl.find env.by_sym g.gsym) args
  | Eapply ({ e = Evar (Local v); _ }, args) when Hashtbl.mem env.by_var v.vid -> call c env k e (Hashtbl.find env.by_var v.vid) args
  | Eapply ({ e = Evar (Global g); _ }, args) -> (
      match builtin c g.gsym with
      | Some ops ->
          List.iter (expr c env k) args;
          List.iter (emit k) ops
      | None when String.length g.gsym > 11 && String.sub g.gsym 0 11 = "Pervasives." -> refuse e.loc (g.gsym ^ ", of the library") "3"
      | None -> refuse e.loc (g.gsym ^ ", of another unit") "1e")
  | Eapply _ -> refuse e.loc "a call of a function value" "1c"
  | Eseq (a, b) ->
      drop c env k a;
      expr c env k b
  | Eif (cond, a, b) ->
      let otherwise = label k and over = label k in
      expr c env k cond;
      emit k (Il.Brfalse otherwise);
      expr c env k a;
      emit k (Il.Br over);
      place k otherwise;
      (match b with Some b -> expr c env k b | None -> ());
      place k over
  | Ewhile (cond, body) ->
      let top = label k and over = label k in
      place k top;
      expr c env k cond;
      emit k (Il.Brfalse over);
      drop c env k body;
      emit k (Il.Br top);
      place k over
  | Efor (v, a, b, dir, body) ->
      let i = local k S.I8 and last = local k S.I8 in
      Hashtbl.replace k.slots v.vid i;
      expr c env k a;
      emit k (Il.Stloc i);
      expr c env k b;
      emit k (Il.Stloc last);
      let top = label k and over = label k in
      place k top;
      emit k (Il.Ldloc i);
      emit k (Il.Ldloc last);
      (* (past the last: out) *)
      emit k (match dir with Upto -> Il.Cgt false | Downto -> Il.Clt false);
      emit k (Il.Brtrue over);
      drop c env k body;
      emit k (Il.Ldloc i);
      emit k (Il.Ldc_i8 1L);
      emit k (Il.Binop (match dir with Upto -> Il.Add | Downto -> Il.Sub));
      emit k (Il.Stloc i);
      emit k (Il.Br top);
      place k over
  | Elet (false, [ (p, d) ], body) ->
      let rec bind (p : Scope.pattern) : unit =
        match p with
        | Pvar v when (match d.e with Efunction _ -> true | _ -> false) -> refuse d.loc (v.vname ^ ", a local function") "1c"
        | Pvar v ->
            let ty = cts_of d in
            expr c env k d;
            if ty <> S.Void then begin
              let i = local k ty in
              Hashtbl.replace k.slots v.vid i;
              emit k (Il.Stloc i)
            end
        | Pany -> drop c env k d
        | Pcons (k', []) when k'.cname = "()" -> drop c env k d
        | Pconstraint (p, _) -> bind p
        | _ -> refuse d.loc "a let of a pattern" "1b" in
      bind p;
      expr c env k body
  | Elet _ -> refuse e.loc "a let rec or let ... and" "1c"
  | Econstraint (e, _) -> expr c env k e
  | Efunction _ -> refuse e.loc "a function as a value" "1c"
  | Ematch _ -> refuse e.loc "a match" "1b"
  | Etry _ -> refuse e.loc "a try" "1b"
  | Etuple _ -> refuse e.loc "a tuple" "1d"
  | Econs (k', _) -> refuse e.loc ("the constructor " ^ k'.cname) "1b"
  | Erecord _ | Ewith _ | Efield _ | Esetfield _ -> refuse e.loc "a record" "1b"
  | Earray _ -> refuse e.loc "an array" "1d"
  | Eassert _ -> refuse e.loc "an assert" "1b"

(* an expression for its effect: its value, if any, popped *)
and drop (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  expr c env k e;
  if cts_of e <> S.Void then emit k Il.Pop

(* a call of a function of the unit, all its arguments given *)
and call (c : c) (env : env) (k : code) (e : Scope.expr) (f : fn) (args : Scope.expr list) : unit =
  if List.length args <> List.length f.params then refuse e.loc "a partial application" "1c";
  List.iter (expr c env k) args;
  emit k (Il.Call f.tok)

and prim (c : c) (env : env) (k : code) (e : Scope.expr) (p : string) (args : Scope.expr list) : unit =
  let all () = List.iter (expr c env k) args in
  let op (o : Il.op) = all (); emit k o in
  let first () : S.t = match args with a :: _ -> cts_of a | [] -> S.Void in
  (* a comparison: a string's by CompareOrdinal against 0 *)
  let compare (lt : bool) (negate : bool) =
    if first () = S.String then begin
      all ();
      emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
      emit k (Il.Ldc_i4 0l)
    end
    else all ();
    (* (a float's NaN: unordered, so a <= b is not (a > b, or unordered)) *)
    let unordered = negate && first () = S.R8 in
    emit k (if lt then Il.Clt unordered else Il.Cgt unordered);
    if negate then (emit k (Il.Ldc_i4 0l); emit k Il.Ceq) in
  let equal () =
    if first () = S.String then op (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
    else op Il.Ceq in
  match p, args with
  | ("%addint" | "%addfloat"), _ -> op (Il.Binop Il.Add)
  | ("%subint" | "%subfloat"), _ -> op (Il.Binop Il.Sub)
  | ("%mulint" | "%mulfloat"), _ -> op (Il.Binop Il.Mul)
  | ("%divint" | "%divfloat"), _ -> op (Il.Binop Il.Div)
  | "%modint", _ -> op (Il.Binop Il.Rem)
  | ("%andint"), _ -> op (Il.Binop Il.And)
  | ("%orint"), _ -> op (Il.Binop Il.Or)
  | ("%xorint"), _ -> op (Il.Binop Il.Xor)
  | ("%negint" | "%negfloat"), _ -> op Il.Neg
  | "%lnot", _ -> op Il.Not
  | "%succint", _ -> all (); emit k (Il.Ldc_i8 1L); emit k (Il.Binop Il.Add)
  | "%predint", _ -> all (); emit k (Il.Ldc_i8 1L); emit k (Il.Binop Il.Sub)
  (* (a shift's count an int32, IL's) *)
  | ("%lslint" | "%asrint" | "%lsrint"), _ ->
      all ();
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Binop (match p with "%lslint" -> Il.Shl | "%asrint" -> Il.Shr | _ -> Il.Shr_un))
  | "%floatofint", _ -> op (Il.Conv (Il.K_r8, false, false))
  | "%intoffloat", _ -> op (Il.Conv (Il.K_i8, false, false))
  | "%boolnot", _ -> all (); emit k (Il.Ldc_i4 0l); emit k Il.Ceq
  | ("%equal" | "%eq"), _ -> equal ()
  | ("%notequal" | "%noteq"), _ -> equal (); emit k (Il.Ldc_i4 0l); emit k Il.Ceq
  | "%lessthan", _ -> compare true false
  | "%greaterthan", _ -> compare false false
  | "%lessequal", _ -> compare false true
  | "%greaterequal", _ -> compare true true
  | "%sequand", [ a; b ] ->
      let no = label k and over = label k in
      expr c env k a;
      emit k (Il.Brfalse no);
      expr c env k b;
      emit k (Il.Br over);
      place k no;
      emit k (Il.Ldc_i4 0l);
      place k over
  | "%sequor", [ a; b ] ->
      let yes = label k and over = label k in
      expr c env k a;
      emit k (Il.Brtrue yes);
      expr c env k b;
      emit k (Il.Br over);
      place k yes;
      emit k (Il.Ldc_i4 1l);
      place k over
  | "%string_length", _ -> all (); emit k (Il.Callvirt (lib c "String" "get_Length" (instance [] S.I4))); emit k (Il.Conv (Il.K_i8, false, false))
  | "%identity", _ -> all ()
  | "%ignore", [ a ] -> drop c env k a
  | "%raise", _ -> refuse e.loc "raise" "1b"
  | _ -> refuse e.loc ("the primitive " ^ p) "1a"

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

let is_function (e : Scope.expr) : bool = match e.e with Efunction _ -> true | Econstraint ({ e = Efunction _; _ }, _) -> true | _ -> false

(* a toplevel variable's global *)
let global_of (globals : (Scope.var * Scope.global) list) (v : Scope.var) : Scope.global option =
  Option.map snd (List.find_opt (fun ((v', _) : Scope.var * Scope.global) -> v'.vid = v.vid) globals)

(* a function's method declared (a let rec's all first, so that each
 * calls the others), its body made later *)
let declare (c : c) (env : env) (globals : (Scope.var * Scope.global) list) (v : Scope.var) (d : Scope.expr) : fn =
  let ps, body = params d in
  let params = List.map (fun ((v, ty) : Scope.var option * Scope.ty) -> (v, cts d.loc ty)) ps in
  let ret = cts body.loc (type_of body) in
  let sg = static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret in
  let tok = W.method_def c.w c.cls v.vname 0x0096 sg in
  let f = { tok; params; body } in
  Hashtbl.replace env.by_var v.vid f;
  (match global_of globals v with Some g -> Hashtbl.replace env.by_sym g.gsym f | None -> ());
  f

let define (c : c) (env : env) (f : fn) : unit =
  let k = new_code () in
  let n = ref 0 in
  List.iter
    (fun ((v, ty) : Scope.var option * S.t) ->
      if ty <> S.Void then begin
        (match v with Some v -> Hashtbl.replace k.args v.vid !n | None -> ());
        incr n
      end)
    f.params;
  expr c env k f.body;
  emit k Il.Ret;
  finish c k f.tok

let unit_ (name : string) (items : Scope.item list) : string =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console = W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  (* (a static class: abstract and sealed) *)
  let cls = W.type_def w "" name 0x00100181 obj in
  let c = { w; runtime; console; cls; memo = Hashtbl.create 64 } in
  Hashtbl.replace c.memo "type Object" obj;
  let env = { by_var = Hashtbl.create 16; by_sym = Hashtbl.create 16; fields = Hashtbl.create 16 } in
  let main = W.method_def w cls "Main" 0x0096 (static [] S.Void) in
  W.set_entry_point w main;
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
                let ty = cts_of d in
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
            | _ -> refuse d.loc "a toplevel let of a pattern" "1b")
          bs
    | Iexception (g, _) -> refuse 0 ("the exception " ^ g.gname) "1b"
    | Iexternal (g, _, _, _) -> refuse 0 ("the external " ^ g.gname) "1a" in
  List.iter item items;
  emit k Il.Ret;
  finish c k main;
  W.write w
