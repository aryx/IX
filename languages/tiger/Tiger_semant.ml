(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiger_semant.mli *)

open Tiger_tree
module A = Tiger_ast

exception Error of string * A.pos

let error (p : A.pos) (msg : string) = raise (Error (msg, p))

(* what a name means where it is used *)
type value =
  | V of var
  | F of func
  | B of string * ty list * ty          (* the library's *)

type env = {
  types : (string * ty) list;
  values : (string * value) list;
  exns : (string * exn) list;
  cur : func;                           (* the function being checked *)
  in_loop : bool;
}

(* the library: Appel's, fork-tiger's printi and sizea *)
let builtins = [
  "print", [ String ], Unit;
  "printi", [ Int ], Unit;
  "flush", [], Unit;
  "getchar", [], String;
  "ord", [ String ], Int;
  "chr", [ Int ], String;
  "size", [ String ], Int;
  "sizea", [], Int;
  "substring", [ String; Int; Int ], String;
  "concat", [ String; String ], String;
  "not", [ Int ], Int;
  "exit", [ Int ], Unit;
]

let counter = ref 0
let fresh () : int = incr counter; !counter

let all_funcs : func list ref = ref []
let all_records : record list ref = ref []
let all_exns : exn list ref = ref []

let rec show (t : ty) : string =
  match t with
  | Int -> "int" | String -> "string" | Unit -> "unit" | Nil -> "nil"
  | Record r -> r.rname
  | Array a -> a.aname ^ " (array of " ^ show a.elem ^ ")"

(* can a value of type [a] go where [b] is asked? *)
let fits (a : ty) (b : ty) : bool =
  match a, b with
  | Record r, Record s -> r == s
  | Array x, Array y -> x == y
  | Nil, Record _ -> true
  | Int, Int | String, String | Unit, Unit -> true
  | _ -> false

let expect (p : A.pos) (what : string) (got : ty) (want : ty) : unit =
  if not (fits got want) then
    error p (Printf.sprintf "%s: %s expected, not %s" what (show want) (show got))

let find_type (env : env) (n : string) (p : A.pos) : ty =
  match List.assoc_opt n env.types with
  | Some t -> t
  | None -> error p ("no type " ^ n)

let mk (e : desc) (ty : ty) : exp = { e; ty }

(* ------------------------------------------------------------------ *)
(* Expressions *)
(* ------------------------------------------------------------------ *)

let rec exp (env : env) (x : A.exp) : exp =
  match x with
  | A.Nil _ -> mk Nil_e Nil
  | A.Int (n, _) -> mk (Int_e n) Int
  | A.String (s, _) -> mk (String_e s) String
  | A.Var v -> let lv, t = lvalue env v in mk (Var_e lv) t
  | A.Op (a, op, b, p) ->
      let a = exp env a and b = exp env b in
      (match op with
       | A.Plus | A.Minus | A.Times | A.Divide ->
           expect p "an arithmetic's left" a.ty Int;
           expect p "an arithmetic's right" b.ty Int
       | A.Eq | A.Neq ->
           (* (nil = nil: a variable of fork-tiger's var x := nil) *)
           if a.ty = Unit || not (fits a.ty b.ty || fits b.ty a.ty || (a.ty = Nil && b.ty = Nil)) then
             error p (Printf.sprintf "%s and %s compared" (show a.ty) (show b.ty))
       | A.Lt | A.Le | A.Gt | A.Ge ->
           if not ((a.ty = Int && b.ty = Int) || (a.ty = String && b.ty = String)) then
             error p (Printf.sprintf "%s and %s compared: two ints or two strings are"
                        (show a.ty) (show b.ty)));
      mk (Op_e (a, op, b)) Int
  | A.Call (f, args, p) ->
      let args = List.map (exp env) args in
      let check params =
        if List.length params <> List.length args then
          error p (Printf.sprintf "%s: %d arguments expected, not %d" f (List.length params) (List.length args));
        List.iteri (fun i ((a : exp), t) ->
            (match a.e, a.ty, t with
             | Var_e (Simple var), Nil, Record _ -> var.vty <- t
             | _ -> ());
            expect p (Printf.sprintf "%s's argument %d" f (i + 1)) a.ty t)
          (List.combine args params) in
      (match List.assoc_opt f env.values with
       | Some (F fn) -> check (List.map (fun v -> v.vty) fn.params); mk (Call_e (fn, args)) fn.result
       | Some (B ("sizea", _, r)) ->
           (* (fork-tiger's: an array's length, of any array) *)
           (match args with
            | [ { ty = Array _; _ } ] -> mk (Builtin_e ("sizea", args)) r
            | _ -> error p "sizea: an array expected")
       | Some (B (name, params, r)) -> check params; mk (Builtin_e (name, args)) r
       | Some (V _) -> error p (f ^ " is a variable, not a function")
       | None -> error p ("no function " ^ f))
  | A.Record (tn, fields, p) ->
      (match find_type env tn p with
       | Record r ->
           if List.length fields <> List.length r.rfields then
             error p (Printf.sprintf "%s: %d fields expected" tn (List.length r.rfields));
           let es = List.map2 (fun (n, e, fp) (rn, rt) ->
               if n <> rn then error fp (Printf.sprintf "%s: the field %s expected, not %s" tn rn n);
               let e = exp env e in
               expect fp ("the field " ^ n) e.ty rt;
               e) fields r.rfields in
           mk (Record_e (r, es)) (Record r)
       | t -> error p (tn ^ " is " ^ show t ^ ", not a record"))
  | A.Array (tn, size, init, p) ->
      (match find_type env tn p with
       | Array a ->
           let size = exp env size and init = exp env init in
           expect p "an array's size" size.ty Int;
           expect p "an array's initial value" init.ty a.elem;
           mk (Array_e (a, size, init)) (Array a)
       | t -> error p (tn ^ " is " ^ show t ^ ", not an array"))
  | A.Seq ([], _) -> mk (Seq_e []) Unit
  | A.Seq (l, _) ->
      let l = List.map (exp env) l in
      mk (Seq_e l) (List.nth l (List.length l - 1)).ty
  | A.Assign (v, e, p) ->
      let lv, t = lvalue env v in
      (match lv with
       | Simple var when var.readonly -> error p ("the loop's variable " ^ var.vname ^ " assigned")
       | _ -> ());
      let e = exp env e in
      (match lv, t, e.ty with
       | Simple var, Nil, (Record _ as r) -> var.vty <- r
       | _ -> expect p "an assignment" e.ty t);
      mk (Assign_e (lv, e)) Unit
  | A.If (c, t, None, p) ->
      let c = exp env c and t = exp env t in
      expect p "a condition" c.ty Int;
      expect p "an if without else" t.ty Unit;
      mk (If_e (c, t, None)) Unit
  | A.If (c, t, Some f, p) ->
      let c = exp env c and t = exp env t and f = exp env f in
      expect p "a condition" c.ty Int;
      let ty = if fits t.ty f.ty then f.ty else if fits f.ty t.ty then t.ty
        else error p (Printf.sprintf "then and else differ: %s and %s" (show t.ty) (show f.ty)) in
      mk (If_e (c, t, Some f)) ty
  | A.While (c, b, p) ->
      let c = exp env c and b = exp { env with in_loop = true } b in
      expect p "a condition" c.ty Int;
      expect p "a while's body" b.ty Unit;
      mk (While_e (c, b)) Unit
  | A.For (i, lo, hi, body, p) ->
      let lo = exp env lo and hi = exp env hi in
      expect p "a for's start" lo.ty Int;
      expect p "a for's end" hi.ty Int;
      let v = new_var env i Int (-1) true in
      let body = exp { env with values = (i, V v) :: env.values; in_loop = true } body in
      expect p "a for's body" body.ty Unit;
      mk (For_e (v, lo, hi, body)) Unit
  | A.Break p -> if not env.in_loop then error p "a break outside a loop"; mk Break_e Unit
  | A.Let (decs, body, _) ->
      let env, vars = List.fold_left (fun (env, vars) d -> dec env vars d) (env, []) decs in
      let body = exp env body in
      mk (Let_e (List.rev vars, body)) body.ty
  | A.Try (body, handlers, p) ->
      let body = exp env body in
      let hs = List.map (fun (n, h, hp) ->
          let x = match List.assoc_opt n env.exns with
            | Some x -> x | None -> error hp ("no exception " ^ n) in
          let h = exp env h in
          expect hp "a handler" h.ty body.ty;
          (x, h)) handlers in
      ignore p;
      mk (Try_e (body, hs)) body.ty
  | A.Raise (n, p) ->
      (match List.assoc_opt n env.exns with
       | Some x -> mk (Raise_e x) Unit
       | None -> error p ("no exception " ^ n))

and new_var (env : env) (name : string) (ty : ty) (param : int) (readonly : bool) : var =
  let v = { vname = name; vid = fresh (); vty = ty; vfun = env.cur; param; escapes = false; readonly } in
  env.cur.vars <- env.cur.vars @ [ v ];
  v

and lvalue (env : env) (v : A.var) : lvalue * ty =
  match v with
  | A.Simple (n, p) ->
      (match List.assoc_opt n env.values with
       | Some (V var) ->
           (* used by a function other than its own: it escapes *)
           if var.vfun != env.cur then var.escapes <- true;
           (Simple var, var.vty)
       | Some _ -> error p (n ^ " is a function, not a variable")
       | None -> error p ("no variable " ^ n))
  | A.Field (v, f, p) ->
      (match lvalue env v with
       | lv, Record r ->
           let rec find i l = match l with
             | [] -> error p (Printf.sprintf "%s has no field %s" r.rname f)
             | (n, t) :: rest -> if n = f then (Field (lv, r, i), t) else find (i + 1) rest in
           find 0 r.rfields
       | _, t -> error p (Printf.sprintf "a field %s of %s, not a record" f (show t)))
  | A.Subscript (v, i, p) ->
      (match lvalue env v with
       | lv, Array a ->
           let i = exp env i in
           expect p "an index" i.ty Int;
           (Subscript (lv, a, i), a.elem)
       | _, t -> error p (Printf.sprintf "an index of %s, not an array" (show t)))

(* ------------------------------------------------------------------ *)
(* Declarations *)
(* ------------------------------------------------------------------ *)

and dec (env : env) (vars : (var * exp) list) (d : A.dec) : env * (var * exp) list =
  match d with
  | A.VarDec (n, t, init, p) ->
      let init = exp env init in
      let ty = match t with
        | Some (tn, tp) -> let t = find_type env tn tp in expect p ("the variable " ^ n) init.ty t; t
        | None ->
            (* (var x := nil: an error in Appel's Tiger; fork-tiger's
             * programs have it, x then the type of the first record it
             * is given) *)
            if init.ty = Unit then error p ("no value given to " ^ n);
            init.ty in
      let v = new_var env n ty (-1) false in
      ({ env with values = (n, V v) :: env.values }, (v, init) :: vars)
  | A.TypeDecs group -> (types env group, vars)
  | A.FunDecs group -> (funcs env group, vars)
  | A.ExnDec (n, _) ->
      let x = { ename = n; eid = fresh () } in
      all_exns := !all_exns @ [ x ];
      ({ env with exns = (n, x) :: env.exns }, vars)

(* a group of types, which may name each other: the records and arrays
 * made first, empty, the names then followed (a cycle of names alone
 * is an error), the fields and elements last *)
and types (env : env) (group : (string * A.ty * A.pos) list) : env =
  let rec dups l = match l with
    | [] -> ()
    | (n, _, p) :: rest ->
        if List.exists (fun (m, _, _) -> m = n) rest then error p ("the type " ^ n ^ " declared twice in a group");
        dups rest in
  dups group;
  let made = List.filter_map (fun (n, t, _) -> match t with
      | A.RecordTy _ ->
          let r = { rname = n; rid = fresh (); rfields = [] } in
          all_records := !all_records @ [ r ];
          Some (n, Record r)
      | A.ArrayTy _ -> Some (n, Array { aname = n; aid = fresh (); elem = Unit })
      | A.NameTy _ -> None) group in
  let rec resolve (seen : string list) (n : string) (p : A.pos) : ty =
    match List.assoc_opt n made with
    | Some t -> t
    | None ->
        match List.find_opt (fun (m, _, _) -> m = n) group with
        | Some (_, A.NameTy (m, mp), _) ->
            if List.mem n seen then error p ("the types " ^ String.concat ", " (List.rev seen) ^ " are a cycle")
            else resolve (n :: seen) m mp
        | _ -> find_type env n p in
  let named = List.map (fun (n, _, p) -> (n, resolve [] n p)) group in
  let env = { env with types = named @ env.types } in
  List.iter (fun (n, t, _) -> match t, List.assoc n named with
      | A.RecordTy fields, Record r ->
          r.rfields <- List.map (fun (f, tn, p) -> (f, find_type env tn p)) fields
      | A.ArrayTy (tn, p), Array a -> a.elem <- find_type env tn p
      | _ -> ()) group;
  env

(* a group of functions: their headers first, so they may call each
 * other, then their bodies, each checked in a function of its own *)
and funcs (env : env) (group : A.fundec list) : env =
  let rec dups l = match l with
    | [] -> ()
    | (f : A.fundec) :: rest ->
        if List.exists (fun (g : A.fundec) -> g.fname = f.fname) rest then
          error f.fpos ("the function " ^ f.fname ^ " declared twice in a group");
        dups rest in
  dups group;
  env.cur.nested <- true;
  let made = List.map (fun (f : A.fundec) ->
      let fn = { name = Printf.sprintf "%s_%d" f.fname (fresh ()); fid = 0; parent = Some env.cur;
                 params = []; result = Unit; nested = false; vars = []; fbody = None } in
      fn.result <- (match f.result with Some (tn, p) -> find_type env tn p | None -> Unit);
      let fenv = { env with cur = fn } in
      fn.params <- List.mapi (fun i (n, tn, p) -> new_var fenv n (find_type env tn p) i false) f.params;
      all_funcs := !all_funcs @ [ fn ];
      (f, fn)) group in
  let env = { env with values = List.map (fun ((f : A.fundec), fn) -> (f.fname, F fn)) made @ env.values } in
  List.iter (fun ((f : A.fundec), fn) ->
      let values = List.map (fun v -> (v.vname, V v)) fn.params @ env.values in
      let body = exp { env with values; cur = fn; in_loop = false } f.body in
      expect f.fpos ("the body of " ^ f.fname) body.ty fn.result;
      fn.fbody <- Some body) made;
  env

let program (e : A.exp) : program =
  counter := 0; all_funcs := []; all_records := []; all_exns := [];
  let main = { name = "main"; fid = 0; parent = None; params = []; result = Unit;
               nested = false; vars = []; fbody = None } in
  let env = { types = [ "int", Int; "string", String ];
              values = List.map (fun (n, ps, r) -> (n, B (n, ps, r))) builtins;
              exns = []; cur = main; in_loop = false } in
  let body = exp env e in
  main.result <- body.ty;
  main.fbody <- Some body;
  { main; funcs = !all_funcs; records = !all_records; exns = !all_exns }
