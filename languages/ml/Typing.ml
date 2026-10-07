(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Typing.mli *)

exception Error of int * string

(* a variable is a cell: unbound (its number, its level), or linked to
 * what it became; a constructor is its declaration, Scope's *)
type t = Var of tv ref | Con of Scope.tdecl * t list | Arrow of t * t | Tuple of t list
and tv = Unbound of int * int | Link of t

let generic = max_int
let level = ref 1
let counter = ref 0
let newvar () = incr counter; Var (ref (Unbound (!counter, !level)))
let loc = ref 0
let error fmt = Printf.ksprintf (fun m -> raise (Error (!loc, m))) fmt

let of_scope_const = function Scope.Tconstr (d, []) -> Con (d, []) | _ -> assert false
let int_t = of_scope_const Resolve.int_t and char_t = of_scope_const Resolve.char_t
let string_t = of_scope_const Resolve.string_t and float_t = of_scope_const Resolve.float_t
let bool_t = of_scope_const Resolve.bool_t and unit_t = of_scope_const Resolve.unit_t and exn_t = of_scope_const Resolve.exn_t

let rec repr t = match t with Var { contents = Link t } -> repr t | t -> t

(* a declared type, its variables named: each name's type in vars,
 * a fresh one the first time *)
let rec of_ty vars (ty : Scope.ty) =
  match ty with
  | Tvar "_" -> newvar ()                 (* each _ a type of its own *)
  | Tvar v -> (match List.assoc_opt v !vars with Some t -> t | None -> let t = newvar () in vars := (v, t) :: !vars; t)
  | Tarrow (a, b) -> Arrow (of_ty vars a, of_ty vars b)
  | Ttuple ts -> Tuple (List.map (of_ty vars) ts)
  | Tconstr (d, args) -> Con (d, List.map (of_ty vars) args)

let instance ty = of_ty (ref []) ty

(* a type written in an expression or a pattern: a variable's name is
 * one type in the whole toplevel definition, as OCaml's ((x : 'a) and
 * (y : 'a)), and generalized with it only (the definition's level) *)
let tvars : (string * t) list ref = ref []
let annot ty =
  let rec names (ty : Scope.ty) =
    match ty with
    | Tvar "_" -> ()
    | Tvar v ->
        if not (List.mem_assoc v !tvars) then begin
          let l = !level in
          level := min l 2;
          tvars := (v, newvar ()) :: !tvars;
          level := l
        end
    | Tarrow (a, b) -> names a; names b
    | Ttuple ts | Tconstr (_, ts) -> List.iter names ts
  in
  names ty;
  of_ty tvars ty

