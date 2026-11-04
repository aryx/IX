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

(* the exceptions' facts (analyzers/datalog/exceptions.dl): the trys
 * around the expression being read, the innermost first; a handler's
 * variable, by the try it catches for (raise e again: what came) *)
let tries : string list ref = ref []
(* the trys whose handler is being read, the innermost first *)
let handlers : string list ref = ref []
let try_count : int ref = ref 0
let handler_vars : (int * string) list ref = ref []

(* in the branch of an if Sys.int_size >= 63: bugs/intwidth.dl's *)
let in_wide : bool ref = ref false
(* in a while's condition or body, in this function: bugs/races.dl's *)
let in_loop : bool ref = ref false

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

(* a type the analyses may compare by its name: built in, an object's, or
 * one with constructors or fields. Not one abstract here and defined by
 * an abbreviation (Tui_turbo.mli's type model, Turbo_model.model inside):
 * its two names would keep apart what is one (mini-turbopascal's program
 * record lost, 183 functions dead) *)
let known (d : tdecl) : bool =
  List.mem d.tpath
    [ "int"; "char"; "string"; "bytes"; "float"; "bool"; "unit"; "exn"; "array";
      "list"; "int32"; "int64"; "nativeint"; "format"; "format4"; "< .. >" ]
  || (match Resolve.type_conses d with Some _ -> true | None -> false)
  || (match Resolve.type_fields d with Some _ -> true | None -> false)

(* a type's head, for the analyses to keep apart what cannot be in one
 * variable: list, Hashtbl.t, int64, -> (a function), *2 (a pair). None: a
 * type variable, Obj.t, which Obj.magic makes of anything, a type not known *)
let rec head (t : ty) : string option =
  match t with
  | Tconstr ({ tabbrev = Some a; _ }, _) -> head a
  | Tconstr (d, _) -> if d.tpath = "Obj.t" || not (known d) then None else Some d.tpath
  | Tarrow _ -> Some "->"
  | Ttuple ts -> Some ("*" ^ string_of_int (List.length ts))
  | Tvar _ -> None

(* a type's parameters replaced by its arguments, for an abbreviation's body *)
let rec subst (by : (string * ty) list) (t : ty) : ty =
  match t with
  | Tvar a -> (match List.assoc_opt a by with Some u -> u | None -> t)
  | Tarrow (a, r) -> Tarrow (subst by a, subst by r)
  | Ttuple ts -> Ttuple (List.map (subst by) ts)
  | Tconstr (d, ts) -> Tconstr (d, List.map (subst by) ts)

(* a type whole, when it has no type variable (int list, not 'a list): two
 * lists of other elements are kept apart too, which their head cannot do.
 * None: a variable in it, Obj.t, an object, a type not known *)
let rec full (t : ty) : string option =
  let all (ts : ty list) : string list option =
    List.fold_right (fun t acc ->
      match full t, acc with Some s, Some l -> Some (s :: l) | _ -> None)
      ts (Some [])
  in
  match t with
  | Tconstr ({ tabbrev = Some a; tparams; _ }, ts)
    when List.length tparams = List.length ts ->
      full (subst (List.combine tparams ts) a)
  | Tconstr ({ tabbrev = Some _; _ }, _) -> None
  (* (an object's type is open: < Cap.stdout; .. > holds a bigger one) *)
  | Tconstr ({ tpath = "< .. >"; _ }, _) -> None
  | Tconstr (d, _) when not (known d) -> None
  | Tconstr (d, []) -> if d.tpath = "Obj.t" then None else Some d.tpath
  | Tconstr (d, [ t ]) -> Option.map (fun s -> s ^ " " ^ d.tpath) (full t)
  | Tconstr (d, ts) ->
      Option.map (fun l -> "(" ^ String.concat ", " l ^ ") " ^ d.tpath) (all ts)
  | Tarrow (a, r) ->
      Option.map (fun l -> "(" ^ String.concat " -> " l ^ ")") (all [ a; r ])
  | Ttuple ts ->
      Option.map (fun l -> "(" ^ String.concat " * " l ^ ")") (all ts)
  | Tvar _ -> None

(* v's type's head and a site's (vtype, htype), and its whole type when it has
 * no variable (vfull, hfull): Typing's (Typing.keep, mini-analyze's), else
 * none: then nothing is kept apart *)
(* a variant shaped as a list, for bugs/stack.dl: a constructor holds one
 * value of the type itself, and none two (a tree's): Hashtbl's buckets
 * (Cons of 'a * 'b * bucketlist), walked by a call an element *)
let list_like (t : ty) : unit =
  match t with
  | Tconstr (d, _) when not (Hashtbl.mem mentioned (d.tpath, "list_like")) ->
      Hashtbl.add mentioned (d.tpath, "list_like") ();
      let selves (c : cons) : int =
        let _, args, _ = c.ctype in
        List.length (List.filter (fun (a : ty) -> match a with Tconstr (d2, _) -> d2.tpath = d.tpath | _ -> false) args) in
      (match Resolve.type_conses d with
       | Some cs ->
           let n = List.map (fun ((_, c) : string * cons) -> selves c) cs in
           if List.mem 1 n && List.for_all (fun k -> k <= 1) n then fact "list_like" [ d.tpath ]
       | None -> ())
  | _ -> ()

let typed (relation : string) (v : string) (t : ty option) : unit =
  match t with
  | Some t when not (Hashtbl.mem mentioned (v, relation)) ->
      Hashtbl.add mentioned (v, relation) ();
      (match head t with Some h -> fact relation [ v; h ] | None -> ());
      if relation = "vtype" then list_like t;
      (match head t, full t with
       | Some _, Some f -> fact (String.sub relation 0 1 ^ "full") [ v; f ]
       | _ -> ())
  | _ -> ()

let temp () : string =
  incr temps;
  here (Printf.sprintf "%s:t%d" !unit_name !temps)

let local (v : var) : string =
  let name = here (Printf.sprintf "%s:%s/%d" !unit_name v.vname v.vid) in
  typed "vtype" name (Typing.var_type v.vid);
  name

(* a variable read, its value used (said once): dead.dl's unused_param *)
let reads : (string, unit) Hashtbl.t = Hashtbl.create 256
let read (v : var) : string =
  let n = local v in
  if not (Hashtbl.mem reads n) then begin
    Hashtbl.add reads n ();
    fact "read" [ n ]
  end;
  n

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

(* what was made an Obj.t (Obj.repr f), that no one reads: a function there
 * may be called from where the facts do not go (contexts.dl's callback).
 * Not ext, which is read: Printf's closures, Obj.magic'd, would come back
 * from every C call *)
let raw : string = "raw"

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
(* an external's result's type, after its arguments' arrows *)
let rec result (t : ty) (n : int) : ty = match t with Tarrow (_, r) when n > 0 -> result r (n - 1) | _ -> t

(* what an external does, its arguments arg 1 ... arg n, its result ret of
 * type res, in the functions inside k (the k-th argument's); its objects
 * named after site, made in the unit place if one *)
let prim_body (name : string) (arity : int) (res : ty) ~(arg : int -> string)
    ~(ret : string) ~(inside : int -> string) ~(site : string) ~(place : string option) : unit =
  let n = max arity 1 in
  let kept () : unit =
    for k = 1 to n do fact "assign" [ global ext (inside k); arg k ] done;
    fact "assign" [ ret; global ext (inside n) ] in
  let new_block (what : string) : string =
    let b = site ^ ":" ^ what in
    fact "new_block" [ ret; b ];
    typed "htype" b (Some res);
    Option.iter (fun u -> fact "alloc_in" [ b; u ]) place;
    b in
  scalar ext;
  scalar ret;
  match name with
  | "%identity" ->
      fact "assign" [ ret; arg 1 ];
      (* (made an Obj.t, Obj.repr f: it may leave for what is not followed,
       * mini-dotnet's JIT calling its call-outs by their address) *)
      (match res with
       | Tconstr ({ tpath = "Obj.t"; _ }, _) -> fact "assign" [ global raw (inside 1); arg 1 ]
       | _ -> ())
  (* f @@ x and x |> f: a call, of what the external was given *)
  | "%apply" | "%revapply" ->
      let f, x = if name = "%apply" then (arg 1, arg 2) else (arg 2, arg 1) in
      let i = site ^ ":call" in
      fact "in_function" [ i; inside 2 ];
      fact "call_indirect" [ i; f ];
      fact1 "argument" i x;
      if ret <> junk () then fact "call_ret" [ i; ret ]
  | "%makemutable" ->
      (* (its type's head by its type, Pervasives.ref: old, "ref", that no
       * variable's was, and every ref's content was lost) *)
      ignore (new_block "block");
      fact "assign_store_field" [ ret; "fld:contents"; arg 1 ]
  | "%field0" ->
      fact "assign_load_field" [ ret; arg 1; "fld:contents" ];
      fact "assign_load_field" [ ret; arg 1; "tuple:2.0" ]
  | "%field1" -> fact "assign_load_field" [ ret; arg 1; "tuple:2.1" ]
  | "%setfield0" ->
      fact "assign_store_field" [ arg 1; "fld:contents"; arg 2 ];
      fact "store_in" [ arg 1; "fld:contents"; arg 2; inside 2 ]
  | "%array_safe_get" | "%array_unsafe_get" -> fact "assign_load_field" [ ret; arg 1; elt ]
  | "%array_safe_set" | "%array_unsafe_set" ->
      fact "assign_store_field" [ arg 1; elt; arg 3 ];
      fact "store_in" [ arg 1; elt; arg 3; inside 3 ]
  | "make_vect" ->
      ignore (new_block "block");
      fact "assign_store_field" [ ret; elt; arg 2 ]
  | "%raise" -> fact "assign" [ global exn (inside 1); arg 1 ]
  | "%obj_field" | "%obj_set_field" -> kept ()
  (* what C keeps, or calls: a handler, a thread's function, a callback's *)
  | "register_named_value" | "ml_signal" | "thread_new" -> kept ()
  (* another C function: what it returns is its own, a number or new, and
   * what it is given stays (compare's and hash's: any value at all); old:
   * kept (), so that every C call returned all any had been given *)
  | _ -> if name = "" || name.[0] <> '%' then ignore (new_block "block")

(* a function of n arguments in turn, named f: f, f'2 ... f'n, the k-th's
 * argument f:argk, the last's result f:ret *)
let stage (f : string) (k : int) : string =
  if k = 1 then f else Printf.sprintf "%s'%d" f k
let stage_arg (f : string) (k : int) : string = Printf.sprintf "%s:arg%d" f k

let chain (f : string) (n : int) : unit =
  let ret = f ^ ":ret" in
  for k = 1 to n do
    (* (a function, as a closure is: without it, a primitive given as a
     * value, (-.), passed every filter, mini-cc's 25 a list's cells) *)
    fact "htype" [ stage f k; "->" ];
    fact1 "parameter" (stage f k) (stage_arg f k);
    var_in (stage_arg f k) (stage f k);
    if k < n then begin
      let r = Printf.sprintf "%s:ret%d" f k in
      fact "return" [ stage f k; r ];
      var_in r (stage f k);
      fact "assign_address" [ r; stage f (k + 1) ];
      fact "curried" [ stage f (k + 1); stage f k ]
    end
    else begin
      fact "return" [ stage f k; ret ];
      var_in ret (stage f k)
    end
  done

(* An external, as a function of each of its arguments in turn
 * ('prim:name', then 'prim:name'2'...), the last returning its result.
 * One the compiler writes in place (%...) moves a value only if it is
 * one of these: the identity, a ref's and a pair's fields, an array's
 * elements (a field of the array), raise (to exn: where a handler's
 * pattern reads), Obj's fields (in ext, the one place of what is not
 * followed). A C function's result is its own, a new object of its name,
 * its arguments going nowhere, but of those that keep or call what they are
 * given (register_named_value, ml_signal, thread_new), to ext; make_vect's is
 * an array of its own, of the one site. This one is the external as a
 * value, (-.) given to a fold; a call of all its arguments has its own
 * copy (call's, prim_body at the site). *)
let prim (name : string) (arity : int) (t : ty) : string =
  let f = "prim:" ^ name in
  if not (Hashtbl.mem prims name) then begin
    Hashtbl.add prims name ();
    chain f (max arity 1);
    prim_body name arity (result t arity) ~arg:(stage_arg f) ~ret:(f ^ ":ret")
      ~inside:(stage f) ~site:f ~place:None
  end;
  f

(* what a library's container does (Models): its arguments arg 1 ..., its
 * result ret, of type res, its own variables and its calls in the function
 * inside, its sites named after site; the sites of its calls and raises *)
let model_body (sym : string) (ops : Models.op list) ~(arg : int -> string)
    ~(ret : string) ~(inside : string) ~(site : string) ~(place : string option)
    (res : ty option) : string list =
  let own (s : string) : string = var_in s inside; s in
  (* (a result no one reads goes nowhere: see call) *)
  let ret = if ret = junk () then own (site ^ ":ret") else ret in
  let var (v : Models.v) : string =
    match v with
    | Arg k -> arg k
    | Ret -> ret
    | Tmp k -> own (Printf.sprintf "%s:m%d" site k) in
  let calls = ref 0 and news = ref 0 in
  (* (what the model walks, in order: a list's cells, c = c.tl after
   * c = l, or a table's bindings; bugs/order.dl's) *)
  let rec walked (ops : Models.op list) : unit =
    match ops with
    | Assign (Tmp j, (Arg _ as a)) :: (Load (Tmp j', Tmp j'', f) :: _ as rest)
      when j = j' && j = j'' && f = "con:::.1" ->
        fact "walked" [ site; sym; var a ]; walked rest
    | Load (_, (Arg _ as a), f) :: rest when f = "tbl:key" ->
        fact "walked" [ site; sym; var a ]; walked rest
    | _ :: rest -> walked rest
    | [] -> () in
  walked ops;
  List.concat_map
    (fun (op : Models.op) ->
      match op with
      | New v ->
          incr news;
          let b =
            if !news = 1 then site ^ ":block"
            else Printf.sprintf "%s:block%d" site !news in
          fact "new_block" [ var v; b ];
          fact "model_new" [ site; b ];
          (* (of the result's type; another's is not known: no filter) *)
          if v = Ret then typed "htype" b res;
          Option.iter (fun (u : string) -> fact "alloc_in" [ b; u ]) place;
          []
      | Load (d, o, f) -> fact "assign_load_field" [ var d; var o; f ]; []
      | Store (o, f, s) ->
          fact "assign_store_field" [ var o; f; var s ];
          (* (a block the model made is being given its fields) *)
          if not (List.mem (Models.New o) ops) then
            fact "store_in" [ var o; f; var s; inside ];
          []
      | Assign (d, s) -> fact "assign" [ var d; var s ]; []
      | Scalar v -> scalar (var v); []
      | Call (d, f, a) ->
          incr calls;
          let i = Printf.sprintf "%s:call%d" site !calls in
          fact "in_function" [ i; inside ];
          fact "call_indirect" [ i; var f ];
          fact1 "argument" i (var a);
          fact "call_ret" [ i; var d ];
          (* (the library's call: bugs/stack.dl does not follow it, as it
           * did not follow List.map's own, in another unit) *)
          fact "model_call" [ i; sym ];
          fact "walk_call" [ i; site ];
          [ i ]
      | Raise e ->
          let i = site ^ ":raise" in
          fact "raise_in" [ i; inside ];
          fact "in_function" [ i; inside ];
          fact "raise_of" [ i; e ];
          [ i ])
    ops

(* a modeled global as a value, its own function: model:Hashtbl.find *)
let model_fun (sym : string) (n : int) (ops : Models.op list) (t : ty option) :
    string =
  let f = "model:" ^ sym in
  chain f n;
  let res = Option.map (fun (t : ty) -> result t n) t in
  ignore
    (model_body sym ops ~arg:(stage_arg f) ~ret:(f ^ ":ret") ~inside:(stage f n)
       ~site:f ~place:None res);
  f

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

(* the capabilities a record keeps in its fields, Eval.t's caps, and in its
 * fields' records (seen: the records gone into, a type of itself) *)
let rec field_caps (seen : string list) (t : ty) : string list =
  match t with
  | Tconstr ({ tabbrev = Some a; _ }, _) -> field_caps seen a
  | Tconstr (d, _) when not (List.mem d.tpath seen) -> (
      match Resolve.type_fields d with
      | None -> []
      | Some fields ->
          List.concat_map
            (fun ((_, l) : string * label) ->
              let _, ft, _ = l.ltype in
              if is_object ft then Resolve.capabilities ft else field_caps (d.tpath :: seen) ft)
            fields)
  | _ -> []

let rec held_in_fields (p : pattern) : string list =
  match p with
  | Pconstraint (p, t) -> field_caps [] t @ held_in_fields p
  | Pvar v -> (match Typing.var_type v.vid with Some t -> field_caps [] t | None -> [])
  | _ -> []

let rec is_function (x : expr) : bool =
  match x.e with
  | Efunction _ -> true
  | Econstraint (e, _) -> is_function e
  | _ -> false

(* the pattern's variables, from the value in src *)
(* a local variable bound, in the function being read, _ before its
 * name saying "not read, meant": bugs/unused.dl's (OCaml's warnings 26
 * and 27, by rules) *)
let exported_pattern : bool ref = ref false
let bound (v : var) : unit =
  let n = local v in
  if not !exported_pattern then begin
    fact "bound_var" [ !inside; n ];
    if v.vname <> "" && v.vname.[0] = '_' then fact "underscore" [ n ]
  end

let rec bind (p : pattern) (src : string) : unit =
  let part (field : string) (p : pattern) : unit =
    match p with
    | Pany | Pconst _ | Prange _ -> ()
    | _ ->
        let t = match plain p with Some v -> bound v; local v | None -> temp () in
        fact "assign_load_field" [ t; src; field ];
        if plain p = None then bind p t in
  match p with
  | Pany | Pconst _ | Prange _ -> ()
  | Pvar v -> bound v; fact "assign" [ local v; src ]
  | Palias (p, v) -> bound v; fact "assign" [ local v; src ]; bind p src
  | Pconstraint (p, _) -> bind p src
  | Por (p, q) -> bind p src; bind q src
  | Ptuple ps ->
      let n = List.length ps in
      List.iteri (fun (k : int) (p : pattern) -> part (Printf.sprintf "tuple:%d.%d" n k) p) ps
  | Pcons (c, ps) -> List.iteri (fun (k : int) (p : pattern) -> part (Printf.sprintf "con:%s.%d" c.cname k) p) ps
  | Precord fields -> List.iter (fun ((l, p) : label * pattern) -> part ("fld:" ^ l.lname) p) fields

(* a call's or a raise's site: in which try *)
let site_in (s : string) : unit =
  (match !tries with t :: _ -> fact "in_try" [ s; t ] | [] -> ());
  if !in_wide then fact "wide_site" [ s ];
  if !in_loop then fact "loop_site" [ s ]

(* a call's place, for bugs/stack.dl: in a handler (no tail call by mini-ml,
 * whose try is a function of its own); a tail call, its result the
 * function's, outside any try; or one but for a try around it *)
let position (i : string) (result : string) : unit =
  (match !handlers with t :: _ -> fact "in_handler" [ i; t ] | [] -> ());
  if result = !inside ^ ":ret" then
    if !tries = [] && !handlers = [] then fact "tail" [ i ] else fact "tail_but_try" [ i ]

(* an operand of == or != made where it is written, so no other value is
 * it: what it is, for bugs/physeq.dl's report. A constant constructor and []
 * are numbers, not blocks; a closure is left out (one with no free
 * variable may be static) *)
let rec fresh (x : expr) : string option =
  match x.e with
  | Econs (c, _ :: _) -> Some c.cname
  | Etuple _ -> Some "a tuple"
  | Erecord _ | Ewith _ -> Some "a record"
  | Earray (_ :: _) -> Some "an array"
  | Econst (Ast.String _) -> Some "a string"
  | Econst (Ast.Float _) -> Some "a float"
  | Econstraint (e, _) -> fresh e
  | _ -> None

(* an int of 63 bits that an int of the Pi 1, 31 bits, does not hold:
 * bugs/intwidth.dl's (plan_bug_analyses.md's A4). In the branch of an
 * if Sys.int_size >= 63 (in_wide), what is there runs only where ints
 * are wide: its calls are wide_site, its literals not said *)
let max31 : int = 0x3fffffff

let rec bits (n : int) : int = if n = 0 then 0 else 1 + bits (n lsr 1)

(* the condition c true when ints are wide (Some true), when they are
 * not (Some false) *)
let int_size_test (c : expr) : bool option =
  match c.e with
  | Eapply ({ e = Evar (Prim (op, _, _)); _ },
            [ { e = Evar (Global g); _ }; { e = Econst (Ast.Int n); _ } ])
    when g.gsym = "Sys.int_size" -> (
      match op with
      | "%greaterequal" when n > 31 -> Some true
      | "%greaterthan" when n >= 31 -> Some true
      | "%lessthan" when n > 31 -> Some false
      | "%lessequal" when n >= 31 -> Some false
      | _ -> None)
  | _ -> None

let is_char (x : expr) : bool =
  match Typing.expr_type x with
  | Some (Tconstr ({ tpath = "char"; _ }, [])) -> true
  | _ -> false

(* the bits x's value needs, when x says it: a constant, a mask, a
 * char's code; None, any *)
let rec width (x : expr) : int option =
  match x.e with
  | Econst (Ast.Int n) when n >= 0 -> Some (bits n)
  | Econstraint (e, _) -> width e
  | Eapply ({ e = Evar (Prim ("%andint", _, _)); _ }, [ a; b ]) -> (
      match width a, width b with
      | Some m, Some n -> Some (min m n)
      | (Some _ as w), None | None, (Some _ as w) -> w
      | None, None -> None)
  | Eapply ({ e = Evar (Prim ("%lsrint", _, _)); _ }, [ a; { e = Econst (Ast.Int k); _ } ]) ->
      Option.map (fun (w : int) -> max 0 (w - k)) (width a)
  | Eapply ({ e = Evar (Prim ("%identity", _, _)); _ }, [ a ]) when is_char a -> Some 8
  | _ -> None

let wide_int (site : string) (what : string) : unit =
  if not !in_wide then fact "wide_int" [ site; !unit_name; !inside; what ]

(* 0xffffffff, Sha1's mask before e92ae1ec: -1 on the Pi 1 *)
let literal (x : expr) : unit =
  match x.e with
  | Econst (Ast.Int n) when n > max31 || n < - max31 - 1 ->
      wide_int (Printf.sprintf "%s:%d" !unit_name x.loc)
        (if n > 0 then Printf.sprintf "0x%x" n else string_of_int n)
  | _ -> ()

(* Marshal.to_string v flags, flags without No_sharing: the bytes then
 * depend on what the compiler shared (ca664887's Asm.save); bugs/order.dl's *)
let marshal (x : expr) (f : expr) (args : expr list) : unit =
  let rec no_sharing (e : expr) : bool =
    match e.e with
    | Econs ({ cname = "No_sharing"; _ }, _) -> true
    | Econs (_, es) -> List.exists no_sharing es
    | Econstraint (e, _) -> no_sharing e
    | _ -> false in
  match f.e with
  | Evar (Global g) -> (
      let flags =
        match g.gsym with
        | "Marshal.to_string" | "Marshal.to_bytes" -> List.nth_opt args 1
        | "Marshal.to_channel" -> List.nth_opt args 2
        | _ -> None in
      match flags with
      | Some e when not (no_sharing e) ->
          fact "shares" [ Printf.sprintf "%s:%d" !unit_name x.loc; !inside ]
      | _ -> ())
  | _ -> ()

(* x lsl k past bit 30, by x's width; a shift by 31 or more *)
let shift (site : string) (p : string) (args : expr list) : unit =
  match p, args with
  | ("%lslint" | "%lsrint" | "%asrint"), [ a; { e = Econst (Ast.Int k); _ } ] ->
      let op = match p with "%lslint" -> "lsl" | "%lsrint" -> "lsr" | _ -> "asr" in
      let w = if p = "%lslint" then width a else None in
      let x =
        match a.e with
        | Econst (Ast.Int n) -> Printf.sprintf "0x%x" n
        | Eapply ({ e = Evar (Prim ("%identity", _, _)); _ }, [ c ]) when is_char c -> "a char's code"
        | _ -> "x" in
      (match w with
       | Some w when w + k > 31 -> wide_int site (Printf.sprintf "%s %s %d, %d bits" x op k (w + k))
       | _ -> if k >= 31 then wide_int site (Printf.sprintf "%s %s %d" x op k))
  | _ -> ()

(* e's value goes to the variable dst; name: what a function written
 * here is called (the variable it is bound to) *)
let rec flow (name : string option) (x : expr) (dst : string) : unit =
  let stores (fields : (string * expr) list) : unit =
    List.iter (fun ((field, e) : string * expr) -> fact "assign_store_field" [ dst; field; operand e ]) fields in
  match x.e with
  | Econst _ -> literal x; scalar dst
  | Evar (Local v) -> fact "assign" [ dst; read v ]
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
      List.iter
        (fun (c : string) -> fact "holds_field" [ f; c ])
        (List.sort_uniq compare (List.concat_map (fun ((p, _, _) : case) -> held_in_fields p) cases));
      let outer = !inside and outer_tries = !tries and outer_handlers = !handlers in
      let outer_loop = !in_loop in
      (* (its body runs where it is called, not in the trys around it,
       * nor in the while) *)
      inside := f;
      tries := [];
      handlers := [];
      in_loop := false;
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
      inside := outer;
      tries := outer_tries;
      handlers := outer_handlers;
      in_loop := outer_loop
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
  (* a && b, a || b: b's value is the result, b a tail call if the whole
   * is one (mini-ml's Lower since 2fe7e116), not an external's argument *)
  | Eapply ({ e = Evar (Prim (("%sequand" | "%sequor"), _, _)); _ }, [ a; b ]) ->
      scalar dst;
      flow None a (junk ());
      flow None b dst
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
      (* (a case whose answer is a constant, with _ -> (), says nothing
       * of what it caught: bugs/swallowed.dl's; one that names what it
       * holds, Unix_error (EINTR, _, _), is a choice) *)
      let rec any (p : pattern) : bool =
        match p with
        | Pany | Pvar _ -> true
        | Ptuple ps -> List.for_all any ps
        | Palias (p, _) | Pconstraint (p, _) -> any p
        | _ -> false in
      let rec silent (p : pattern) : unit =
        match p with
        | Pcons ({ kind = Exn g; _ }, ps) -> if List.for_all any ps then fact "silent" [ t; g.gsym ]
        | Por (p, q) -> silent p; silent q
        | Palias (p, _) | Pconstraint (p, _) -> silent p
        | Pvar _ | Pany -> fact "silent_all" [ t ]
        | _ -> () in
      (* (unit or a number: what a None, a false or a [] answers is a
       * question, try Some (stat f) with Unix_error _ -> None) *)
      let rec constant (x : expr) : bool =
        match x.e with
        | Econst (Ast.Int _) -> true
        | Econs ({ cname = "()"; _ }, []) -> true
        | Econstraint (e, _) -> constant e
        | _ -> false in
      (* (a variable of the whole exception points to the try's own
       * object, what it caught: kept and raised again, it is what
       * arrived there, not every exception, as exn would say) *)
      let caught = t ^ ":caught" in
      fact "new_block" [ caught; t ];
      (* (in the function, an exn: old, no frame, so no object ever; and
       * untyped, it would go where any type does) *)
      var_in caught !inside;
      List.iter (fun (r : string) -> fact r [ t; "exn" ]) [ "htype"; "hfull" ];
      List.iter (fun (r : string) -> fact r [ caught; "exn" ]) [ "vtype"; "vfull" ];
      let rec whole (p : pattern) : unit =
        match p with
        | Pvar _ -> bind p caught
        | Palias (q, v) -> bind q (global exn !inside); bind (Pvar v) caught
        | Pconstraint (q, _) -> whole q
        | _ -> bind p (global exn !inside) in
      let outer_handlers = !handlers in
      handlers := t :: outer_handlers;
      List.iter
        (fun ((p, guard, body) : case) ->
          (match guard with None -> catches p; if constant body then silent p | Some _ -> ());
          whole p;
          Option.iter (fun (g : expr) -> flow None g (junk ())) guard;
          flow None body dst)
        cases;
      handlers := outer_handlers
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
      let o = operand e and w = operand v in
      fact "assign_store_field" [ o; "fld:" ^ l.lname; w ];
      fact "store_in" [ o; "fld:" ^ l.lname; w; !inside ]
  | Earray es ->
      block dst x;
      List.iter (fun (e : expr) -> fact "assign_store_field" [ dst; elt; operand e ]) es
  | Eif (c, a, b) ->
      flow None c (junk ());
      let wide = int_size_test c in
      let branch (w : bool) (e : expr) : unit =
        let old = !in_wide in
        if w then in_wide := true;
        flow None e dst;
        in_wide := old in
      branch (wide = Some true) a;
      (match b with Some b -> branch (wide = Some false) b | None -> scalar dst)
  | Eseq (a, b) -> flow None a (junk ()); flow name b dst
  | Ewhile (c, body) ->
      scalar dst;
      let old = !in_loop in
      in_loop := true;
      flow None c (junk ());
      flow None body (junk ());
      in_loop := old
  | Efor (_, lo, hi, _, body) -> scalar dst; flow None lo (junk ()); flow None hi (junk ()); flow None body (junk ())
  | Eassert e -> scalar dst; flow None e (junk ())

(* f a1 ... an: a call for each argument, of what the one before returned *)
and call (x : expr) (f : expr) (args : expr list) (dst : string) : unit =
  marshal x f args;
  (* (each site of this application by its function's span, as the
   * SSA's calls are (Ssa_facts.site): bugs/pairs.dl's) *)
  let key (i : string) : unit =
    fact "site_key" [ i; Printf.sprintf "%s:%d-%d" !unit_name (fst f.span) (snd f.span) ] in
  let fn = ref (operand f) in
  (* an external given all its arguments: its own copy, here, its objects
   * this call's, of the type here (an int ref, not 'a ref). Shared, one
   * Obj.magic, Array.get, ref for all the program, each returned all any
   * caller had given (mini-cc: 306 functions returning 1,000 objects, the
   * same 2,014) *)
  let args =
    match f.e with
    | Evar (Prim (p, arity, t)) when List.length args >= max arity 1 ->
        let n = max arity 1 in
        incr calls;
        let i = Printf.sprintf "%s:%d:c%d" !unit_name x.loc !calls in
        key i;
        let given = Array.of_list (List.map operand (List.filteri (fun k _ -> k < n) args)) in
        let last = List.length args = n in
        let ret = if last then dst else temp () in
        let res = match (if last then Typing.expr_type x else None) with Some r -> r | None -> result t arity in
        prim_body p arity res ~arg:(fun k -> given.(k - 1)) ~ret ~inside:(fun _ -> !inside) ~site:i
          ~place:(Some !unit_name);
        shift i p args;
        if p = "%apply" || p = "%revapply" then begin site_in (i ^ ":call"); position (i ^ ":call") ret end;
        (* (a raise's site, raise_in's: where it runs, what it raises) *)
        if p = "%raise" then begin
          fact "in_function" [ i; !inside ];
          fact1 "argument" i given.(0)
        end;
        (* (a primitive that may fail, its external's [@@raise Sys_error]:
         * a raise of the runtime's, a predefined exception;
         * plan_bug_analyses.md's A2) *)
        (match Hashtbl.find_all Annotations.raises p with
         | [] -> ()
         | es ->
             fact "raise_in" [ i; !inside ];
             fact "in_function" [ i; !inside ];
             site_in i;
             List.iter (fun (e : string) -> fact "raise_of" [ i; "caml_exn_" ^ e ]) es;
             fact "primitive" [ i; p ]);
        (* (x == y, x != y: bugs/physeq.dl's, a side made here never the other) *)
        if p = "%eq" || p = "%noteq" then begin
          fact "phys_compare" [ i; !inside; (if p = "%eq" then "==" else "!=") ];
          (* (its two sides, for a value changed in place compared by
           * identity: physeq.dl's stale) *)
          Array.iter (fun (v : string) -> fact "compared" [ i; v ]) given;
          List.iter (fun (e : expr) -> Option.iter (fun w -> fact "fresh_operand" [ i; w ]) (fresh e))
            (List.filteri (fun k _ -> k < 2) args)
        end;
        fn := ret;
        List.filteri (fun k _ -> k >= n) args
    (* a container's function given all its arguments: what it does, here
     * (Models), its objects this call's *)
    | Evar (Global g)
      when (match Models.find g.gsym with
            | Some (n, _) -> List.length args >= n
            | None -> false) ->
        let n, ops = Option.get (Models.find g.gsym) in
        (* (numbered as the n calls it replaces, each's result a temporary
         * but the last's, an argument's own calls after: the facts after
         * it named as without the model; a temporary no one reads is a
         * number, not a variable) *)
        let total = List.length args in
        let num = ref 0 and ret = ref dst in
        let given =
          Array.of_list
            (List.mapi
               (fun (k : int) (a : expr) ->
                 incr calls;
                 num := !calls;
                 if k < total - 1 then (if k = n - 1 then ret := temp () else incr temps);
                 operand a)
               (List.filteri (fun k _ -> k < n) args)) in
        let i = Printf.sprintf "%s:%d:c%d" !unit_name x.loc !num in
        let last = total = n in
        let ret = !ret in
        let res =
          if last then Typing.expr_type x
          else Option.map (fun (t : ty) -> result t n) g.gtype in
        let sites =
          model_body g.gsym ops ~arg:(fun k -> given.(k - 1)) ~ret ~inside:!inside
            ~site:i ~place:(Some !unit_name) res in
        List.iter site_in sites;
        fn := ret;
        List.filteri (fun k _ -> k >= n) args
    | _ -> args in
  let n = List.length args in
  List.iteri
    (fun (k : int) (a : expr) ->
      incr calls;
      let i = Printf.sprintf "%s:%d:c%d" !unit_name x.loc !calls in
      let result = if k = n - 1 then dst else temp () in
      fact "in_function" [ i; !inside ];
      site_in i;
      key i;
      position i result;
      fact "call_indirect" [ i; !fn ];
      fact1 "argument" i (operand a);
      (* (a result no one reads, ignore (f x)'s, goes nowhere: one junk of a
       * unit had every such call's results, mini-cc's Cgen 398 calls) *)
      if result <> junk () then fact "call_ret" [ i; result ];
      fn := result)
    args

(* the variable e's value is in: its own if it is one, or a new one *)
and operand (x : expr) : string =
  match x.e with
  | Evar (Local v) -> read v
  | Evar (Global g) -> typed "vtype" g.gsym g.gtype; global g.gsym !inside
  | Econstraint (e, _) -> operand e
  | Econst _ -> literal x; constant ()
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
          let name : string = match List.assq_opt v exported with Some g -> g.gsym | None -> bound v; local v in
          flow (Some name) e (local v)
      | None ->
          (* (a toplevel's pattern, let a, b = ...: the unit's, other
           * units read them, as OCaml does not say) *)
          let src = operand e in
          exported_pattern := exported <> [];
          bind p src;
          exported_pattern := false)
    bindings

let unit_ (name : string) (items : item list) : string =
  Buffer.clear out;
  Hashtbl.reset prims;
  Hashtbl.reset mentioned;
  Hashtbl.reset reads;
  unit_name := name;
  temps := 0;
  calls := 0;
  try_count := 0;
  tries := [];
  handlers := [];
  handler_vars := [];
  in_wide := false;
  in_loop := false;
  funs := 0;
  blocks := 0;
  inside := name ^ ":init";
  fact "init" [ name ^ ":init" ];
  List.iter
    (fun (item : item) ->
      match item with
      | Ieval e -> flow None e (junk ())
      (* a modeled unit's functions: their models, their bodies not read; the
       * unit's own code, what is not modeled, calls them by their variable *)
      | Ivalue (_, bindings, ((_ :: _) as exported))
        when Models.modeled_unit name
             && List.for_all
                  (fun ((_, g) : var * global) -> Models.find g.gsym <> None)
                  exported ->
          List.iter
            (fun ((v, g) : var * global) ->
              let n, ops = Option.get (Models.find g.gsym) in
              let line =
                List.fold_left
                  (fun (l : int) ((p, e) : pattern * expr) ->
                    match plain p with Some w when w.vid = v.vid -> e.loc | _ -> l)
                  0 bindings in
              let f = model_fun g.gsym n ops g.gtype in
              (* (where the function is written: dynamic.sh's, what ran
               * there is the model's) *)
              fact "closure" [ f; !unit_name; string_of_int line ];
              fact "alloc_in" [ f; !unit_name ];
              fact "assign_address" [ local v; f ];
              fact "global_def" [ g.gsym; !inside ];
              fact "assign" [ global g.gsym !inside; local v ])
            exported
      | Ivalue (_, bindings, exported) ->
          lets bindings exported;
          List.iter
            (fun ((v, g) : var * global) ->
              fact "global_def" [ g.gsym; !inside ];
              fact "assign" [ global g.gsym !inside; local v ])
            exported
      | Iexception _ -> ()
      | Iexternal (g, p, arity, t) ->
          fact "assign_address" [ global g.gsym !inside; prim p arity t ];
          (* (its primitive, what its [@@raise] says: checked against the
           * C by bugs/raises.dl) *)
          fact "external_prim" [ g.gsym; p ];
          List.iter (fun (e : string) -> fact "declares_raise" [ p; "caml_exn_" ^ e ])
            (List.sort_uniq compare (Hashtbl.find_all Annotations.raises p)))
    items;
  Buffer.contents out
