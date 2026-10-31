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

let temp () : string =
  incr temps;
  here (Printf.sprintf "%s:t%d" !unit_name !temps)

let local (v : var) : string = here (Printf.sprintf "%s:%s/%d" !unit_name v.vname v.vid)

(* where a value no one reads goes *)
let junk () : string = !unit_name ^ ":_"

(* a constant's value: no fact writes it, so it points to nothing
 * (old: junk, which a condition's or a statement's value had gone to,
 * so a constant argument passed them on) *)
let constant () : string =
  let c = global (!unit_name ^ ":const") !inside in
  scalar c;
  c

(* the externals' one place *)
let ext : string = "ext"

(* a block made: dst points to a place of its own, this expression's *)
let block (dst : string) (loc : int) : unit =
  incr blocks;
  let site = Printf.sprintf "%s:block%d@%d" !unit_name !blocks loc in
  fact "new_block" [ dst; site ];
  fact "alloc_in" [ site; !unit_name ]

(* An external, as a function of each of its arguments in turn
 * ('prim:name', then 'prim:name'2'...), the last returning its result.
 * One the compiler writes in place (%...) moves a value only if it is
 * one of these: the identity, a ref's and a pair's fields, an array's
 * and a block's elements (in ext, the one place of what is not
 * followed), raise (to ext: where a handler's pattern reads). A C
 * function's arguments go to ext and its result comes from it. *)
let prim (name : string) (arity : int) : string =
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
        fact "assign_store_field" [ ret; "fld:contents"; arg 1 ]
    | "%field0" ->
        fact "assign_load_field" [ ret; arg 1; "fld:contents" ];
        fact "assign_load_field" [ ret; arg 1; "tuple:2.0" ]
    | "%field1" -> fact "assign_load_field" [ ret; arg 1; "tuple:2.1" ]
    | "%setfield0" -> fact "assign_store_field" [ arg 1; "fld:contents"; arg 2 ]
    | "%raise" | "%array_safe_get" | "%array_safe_set" | "%array_unsafe_get" | "%array_unsafe_set" | "%obj_field" | "%obj_set_field" -> kept ()
    | _ -> if name = "" || name.[0] <> '%' then kept ()
  end;
  stage 1

let rec plain (p : pattern) : var option =
  match p with
  | Pvar v -> Some v
  | Pconstraint (p, _) -> plain p
  | _ -> None

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

(* e's value goes to the variable dst; name: what a function written
 * here is called (the variable it is bound to) *)
let rec flow (name : string option) (x : expr) (dst : string) : unit =
  let stores (fields : (string * expr) list) : unit =
    List.iter (fun ((field, e) : string * expr) -> fact "assign_store_field" [ dst; field; operand e ]) fields in
  match x.e with
  | Econst _ -> scalar dst
  | Evar (Local v) -> fact "assign" [ dst; local v ]
  | Evar (Global g) -> fact "assign" [ dst; global g.gsym !inside ]
  | Evar (Prim (p, arity, _)) -> fact "assign_address" [ dst; prim p arity ]
  | Econstraint (e, _) -> flow name e dst
  | Efunction cases ->
      let f : string =
        match name with
        | Some n -> n
        | None -> incr funs; Printf.sprintf "%s:fun%d@%d" !unit_name !funs x.loc in
      fact "closure" [ f; !unit_name; string_of_int x.loc ];
      fact "alloc_in" [ f; !unit_name ];
      fact "assign_address" [ dst; f ];
      fact1 "parameter" f (f ^ ":arg");
      fact "return" [ f; f ^ ":ret" ];
      var_in (f ^ ":arg") f;
      var_in (f ^ ":ret") f;
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
  | Eapply (f, args) ->
      let n = List.length args in
      let fn = ref (operand f) in
      List.iteri
        (fun (k : int) (a : expr) ->
          incr calls;
          let i = Printf.sprintf "%s:%d:c%d" !unit_name x.loc !calls in
          let result = if k = n - 1 then dst else temp () in
          fact "in_function" [ i; !inside ];
          fact "call_indirect" [ i; !fn ];
          fact1 "argument" i (operand a);
          fact "call_ret" [ i; result ];
          fn := result)
        args
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
      flow None e dst;
      List.iter
        (fun ((p, guard, body) : case) ->
          bind p (global ext !inside);
          Option.iter (fun (g : expr) -> flow None g (junk ())) guard;
          flow None body dst)
        cases
  | Etuple es ->
      let n = List.length es in
      block dst x.loc;
      stores (List.mapi (fun (k : int) (e : expr) -> (Printf.sprintf "tuple:%d.%d" n k, e)) es)
  | Econs (_, []) -> scalar dst
  | Econs (c, es) ->
      block dst x.loc;
      stores (List.mapi (fun (k : int) (e : expr) -> (Printf.sprintf "con:%s.%d" c.cname k, e)) es)
  | Erecord (_, fields) ->
      block dst x.loc;
      stores (List.map (fun ((l, e) : label * expr) -> ("fld:" ^ l.lname, e)) fields)
  | Ewith (e, _, fields) ->
      flow None e dst;
      stores (List.map (fun ((l, e) : label * expr) -> ("fld:" ^ l.lname, e)) fields)
  | Efield (e, l) -> fact "assign_load_field" [ dst; operand e; "fld:" ^ l.lname ]
  | Esetfield (e, l, v) ->
      scalar dst;
      fact "assign_store_field" [ operand e; "fld:" ^ l.lname; operand v ]
  | Earray es ->
      scalar dst;
      List.iter (fun (e : expr) -> fact "assign" [ global ext !inside; operand e ]) es
  | Eif (c, a, b) ->
      flow None c (junk ());
      flow None a dst;
      (match b with Some b -> flow None b dst | None -> scalar dst)
  | Eseq (a, b) -> flow None a (junk ()); flow name b dst
  | Ewhile (c, body) -> scalar dst; flow None c (junk ()); flow None body (junk ())
  | Efor (_, lo, hi, _, body) -> scalar dst; flow None lo (junk ()); flow None hi (junk ()); flow None body (junk ())
  | Eassert e -> scalar dst; flow None e (junk ())

(* the variable e's value is in: its own if it is one, or a new one *)
and operand (x : expr) : string =
  match x.e with
  | Evar (Local v) -> local v
  | Evar (Global g) -> global g.gsym !inside
  | Econstraint (e, _) -> operand e
  | Econst _ -> constant ()
  | _ ->
      let t = temp () in
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
      | Iexternal (g, p, arity, _) -> fact "assign_address" [ global g.gsym !inside; prim p arity ])
    items;
  Buffer.contents out