(* an abbreviation's body, its parameters the arguments *)
let expand (d : Scope.tdecl) args =
  match d.tabbrev with
  | Some body when List.length d.tparams = List.length args -> Some (of_ty (ref (List.combine d.tparams args)) body)
  | _ -> None

(* a type with its abbreviations opened, at its head ('a Logs.msgf is a function's) *)
let rec expanded t = match repr t with Con (d, args) -> (match expand d args with Some t -> expanded t | None -> repr t) | t -> t

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

let current = ref ""

(* the unit's own types, and Pervasives's, by their names *)
let path (d : Scope.tdecl) =
  let strip p s = if String.starts_with ~prefix:(p ^ ".") s then String.sub s (String.length p + 1) (String.length s - String.length p - 1) else s in
  strip "Pervasives" (strip !current d.tpath)

let show_with names t =
  let name r =
    match List.assq_opt r !names with
    | Some n -> n
    | None ->
        let weak = match !r with Unbound (_, l) -> l <> generic | Link _ -> false in
        let n = List.length !names in
        let s = (if weak then "'_" else "'") ^ (if n < 26 then String.make 1 (Char.chr (97 + n)) else Printf.sprintf "a%d" n) in
        names := (r, s) :: !names;
        s
  in
  let rec go prec t =
    let paren p s = if prec > p then "(" ^ s ^ ")" else s in
    match repr t with
    | Var r -> name r
    | Arrow (a, b) -> let a = go 1 a in paren 0 (a ^ " -> " ^ go 0 b)
    | Tuple ts -> paren 1 (String.concat " * " (List.map (go 2) ts))
    | Con (d, []) -> path d
    | Con (d, [ a ]) -> go 2 a ^ " " ^ path d
    | Con (d, args) -> "(" ^ String.concat ", " (List.map (go 0) args) ^ ") " ^ path d
  in
  go 0 t

let show t = show_with (ref []) t

(*****************************************************************************)
(* Unification *)
(*****************************************************************************)

(* r's variable in t is a cycle; a variable met in t at a deeper level
 * takes r's, so that it is generalized only where both are *)
let rec occurs r lv t =
  match repr t with
  | Var r' when r == r' -> error "a type would be recursive"
  | Var ({ contents = Unbound (n, l) } as r') -> if l > lv then r' := Unbound (n, lv)
  | Var _ -> ()
  | Con (_, ts) | Tuple ts -> List.iter (occurs r lv) ts
  | Arrow (a, b) -> occurs r lv a; occurs r lv b

exception Clash

let rec unify_ a b =
  let a = repr a and b = repr b in
  if a != b then
    match a, b with
    | Var ({ contents = Unbound (_, l) } as r), t | t, Var ({ contents = Unbound (_, l) } as r) -> occurs r l t; r := Link t
    | Arrow (a1, r1), Arrow (a2, r2) -> unify_ a1 a2; unify_ r1 r2
    | Tuple l1, Tuple l2 when List.length l1 = List.length l2 -> List.iter2 unify_ l1 l2
    | Con (d1, l1), Con (d2, l2) when d1.tpath = d2.tpath && List.length l1 = List.length l2 -> List.iter2 unify_ l1 l2
    | Con (d, l), _ when expand d l <> None -> unify_ (Option.get (expand d l)) b
    | _, Con (d, l) when expand d l <> None -> unify_ a (Option.get (expand d l))
    | _ -> raise Clash

let unify_what what a b =
  try unify_ a b
  with Clash ->
    let names = ref [] in
    let sa = show_with names a in
    error "%s has type %s but is used with type %s" what sa (show_with names b)

let unify a b = unify_what "this expression" a b

(* an arrow, through the abbreviations; a variable made one *)
let rec arrow t =
  match repr t with
  | Arrow (a, r) -> a, r
  | Con (d, l) when expand d l <> None -> arrow (Option.get (expand d l))
  | t -> let a = newvar () and r = newvar () in unify_what "this function" t (Arrow (a, r)); a, r

(*****************************************************************************)
(* Generalization *)
(*****************************************************************************)

let rec generalize t =
  match repr t with
  | Var ({ contents = Unbound (n, l) } as r) when l > !level -> r := Unbound (n, generic)
  | Var _ -> ()
  | Con (_, ts) | Tuple ts -> List.iter generalize ts
  | Arrow (a, b) -> generalize a; generalize b

let instantiate t =
  let copies = ref [] in
  let rec go t =
    match repr t with
    | Var ({ contents = Unbound (_, l) } as r) when l = generic -> (
        match List.assq_opt r !copies with Some v -> v | None -> let v = newvar () in copies := (r, v) :: !copies; v)
    | Var _ as t -> t
    | Con (d, ts) -> Con (d, List.map go ts)
    | Tuple ts -> Tuple (List.map go ts)
    | Arrow (a, b) -> Arrow (go a, go b)
  in
  go t

(* the value restriction: only a value is generalized *)
let rec nonexpansive (e : Scope.expr) =
  match e.e with
  | Evar _ | Econst _ | Efunction _ -> true
  | Econs (_, l) | Etuple l -> List.for_all nonexpansive l
  | Erecord (_, fs) -> List.for_all (fun ((l : Scope.label), e) -> (not l.mut) && nonexpansive e) fs
  | Earray [] -> true
  | Elet (_, bs, b) -> List.for_all (fun (_, e) -> nonexpansive e) bs && nonexpansive b
  | Econstraint (e, _) -> nonexpansive e
  | _ -> false

(*****************************************************************************)
(* Formats *)
(*****************************************************************************)

(* Printf's format: ('a, 'b, 'c, 'd) format4, 'a the conversions' types
 * ending in 'd: %d an int, %s a string, %a a printer of 'b and its
 * argument giving a 'c, %t a function of 'b *)
let format s =
  let b = newvar () and c = newvar () and d = newvar () in
  let n = String.length s in
  let rec go i =
    if i >= n then d
    else if s.[i] <> '%' then go (i + 1)
    else begin
      let j = ref (i + 1) in
      while !j < n && String.contains "-+ #0123456789.*" s.[!j] do incr j done;
      if !j >= n then error "the format %S ends in a %%" s;
      (* %ld an int32, %Ld an int64: the l, L before an integer's letter *)
      let boxed = match s.[!j] with
        | ('l' | 'L') as c when !j + 1 < n && String.contains "diuxXo" s.[!j + 1] ->
            incr j; Some (Resolve.boxed_int_type (if c = 'l' then "Int32" else "Int64"))
        | _ -> None in
      let rest = go (!j + 1) in
      (* a * among the flags (a width, a precision) is an int given before the value *)
      let stars = ref 0 in
      String.iteri (fun k ch -> if k > i && k < !j && ch = '*' then incr stars) s;
      let rec given k t = if k = 0 then t else Arrow (int_t, given (k - 1) t) in
      given !stars
        (match s.[!j] with
      | '%' | '!' -> rest
      | 'd' | 'i' | 'u' | 'x' | 'X' | 'o' when boxed <> None ->
          (match boxed with Some t -> Arrow (of_scope_const t, rest) | None -> rest)
      | 'd' | 'i' | 'u' | 'x' | 'X' | 'o' | 'n' | 'N' -> Arrow (int_t, rest)
      | 'c' | 'C' -> Arrow (char_t, rest)
      | 's' | 'S' -> Arrow (string_t, rest)
      | 'f' | 'e' | 'E' | 'g' | 'G' | 'F' | 'h' -> Arrow (float_t, rest)
      | 'b' | 'B' -> Arrow (bool_t, rest)
      | 'a' -> let x = newvar () in Arrow (Arrow (b, Arrow (x, c)), Arrow (x, rest))
      | 't' -> Arrow (Arrow (b, c), rest)
      | ch -> error "the format %S: %%%c" s ch)
    end
  in
  Con (Resolve.format4_d, [ go 0; b; c; d ])

let is_format t = match repr t with Con (d, _) -> d.tpath = Resolve.format_d.tpath || d.tpath = Resolve.format4_d.tpath | _ -> false

(*****************************************************************************)
(* mlpp: the classes' dictionaries *)
(*****************************************************************************)

(* A class is a record type, an instance a value of it, and a parameter
 * of the type [%using: 'a show] a dictionary the calls don't write
 * (Resolve's implicit): where a name of such a type is used, its
 * dictionaries' types are left wanted, with the variables in scope, and
 * the name has its type without them. When its toplevel definition is
 * typed, each one is found from what its type has become:
 * - a type's constructor: the class's instance for it (Resolve's),
 *   whose own dictionaries are found the same way, show_list show_int;
 * - a variable: the parameter of the function around that is this
 *   class's at that variable (givens, by their numbers);
 * and nothing else: no constraint is inferred, a function that needs a
 * dictionary says so. What is found is text, for mlpp to write after
 * the name (dictionaries), or why none is.
 * Then a definition's type error doesn't stop the unit (errors): mlpp
 * writes the dictionaries it has, and OCaml, or merlin, says the error
 * at its place. *)
let wanted : (Ast.span * int * t list * (int * t) list) list ref = ref []
let givens : (int, string) Hashtbl.t = Hashtbl.create 16
let found : (Ast.span * int * (string, string) result) list ref = ref []
let failures : (int * string) list ref = ref []
let dictionaries () = List.rev !found
let errors () = List.rev !failures
(* the last dictionary not found was a type variable's *)
let unknown = ref false

let using t = match repr t with Con (d, [ c ]) when d == Resolve.using_d -> Some c | _ -> None

let implicit env (e : Scope.expr) t =
  let rec peel acc t = match repr t with Arrow (a, r) when using a <> None -> peel (Option.get (using a) :: acc) r | t -> List.rev acc, t in
  match if !Resolve.implicit then peel [] t else [], t with
  | [], _ -> t
  | cs, r -> wanted := (e.span, e.loc, cs, env) :: !wanted; r

(* a written type's variables from the type it is to be: an instance's
 * 'a list show against int list show (not unified: the variables of a
 * definition already generalized would be lowered) *)
let rec matching m (p : Scope.ty) t =
  match p, repr t with
  | Tvar v, t -> if not (List.mem_assoc v !m) then m := (v, t) :: !m
  | Tconstr (d, ps), Con (d', ts) when d.tpath = d'.tpath && List.length ps = List.length ts -> List.iter2 (matching m) ps ts
  | Ttuple ps, Tuple ts when List.length ps = List.length ts -> List.iter2 (matching m) ps ts
  | Tarrow (a, b), Arrow (a', b') -> matching m a a'; matching m b b'
  | _, Con (d, l) when expand d l <> None -> matching m p (Option.get (expand d l))
  | _ -> ()

let rec dictionary depth env c =
  let cls, arg = match repr c with Con (d, [ a ]) when Resolve.is_class d -> d, a | _ -> error "[%%using: %s]: not a class's type" (show c) in
  if depth > 20 then error "the instances of %s: no end to their own dictionaries" cls.tpath;
  let instance key t =
    match Resolve.instance cls key, t with
    | Some (name, ty), _ ->
        (* its own dictionaries, [%using: 'a show] -> 'a list show: 'a from the type wanted *)
        let rec split (ty : Scope.ty) =
          match ty with
          | Tarrow (Tconstr (d, [ c' ]), r) when d == Resolve.using_d -> let cs, r = split r in c' :: cs, r
          | r -> [], r
        in
        let cs, r = split ty and m = ref [] in
        matching m r c;
        (match List.map (fun c' -> dictionary (depth + 1) env (of_ty m c')) cs with
         | [] -> name
         | l -> "(" ^ String.concat " " (name :: l) ^ ")")
    (* an abbreviation: what it stands for *)
    | None, Con (d, l) when expand d l <> None -> dictionary depth env (Con (cls, [ Option.get (expand d l) ]))
    | None, _ -> error "no instance of %s for %s" (path cls) (show t)
  in
  match repr arg with
  | Var r -> (
      let given (id, t) =
        match Hashtbl.find_opt givens id, repr t with
        | Some x, Con (d, [ a ]) when d.tpath = cls.tpath && (match repr a with Var r' -> r == r' | _ -> false) -> Some x
        | _ -> None
      in
      match List.find_map given env with
      | Some x -> x
      | None -> unknown := true; error "%s of a type not known here: annotate it, or give the function the parameter [%%using: 'a %s]" (path cls) (path cls))
  | Con (d, _) as t -> instance d.tpath t
  | Tuple ts as t -> instance (Printf.sprintf "*%d" (List.length ts)) t
  | Arrow _ as t -> error "no instance of %s for a function, %s" (path cls) (show t)

(* a toplevel definition typed: its dictionaries; failed: it has a type
 * error, and a type not known may be for that: left out *)
let find_wanted failed =
  List.iter (fun (span, l, cs, env) ->
    loc := l;
    unknown := false;
    match String.concat " " (List.map (dictionary 0 env) cs) with
    | d -> found := (span, l, Ok d) :: !found
    | exception Error (_, m) -> if not (failed && !unknown) then found := (span, l, Error m) :: !found) (List.rev !wanted);
  wanted := []

(*****************************************************************************)
(* Patterns and expressions *)
(*****************************************************************************)

(* the current unit's globals: their types, by symbol *)
let globals : (string, t) Hashtbl.t = Hashtbl.create 64

(* a constructor's or a label's type, its declaration's parameters
 * fresh (the same for all a record's labels, by vars) *)
let cons_type (c : Scope.cons) =
  let params, args, res = c.ctype in
  let vars = ref (List.map (fun p -> p, newvar ()) params) in
  List.map (of_ty vars) args, of_ty vars res

let label_types vars (l : Scope.label) =
  let params, field, res = l.ltype in
  if !vars = [] then vars := List.map (fun p -> p, newvar ()) params;
  of_ty vars field, of_ty vars res

(* A field's label, type-directed: the one of this name in the record's
 * type t, when t is known by now and has one; else Scope's (the last
 * type declared with that name, in scope), and none is an error. Its
 * position is written in l, the node's own, for Lower. *)
let field (l : Scope.label) t =
  let l' = match repr t with Con (d, _) -> (match Resolve.type_field d l.lname with Some l' -> l' | None -> l) | _ -> l in
  if l'.pos < 0 then error "the field %s: its record's type is not known here; annotate the record, (r : M.t)" l.lname;
  l.pos <- l'.pos;
  l'

let const_type = function
  | Ast.Int _ -> int_t | Char _ -> char_t | String _ -> string_t | Float _ -> float_t
  | Int32 _ -> of_scope_const (Resolve.boxed_int_type "Int32")
  | Int64 _ -> of_scope_const (Resolve.boxed_int_type "Int64")

(* a pattern's type, and its variables' *)
let rec pattern (p : Scope.pattern) : t * (int * t) list =
  match p with
  | Pany -> newvar (), []
  | Pvar v -> let t = newvar () in t, [ v.vid, t ]
  | Palias (p, v) -> let t, bs = pattern p in t, (v.vid, t) :: bs
  | Pconst c -> const_type c, []
  | Prange _ -> char_t, []
  | Ptuple ps -> let l = List.map pattern ps in Tuple (List.map fst l), List.concat_map snd l
  | Pcons (c, ps) ->
      let args, res = cons_type c in
      res, List.concat (List.map2 (fun p t -> let pt, bs = pattern p in unify_what "this pattern" pt t; bs) ps args)
  | Precord fs ->
      let vars = ref [] in
      let res = ref None in
      let bs =
        List.concat_map (fun (l, p) ->
          let field, r = label_types vars l in
          (match !res with Some r' -> unify_what "this record" r' r | None -> res := Some r);
          let pt, bs = pattern p in
          unify_what "this field" pt field;
          bs) fs
      in
      Option.get !res, bs
  | Pconstraint (p, ty) -> (
      let t, bs = pattern p and want = annot ty in
      (* mlpp: (d : [%using: 'a show]), d a dictionary, the function's type saying using *)
      match using want, p with
      | Some c, Pvar v -> Hashtbl.replace givens v.vid v.vname; unify_what "this pattern" t c; want, bs
      | _ -> unify_what "this pattern" t want; t, bs)
  | Por (a, b) ->
      let t, ba = pattern a and u, bb = pattern b in
      unify_what "this pattern" t u;
      List.iter (fun (id, t) -> match List.assoc_opt id ba with Some t' -> unify_what "this variable" t t' | None -> ()) bb;
      t, ba

let rec infer env (e : Scope.expr) : t =
  let saved = !loc in
  loc := e.loc;
  let t = infer_ env e in
  loc := saved;
  t

and infer_ env (e : Scope.expr) =
  match e.e with
  | Econst c -> const_type c
  (* mlpp: implicit *)
  | Evar (Local v) -> (match List.assoc_opt v.vid env with Some t -> implicit env e (instantiate t) | None -> error "%s: no type" v.vname)
  | Evar (Global g) -> (
      match Hashtbl.find_opt globals g.gsym, g.gtype with
      | Some t, _ -> implicit env e (instantiate t)
      | None, Some ty -> implicit env e (instance ty)
      | None, None -> newvar ())
  | Evar (Prim (_, _, ty)) -> instance ty
  | Elet (false, bs, body) -> infer (let_ env bs) body
  | Elet (true, bs, body) -> infer (letrec env bs) body
  | Efunction cs ->
      let a = newvar () and r = newvar () in
      cases env a r cs;
      Arrow (a, r)
  | Eapply (f, args) ->
      List.fold_left (fun tf (arg : Scope.expr) ->
        let a, r = arrow tf in
        (match arg.e with
         | Econst (String s) when is_format a -> loc := arg.loc; unify a (format s)
         | _ -> under env arg a);
        loc := e.loc;
        r) (infer env f) args
  | Ematch (s, cs) -> let r = newvar () in cases env (infer env s) r cs; r
  | Etry (b, cs) -> let r = infer env b in cases env exn_t r cs; r
  | Etuple es -> Tuple (List.map (infer env) es)
  | Econs (c, args) ->
      let targs, res = cons_type c in
      List.iter2 (fun a t -> unify (infer env a) t) args targs;
      res
  | Erecord (_, fs) -> record env (newvar ()) fs
  | Ewith (r, _, fs) -> let t = infer env r in record env t fs
  | Efield (r, l) -> let t = infer env r in let field, res = label_types (ref []) (field l t) in unify t res; field
  | Esetfield (r, l, v) ->
      let t = infer env r in
      let l = field l t in
      if not l.mut then error "the field %s is not mutable" l.lname;
      let field, res = label_types (ref []) l in
      unify t res;
      unify (infer env v) field;
      unit_t
  | Earray es -> let a = newvar () in List.iter (fun e -> unify (infer env e) a) es; Con (Resolve.array_d, [ a ])
  | Eif (c, a, b) ->
      unify_what "this condition" (infer env c) bool_t;
      let t = infer env a in
      (match b with Some b -> unify (infer env b) t | None -> unify t unit_t);
      t
  | Eseq (a, b) -> ignore (infer env a); infer env b
  | Ewhile (c, b) -> unify (infer env c) bool_t; ignore (infer env b); unit_t
  | Efor (v, a, b, _, body) ->
      unify (infer env a) int_t;
      unify (infer env b) int_t;
      ignore (infer ((v.vid, int_t) :: env) body);
      unit_t
  | Econstraint ({ e = Econst (String s); _ }, ty) when is_format (instance ty) -> let t = annot ty in unify t (format s); t
  | Econstraint (e, ty) -> let t = annot ty in unify (infer env e) t; t
  | Eassert { e = Econs ({ cname = "false"; _ }, []); _ } -> newvar ()
  | Eassert c -> unify (infer env c) bool_t; unit_t

(* e, of type t. A function given where a function's type is expected
 * (a parameter's, a record's field's) has its clauses under that type,
 * so that (fun r -> r.l) has r's type for its field (type-directed,
 * above) *)
and under env (e : Scope.expr) t =
  match e.e with
  | Efunction cs when (match expanded t with Arrow _ -> true | _ -> false) ->
      let pa, pr = arrow (expanded t) in
      let saved = !loc in
      loc := e.loc;
      cases env pa pr cs;
      loc := saved
  | _ -> unify (infer env e) t

(* a record's fields: their labels' types, one instance of the record's
 * parameters *)
and record env t fs =
  let vars = ref [] in
  List.iter (fun (l, e) ->
    let field, res = label_types vars l in
    unify_what "this record" t res;
    under env e field) fs;
  t

and cases env a r cs =
  List.iter (fun (p, g, body) ->
    let pt, bs = pattern p in
    unify_what "this pattern" pt a;
    let env = bs @ env in
    Option.iter (fun g -> unify (infer env g) bool_t) g;
    unify (infer env body) r) cs

(* let: each value at a deeper level, generalized if it is a value; else
 * its variables lowered to the let's level *)
and let_ env bs =
  List.concat_map (fun (p, e) ->
    incr level;
    let t = infer env e in
    let pt, vs = pattern p in
    unify_what "this pattern" pt t;
    decr level;
    if nonexpansive e then List.iter (fun (_, t) -> generalize t) vs else List.iter (fun (_, t) -> unify (newvar ()) t) vs;
    vs) bs
  @ env

and letrec env bs =
  incr level;
  (* mlpp: a function's dictionaries known in its own body, where it calls itself *)
  let rec shape (e : Scope.expr) =
    match e.e with
    | Efunction [ (Pconstraint (_, (Tconstr (d, _) as ty)), None, body) ] when d == Resolve.using_d -> Arrow (annot ty, shape body)
    | _ -> newvar ()
  in
  let vs = List.map (function Scope.Pvar v, e -> v.vid, shape e | _ -> error "let rec: a name expected") bs in
  let env' = vs @ env in
  List.iter2 (fun (_, t) (_, e) -> unify (infer env' e) t) vs bs;
  decr level;
  List.iter (fun (_, t) -> generalize t) vs;
  vs @ env

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

(* declared an instance of inferred: its variables rigid, constructors
 * of their own *)
let instance_of declared inferred =
  let rigid = ref [] in
  let rec go (ty : Scope.ty) =
    match ty with
    | Tvar v -> (
        match List.assoc_opt v !rigid with
        | Some t -> t
        | None -> let t = Con ({ tpath = "'" ^ v; tparams = []; tabbrev = None }, []) in rigid := (v, t) :: !rigid; t)
    | Tarrow (a, b) -> Arrow (go a, go b)
    | Ttuple ts -> Tuple (List.map go ts)
    | Tconstr (d, args) -> Con ((match Resolve.own_type d.tpath with Some d -> d | None -> d), List.map go args)
  in
  let d = go declared in
  try unify_ (instantiate inferred) d; true with Clash | Error _ -> false

let rec generalize_all t =
  match repr t with
  | Var ({ contents = Unbound (n, _) } as r) -> r := Unbound (n, generic)
  | Var _ -> ()
  | Con (_, ts) | Tuple ts -> List.iter generalize_all ts
  | Arrow (a, b) -> generalize_all a; generalize_all b

let unit_ name (items : Scope.item list) =
  Hashtbl.reset globals;
  current := name;
  level := 1;
  wanted := []; found := []; failures := []; Hashtbl.reset givens;
  let shown = ref [] in
  (* mlpp: an error kept, when the dictionaries are looked for *)
  let fail l m = if !Resolve.implicit then failures := (l, m) :: !failures else raise (Error (l, m)) in
  let item (it : Scope.item) =
    match it with
    | Ieval e -> ignore (infer [] e)
    | Iexception _ -> ()
    | Iexternal (g, p, _, ty) ->
        let t = instance ty in
        generalize_all t;
        Hashtbl.replace globals g.gsym t;
        shown := (g.gname, g.gsym, Printf.sprintf " = %S" p) :: !shown
    | Ivalue (r, bs, gs) ->
        let env = if r then letrec [] bs else let_ [] bs in
        List.iter (fun ((v : Scope.var), (g : Scope.global)) ->
          let t = List.assoc v.vid env in
          Hashtbl.replace globals g.gsym t;
          shown := (v.vname, g.gsym, "") :: !shown) gs
  in
  List.iter (fun it ->
    tvars := [];
    find_wanted (match item it with () -> false | exception Error (l, m) -> fail l m; level := 1; true)) items;
  (* the .mli's values against the inferred *)
  (match Resolve.interface () with
   | None -> ()
   | Some decls ->
       List.iter (fun (x, declared) ->
         match Hashtbl.find_opt globals (Resolve.symbol [ name ] x) with
         | None -> ()
         | Some inferred ->
             if not (instance_of declared inferred) then
               fail 0 (Printf.sprintf "the value %s: its interface's type isn't an instance of %s" x (show inferred))) decls);
  List.rev_map (fun (x, sym, prim) -> x, show (Hashtbl.find globals sym) ^ prim) !shown
