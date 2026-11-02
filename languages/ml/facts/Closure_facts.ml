(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Closure_facts.mli *)

open Scope

let out : Buffer.t = Buffer.create 4096
let unit_name : string ref = ref ""
let temps : int ref = ref 0
let calls : int ref = ref 0
let funs : int ref = ref 0
let blocks : int ref = ref 0

(* the function whose body is being read *)
let inside : string ref = ref ""

(* the exceptions' facts (lib_code/datalog/exceptions.dl): the trys
 * around the expression being read, the innermost first; a handler's
 * variable, by the try it catches for (raise e again: what came) *)
let tries : string list ref = ref []
let try_count : int ref = ref 0
let handler_vars : (int * string) list ref = ref []

let prims : (string, unit) Hashtbl.t = Hashtbl.create 64

let quote (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (fun (c : char) -> if c = '\'' || c = '\\' then Buffer.add_char b '\\'; Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

(* a fact's argument: a name, or a number (an argument's position) *)
type arg = Sym of string | Num of int

let added : (string -> arg list -> unit) ref = ref (fun (_ : string) (_ : arg list) -> ())

let fact (relation : string) (args : string list) : unit =
  Buffer.add_string out (relation ^ "(" ^ String.concat ", " (List.map quote args) ^ ").\n");
  !added relation (List.map (fun (a : string) -> Sym a) args)

(* (a number is not an atom: parameter(F, 1, P)) *)
let fact1 (relation : string) (a : string) (b : string) : unit =
  Buffer.add_string out (Printf.sprintf "%s(%s, 1, %s).\n" relation (quote a) (quote b));
  !added relation [ Sym a; Num 1; Sym b ]

(* each (variable, function) once: a variable is named at every use *)
let mentioned : (string * string, unit) Hashtbl.t = Hashtbl.create 1021

let var_in (v : string) (f : string) : unit =
  if not (Hashtbl.mem mentioned (v, f)) then begin
    Hashtbl.add mentioned (v, f) ();
    fact "var_in" [ v; f ]
  end

let here (v : string) : string =
  var_in v !inside;
  v

(* a variable no frame owns: a toplevel value, ext *)
let global (v : string) (f : string) : string =
  if not (Hashtbl.mem mentioned (v, "")) then begin
    Hashtbl.add mentioned (v, "") ();
    fact "global_var" [ v ]
  end;
  var_in v f;
  v

(* v holds a value that is no object the facts follow: a number, unit, a
 * constant constructor, what C gave. So every value has an object, and
 * a variable with none is one no run has reached: what lets an analysis
 * choose a context by an argument's object (object1.dl) *)
let scalar (v : string) : unit =
  if not (Hashtbl.mem mentioned (v, "scalar")) then begin
    Hashtbl.add mentioned (v, "scalar") ();
    fact "scalar" [ v ]
  end

(* a type's head, for the analyses to keep apart what cannot be in one
 * variable: list, Hashtbl.t, int64, -> (a function), *2 (a pair). None: a
 * type variable, or Obj.t, which Obj.magic makes of anything *)
let rec head (t : ty) : string option =
  match t with
  | Tconstr ({ tabbrev = Some a; _ }, _) -> head a
  | Tconstr (d, _) -> if d.tpath = "Obj.t" then None else Some d.tpath
  | Tarrow _ -> Some "->"
  | Ttuple ts -> Some ("*" ^ string_of_int (List.length ts))
  | Tvar _ -> None

(* v's type's head and a site's: Typing's (Typing.keep, mini-analyze's), else
 * none: then nothing is kept apart *)
let typed (relation : string) (v : string) (t : ty option) : unit =
  match Option.bind t head with
  | Some h when not (Hashtbl.mem mentioned (v, relation)) ->
      Hashtbl.add mentioned (v, relation) ();
      fact relation [ v; h ]
  | _ -> ()

let temp () : string =
  incr temps;
  here (Printf.sprintf "%s:t%d" !unit_name !temps)

let local (v : var) : string =
  let name = here (Printf.sprintf "%s:%s/%d" !unit_name v.vname v.vid) in
  typed "vtype" name (Typing.var_type v.vid);
  name

(* where a value no one reads goes *)
let junk () : string = !unit_name ^ ":_"

(* a constant's value: no fact writes it, so it points to nothing
 * (old: junk, which a condition's or a statement's value had gone to,
 * so a constant argument passed them on) *)
let constant () : string =
  let c = global (!unit_name ^ ":const") !inside in
  scalar c;
  c

(* the externals' one place: what is given to C and comes back, Obj's *)
let ext : string = "ext"

(* what raise gives and a handler catches (old: ext, with the arrays' elements:
 * what any array held, any read of one had, the set that made mini-tiger's
 * Andersen's past 12 GB; 36 s without them) *)
let exn : string = "exn"

(* an array's elements: one field of the array, each array its object *)
let elt : string = "arr:elt"

(* a block made: dst points to a place of its own, this expression's *)
let block_at (dst : string) (x : expr) : string =
  incr blocks;
  let site = Printf.sprintf "%s:block%d@%d" !unit_name !blocks x.loc in
  fact "new_block" [ dst; site ];
  fact "alloc_in" [ site; !unit_name ];
  typed "htype" site (Typing.expr_type x);
  site

let block (dst : string) (x : expr) : unit = ignore (block_at dst x)

(* An external, as a function of each of its arguments in turn
 * ('prim:name', then 'prim:name'2'...), the last returning its result.
 * One the compiler writes in place (%...) moves a value only if it is
 * one of these: the identity, a ref's and a pair's fields, an array's
 * elements (a field of the array), raise (to exn: where a handler's
 * pattern reads), Obj's fields (in ext, the one place of what is not
 * followed). A C function's result is its own, a new object of its name,
 * its arguments going nowhere, but of those that keep or call what they are
 * given (register_named_value, ml_signal, thread_new), to ext; make_vect's is
 * an array of its own, of the one site. *)
let prim (name : string) (arity : int) (t : ty) : string =
  (* its result's type, after its arguments' arrows *)
  let rec result (t : ty) (n : int) : ty = match t with Tarrow (_, r) when n > 0 -> result r (n - 1) | _ -> t in
  let stage (k : int) : string = if k = 1 then "prim:" ^ name else Printf.sprintf "prim:%s'%d" name k in
  let arg (k : int) : string = Printf.sprintf "prim:%s:arg%d" name k in
  let ret : string = "prim:" ^ name ^ ":ret" in
  let n = max arity 1 in
  if not (Hashtbl.mem prims name) then begin
    Hashtbl.add prims name ();
    for k = 1 to n do
      fact1 "parameter" (stage k) (arg k);
      var_in (arg k) (stage k);
      if k < n then begin
        fact "return" [ stage k; Printf.sprintf "prim:%s:ret%d" name k ];
        var_in (Printf.sprintf "prim:%s:ret%d" name k) (stage k);
        fact "assign_address" [ Printf.sprintf "prim:%s:ret%d" name k; stage (k + 1) ];
        fact "curried" [ stage (k + 1); stage k ]
      end
      else begin
        fact "return" [ stage k; ret ];
        var_in ret (stage k)
      end
    done;
    let kept () : unit =
      for k = 1 to n do fact "assign" [ global ext (stage k); arg k ] done;
      fact "assign" [ ret; global ext (stage n) ] in
    scalar ext;
    scalar ret;
    match name with
    | "%identity" -> fact "assign" [ ret; arg 1 ]
    (* f @@ x and x |> f: a call, of what the external was given *)
    | "%apply" | "%revapply" ->
        let f, x = if name = "%apply" then (arg 1, arg 2) else (arg 2, arg 1) in
        let i = "prim:" ^ name ^ ":call" in
        fact "in_function" [ i; stage 2 ];
        fact "call_indirect" [ i; f ];
        fact1 "argument" i x;
        fact "call_ret" [ i; ret ]
    | "%makemutable" ->
        fact "new_block" [ ret; "prim:%makemutable:block" ];
        (* (its type's head by its type, Pervasives.ref: old, "ref", that no
         * variable's was, and every ref's content was lost) *)
        typed "htype" "prim:%makemutable:block" (Some (result t arity));
        fact "assign_store_field" [ ret; "fld:contents"; arg 1 ]
    | "%field0" ->
        fact "assign_load_field" [ ret; arg 1; "fld:contents" ];
        fact "assign_load_field" [ ret; arg 1; "tuple:2.0" ]
    | "%field1" -> fact "assign_load_field" [ ret; arg 1; "tuple:2.1" ]
    | "%setfield0" -> fact "assign_store_field" [ arg 1; "fld:contents"; arg 2 ]
    | "%array_safe_get" | "%array_unsafe_get" -> fact "assign_load_field" [ ret; arg 1; elt ]
    | "%array_safe_set" | "%array_unsafe_set" -> fact "assign_store_field" [ arg 1; elt; arg 3 ]
    | "make_vect" ->
        fact "new_block" [ ret; "prim:make_vect:block" ];
        typed "htype" "prim:make_vect:block" (Some (result t arity));
        fact "assign_store_field" [ ret; elt; arg 2 ]
    | "%raise" -> fact "assign" [ global exn (stage 1); arg 1 ]
    | "%obj_field" | "%obj_set_field" -> kept ()
    (* what C keeps, or calls: a handler, a thread's function, a callback's *)
    | "register_named_value" | "ml_signal" | "thread_new" -> kept ()
    (* another C function: what it returns is its own, a number or new, and
     * what it is given stays (compare's and hash's: any value at all); old:
     * kept (), so that every C call returned all any had been given *)
    | _ ->
        if name = "" || name.[0] <> '%' then begin
          fact "new_block" [ ret; "prim:" ^ name ^ ":block" ];
          typed "htype" ("prim:" ^ name ^ ":block") (Some (result t arity))
        end
  end;
  stage 1

let rec plain (p : pattern) : var option =
  match p with
  | Pvar v -> Some v
  | Pconstraint (p, _) -> plain p
  | _ -> None

(* a parameter that is a capability: of an object's type, written or found by
 * Typing (Typing.keep, mini-analyze's), or named so where nothing says more:
 * let argv _caps = ... has any type. (old: the name alone, and Regex's caps, its
 * groups' places, an array, was one: capabilities_types.dl's handed_unknown) *)
let rec is_object (t : ty) : bool =
  match t with
  | Tconstr ({ tabbrev = Some t; _ }, _) -> is_object t
  | Tconstr (d, _) -> d.tpath = "< .. >"
  | _ -> false

let rec takes_capability (p : pattern) : bool =
  match p with
  | Pconstraint (p, t) -> is_object t || takes_capability p
  | Pvar v -> (
      let named = v.vname = "caps" || v.vname = "_caps" in
      match Typing.var_type v.vid with
      | None | Some (Tvar _) -> named
      | Some t -> is_object t)
  | _ -> false

let rec declared (p : pattern) : string list =
  match p with
  | Pconstraint (p, t) -> Resolve.capabilities t @ declared p
  | _ -> []

let rec is_function (x : expr) : bool =
  match x.e with
  | Efunction _ -> true
  | Econstraint (e, _) -> is_function e
  | _ -> false

(* the pattern's variables, from the value in src *)
let rec bind (p : pattern) (src : string) : unit =
  let part (field : string) (p : pattern) : unit =
    match p with
    | Pany | Pconst _ | Prange _ -> ()
    | _ ->
        let t = match plain p with Some v -> local v | None -> temp () in
        fact "assign_load_field" [ t; src; field ];
        if plain p = None then bind p t in
  match p with
  | Pany | Pconst _ | Prange _ -> ()
  | Pvar v -> fact "assign" [ local v; src ]
  | Palias (p, v) -> fact "assign" [ local v; src ]; bind p src
  | Pconstraint (p, _) -> bind p src
  | Por (p, q) -> bind p src; bind q src
  | Ptuple ps ->
      let n = List.length ps in
      List.iteri (fun (k : int) (p : pattern) -> part (Printf.sprintf "tuple:%d.%d" n k) p) ps
  | Pcons (c, ps) -> List.iteri (fun (k : int) (p : pattern) -> part (Printf.sprintf "con:%s.%d" c.cname k) p) ps
  | Precord fields -> List.iter (fun ((l, p) : label * pattern) -> part ("fld:" ^ l.lname) p) fields

(* a call's or a raise's site: in which try *)
let site_in (s : string) : unit = match !tries with t :: _ -> fact "in_try" [ s; t ] | [] -> ()

(* e's value goes to the variable dst; name: what a function written
 * here is called (the variable it is bound to) *)
let rec flow (name : string option) (x : expr) (dst : string) : unit =
  let stores (fields : (string * expr) list) : unit =
    List.iter (fun ((field, e) : string * expr) -> fact "assign_store_field" [ dst; field; operand e ]) fields in
  match x.e with
  | Econst _ -> scalar dst
  | Evar (Local v) -> fact "assign" [ dst; local v ]
  | Evar (Global g) -> fact "assign" [ dst; global g.gsym !inside ]; typed "vtype" g.gsym g.gtype
  | Evar (Prim (p, arity, t)) -> fact "assign_address" [ dst; prim p arity t ]
  | Econstraint (e, _) -> flow name e dst
  | Efunction cases ->
      let f : string =
        match name with
        | Some n -> n
        | None -> incr funs; Printf.sprintf "%s:fun%d@%d" !unit_name !funs x.loc in
      fact "closure" [ f; !unit_name; string_of_int x.loc ];
      fact "alloc_in" [ f; !unit_name ];
      fact "htype" [ f; "->" ];
      (match Typing.expr_type x with
       | Some (Tarrow (a, r)) -> typed "vtype" (f ^ ":arg") (Some a); typed "vtype" (f ^ ":ret") (Some r)
       | _ -> ());
      fact "assign_address" [ dst; f ];
      fact1 "parameter" f (f ^ ":arg");
      fact "return" [ f; f ^ ":ret" ];
      var_in (f ^ ":arg") f;
      var_in (f ^ ":ret") f;
      if List.exists (fun ((p, _, _) : case) -> takes_capability p) cases then fact "takes_cap" [ f ];
      List.iter
        (fun ((p, _, _) : case) -> List.iter (fun (c : string) -> fact "declares" [ f; c ]) (declared p))
        cases;
      let outer = !inside in
      inside := f;
      (* let f x y = ...: the function of y is f' *)
      let inner : string option =
        match cases with
        | [ (_, _, body) ] when is_function body ->
            fact "inner" [ f ^ "'"; f ];
            fact "curried" [ f ^ "'"; f ];
            Some (f ^ "'")
        | _ -> None in
      List.iter
        (fun ((p, guard, body) : case) ->
          bind p (f ^ ":arg");
          Option.iter (fun (g : expr) -> flow None g (junk ())) guard;
          flow inner body (f ^ ":ret"))
        cases;
      inside := outer
  | Eapply (({ e = Evar (Prim ("%raise", _, _)); _ } as f), [ a ]) ->
      (* (a raise: its site, its call's, the exception's constructor
       * when it is written, a handler's variable raised again; else
       * what its argument points to, an exception's block) *)
      let r = Printf.sprintf "%s:%d:c%d" !unit_name x.loc (!calls + 1) in
      fact "raise_in" [ r; !inside ];
      site_in r;
      let rec what (a : expr) : unit =
        match a.e with
        | Econstraint (a, _) -> what a
        | Econs ({ kind = Exn g; _ }, _) -> fact "raise_of" [ r; g.gsym ]
        | Evar (Local v) when List.mem_assoc v.vid !handler_vars ->
            fact "reraises" [ r; List.assoc v.vid !handler_vars ]
        | _ -> () in
      what a;
      call x f [ a ] dst
  | Eapply (f, args) -> call x f args dst
  | Elet (_, bindings, body) -> lets bindings []; flow name body dst
  | Ematch (e, cases) ->
      let v = operand e in
      List.iter
        (fun ((p, guard, body) : case) ->
          bind p v;
          Option.iter (fun (g : expr) -> flow None g (junk ())) guard;
          flow None body dst)
        cases
  | Etry (e, cases) ->
      (* (a try: in which function, in which try; what it catches, a
       * case with a guard nothing for sure) *)
      incr try_count;
      let t = Printf.sprintf "%s:try%d@%d" !unit_name !try_count x.loc in
      fact "try_in_function" [ t; !inside ];
      (match !tries with t2 :: _ -> fact "try_in_try" [ t; t2 ] | [] -> ());
      let outer = !tries in
      tries := t :: outer;
      flow None e dst;
      tries := outer;
      let rec catches (p : pattern) : unit =
        match p with
        | Pcons ({ kind = Exn g; _ }, _) -> fact "catches" [ t; g.gsym ]
        | Por (p, q) -> catches p; catches q
        | Palias (p, v) -> handler_vars := (v.vid, t) :: !handler_vars; catches p
        | Pconstraint (p, _) -> catches p
        | Pvar v -> handler_vars := (v.vid, t) :: !handler_vars; fact "catches_all" [ t ]
        | Pany -> fact "catches_all" [ t ]
        | _ -> () in
      List.iter
        (fun ((p, guard, body) : case) ->
          (match guard with None -> catches p | Some _ -> ());
          bind p (global exn !inside);
          Option.iter (fun (g : expr) -> flow None g (junk ())) guard;
          flow None body dst)
        cases
  | Etuple es ->
      let n = List.length es in
      block dst x;
      stores (List.mapi (fun (k : int) (e : expr) -> (Printf.sprintf "tuple:%d.%d" n k, e)) es)
  | Econs (({ kind = Exn g; _ } as c), es) ->
      (* (an exception a block even without arguments: what a raise
       * of a variable raises) *)
      fact "exn_block" [ block_at dst x; g.gsym ];
      stores (List.mapi (fun (k : int) (e : expr) -> (Printf.sprintf "con:%s.%d" c.cname k, e)) es)
  | Econs (_, []) -> scalar dst
  | Econs (c, es) ->
      block dst x;
      stores (List.mapi (fun (k : int) (e : expr) -> (Printf.sprintf "con:%s.%d" c.cname k, e)) es)
  | Erecord (_, fields) ->
      block dst x;
      stores (List.map (fun ((l, e) : label * expr) -> ("fld:" ^ l.lname, e)) fields)
  | Ewith (e, _, fields) ->
      flow None e dst;
      stores (List.map (fun ((l, e) : label * expr) -> ("fld:" ^ l.lname, e)) fields)
  | Efield (e, l) -> fact "assign_load_field" [ dst; operand e; "fld:" ^ l.lname ]
  | Esetfield (e, l, v) ->
      scalar dst;
      fact "assign_store_field" [ operand e; "fld:" ^ l.lname; operand v ]
  | Earray es ->
      block dst x;
      List.iter (fun (e : expr) -> fact "assign_store_field" [ dst; elt; operand e ]) es
  | Eif (c, a, b) ->
      flow None c (junk ());
      flow None a dst;
      (match b with Some b -> flow None b dst | None -> scalar dst)
  | Eseq (a, b) -> flow None a (junk ()); flow name b dst
  | Ewhile (c, body) -> scalar dst; flow None c (junk ()); flow None body (junk ())
  | Efor (_, lo, hi, _, body) -> scalar dst; flow None lo (junk ()); flow None hi (junk ()); flow None body (junk ())
  | Eassert e -> scalar dst; flow None e (junk ())

(* f a1 ... an: a call for each argument, of what the one before returned *)
and call (x : expr) (f : expr) (args : expr list) (dst : string) : unit =
  let n = List.length args in
  let fn = ref (operand f) in
  List.iteri
    (fun (k : int) (a : expr) ->
      incr calls;
      let i = Printf.sprintf "%s:%d:c%d" !unit_name x.loc !calls in
      let result = if k = n - 1 then dst else temp () in
      fact "in_function" [ i; !inside ];
      site_in i;
      fact "call_indirect" [ i; !fn ];
      fact1 "argument" i (operand a);
      fact "call_ret" [ i; result ];
      fn := result)
    args

(* the variable e's value is in: its own if it is one, or a new one *)
and operand (x : expr) : string =
  match x.e with
  | Evar (Local v) -> local v
  | Evar (Global g) -> typed "vtype" g.gsym g.gtype; global g.gsym !inside
  | Econstraint (e, _) -> operand e
  | Econst _ -> constant ()
  | _ ->
      let t = temp () in
      typed "vtype" t (Typing.expr_type x);
      flow None x t;
      t

(* a let's bindings; exported: the toplevel's variables and their globals *)
and lets (bindings : (pattern * expr) list) (exported : (var * global) list) : unit =
  List.iter
    (fun ((p, e) : pattern * expr) ->
      match plain p with
      | Some v ->
          let name : string = match List.assq_opt v exported with Some g -> g.gsym | None -> local v in
          flow (Some name) e (local v)
      | None -> bind p (operand e))
    bindings

let unit_ (name : string) (items : item list) : string =
  Buffer.clear out;
  Hashtbl.reset prims;
  Hashtbl.reset mentioned;
  unit_name := name;
  temps := 0;
  calls := 0;
  try_count := 0;
  tries := [];
  handler_vars := [];
  funs := 0;
  blocks := 0;
  inside := name ^ ":init";
  fact "init" [ name ^ ":init" ];
  List.iter
    (fun (item : item) ->
      match item with
      | Ieval e -> flow None e (junk ())
      | Ivalue (_, bindings, exported) ->
          lets bindings exported;
          List.iter
            (fun ((v, g) : var * global) ->
              fact "global_def" [ g.gsym; !inside ];
              fact "assign" [ global g.gsym !inside; local v ])
            exported
      | Iexception _ -> ()
      | Iexternal (g, p, arity, t) -> fact "assign_address" [ global g.gsym !inside; prim p arity t ])
    items;
  Buffer.contents out
