(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiger_emit.mli *)

open Tiger_tree
module S = Signature
module W = Writer

(* ------------------------------------------------------------------ *)
(* The assembly's classes and members, each made when first needed *)
(* ------------------------------------------------------------------ *)

type t = {
  w : W.t;
  runtime : int;
  console : int;
  program : int;                                  (* the class of the functions *)
  library : int;                                  (* the class Tiger *)
  memo : (string, int) Hashtbl.t;                 (* what is made, by a name of ours *)
}

let memo (c : t) (key : string) (make : unit -> int) : int =
  match Hashtbl.find_opt c.memo key with
  | Some x -> x
  | None -> let x = make () in Hashtbl.replace c.memo key x; x

let static (ps : S.t list) (r : S.t) : S.meth =
  { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps }
let instance (ps : S.t list) (r : S.t) : S.meth = { (static ps r) with has_this = true }

let sys (c : t) (name : string) : int =
  memo c ("type " ^ name) (fun () ->
      if name = "Console" then c.console
      else if name = "Encoding" then W.type_ref c.w c.runtime "System.Text" name
      else W.type_ref c.w c.runtime "System" name)

(* a member of the library's: its class, name and signature *)
let lib (c : t) (cls : string) (name : string) (m : S.meth) : int =
  memo c (cls ^ "::" ^ name ^ S.encode_method m) (fun () -> W.member_ref c.w (sys c cls) name m)

let object_ctor (c : t) : int = lib c "Object" ".ctor" (instance [] S.Void)

(* a class with nothing but its constructor, which calls its parent's *)
let new_class (c : t) (name : string) (parent : int) (parent_ctor : int) (args : Il.op list) : int * int =
  let cls = W.type_def c.w "" name 0x00100001 parent in
  let ctor = W.method_def c.w cls ".ctor" 0x1886 (instance [] S.Void) in
  W.set_body c.w ctor [] (Array.of_list ([ Il.Ldarg 0 ] @ args @ [ Il.Call parent_ctor; Il.Ret ])) [];
  (cls, ctor)

(* a record type: a class of fields *)
let rec record (c : t) (r : record) : int * int =
  let key = Printf.sprintf "record %d" r.rid in
  (match Hashtbl.find_opt c.memo key with
   | Some _ -> ()
   | None ->
       let cls, ctor = new_class c (Printf.sprintf "%s_%d" r.rname r.rid) (sys c "Object") (object_ctor c) [] in
       (* (known before its fields, which may be of its own type) *)
       Hashtbl.replace c.memo key cls;
       Hashtbl.replace c.memo (Printf.sprintf "ctor %d" r.rid) ctor;
       List.iteri (fun i (f, ty) ->
           Hashtbl.replace c.memo (Printf.sprintf "field %d %d" r.rid i)
             (W.field_def c.w cls f 0x0006 (sig_of c ty))) r.rfields);
  (Hashtbl.find c.memo key, Hashtbl.find c.memo (Printf.sprintf "ctor %d" r.rid))

and sig_of (c : t) (ty : ty) : S.t =
  match ty with
  | Int -> S.I4
  | String -> S.String
  | Unit -> S.Void
  | Nil -> S.Object
  | Record r -> S.Class (fst (record c r))
  | Array a -> S.SzArray (sig_of c a.elem)

let field_tok (c : t) (r : record) (i : int) : int =
  ignore (record c r);
  Hashtbl.find c.memo (Printf.sprintf "field %d %d" r.rid i)

(* the type newarr is given *)
let elem_tok (c : t) (ty : ty) : int =
  match ty with
  | Int -> sys c "Int32"
  | String -> sys c "String"
  | Record r -> fst (record c r)
  | Array _ -> memo c ("spec " ^ S.encode_type_spec (sig_of c ty)) (fun () -> W.type_spec c.w (sig_of c ty))
  | Unit | Nil -> sys c "Object"

(* a function's frame, an object: the variables its nested functions
 * use, and the link to its parent's frame *)
let rec frame (c : t) (f : func) : int * int =
  let cls = memo c ("frame " ^ f.name) (fun () ->
      let cls, ctor = new_class c ("frame_" ^ f.name) (sys c "Object") (object_ctor c) [] in
      Hashtbl.replace c.memo ("frame ctor " ^ f.name) ctor;
      (match f.parent with
       | Some p -> Hashtbl.replace c.memo ("link " ^ f.name)
                     (W.field_def c.w cls "link" 0x0006 (S.Class (fst (frame c p))))
       | None -> ());
      cls) in
  (cls, Hashtbl.find c.memo ("frame ctor " ^ f.name))

let link (c : t) (f : func) : int = ignore (frame c f); Hashtbl.find c.memo ("link " ^ f.name)

let var_field (c : t) (v : var) : int =
  memo c (Printf.sprintf "var %d" v.vid) (fun () ->
      W.field_def c.w (fst (frame c v.vfun)) (Printf.sprintf "%s_%d" v.vname v.vid) 0x0006 (sig_of c v.vty))

let method_of (c : t) (f : func) : int =
  memo c ("method " ^ f.name) (fun () ->
      let link = match f.parent with Some p -> [ S.Class (fst (frame c p)) ] | None -> [] in
      let m = if f.parent = None then static [] S.I4
        else static (link @ List.map (fun v -> sig_of c v.vty) f.params) (sig_of c f.result) in
      W.method_def c.w c.program (if f.parent = None then "Main" else f.name) 0x0096 m)

(* an exception: a class of System.Exception's, its message its name *)
let exn_ctor (c : t) (x : exn) : int * int =
  let cls = memo c (Printf.sprintf "exn %d" x.eid) (fun () ->
      let base_ctor = lib c "Exception" ".ctor" (instance [ S.String ] S.Void) in
      let cls, ctor = new_class c (Printf.sprintf "%s_%d" x.ename x.eid) (sys c "Exception") base_ctor
          [ Il.Ldstr (W.user_string c.w x.ename) ] in
      Hashtbl.replace c.memo (Printf.sprintf "exn ctor %d" x.eid) ctor;
      cls) in
  (cls, Hashtbl.find c.memo (Printf.sprintf "exn ctor %d" x.eid))

(* ------------------------------------------------------------------ *)
(* A method's code: the instructions, their labels, the locals *)
(* ------------------------------------------------------------------ *)

type code = {
  mutable ops : Il.op list;                       (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;                  (* a label to its instruction *)
  mutable nlabels : int;
  mutable locals : S.t list;                      (* reversed *)
  mutable nlocals : int;
  slots : (int, int) Hashtbl.t;                   (* a variable's local *)
  mutable clauses : (int * int * int * int * int) list;   (* by labels, and the class *)
  fn : func;
  mutable loops : (int * int) list;               (* each loop's end, and the trys around it *)
  mutable trys : int;
}

let emit (k : code) (op : Il.op) : unit = k.ops <- op :: k.ops; k.n <- k.n + 1
let label (k : code) : int = k.nlabels <- k.nlabels + 1; k.nlabels
let place (k : code) (l : int) : unit = Hashtbl.replace k.labels l k.n
let local (k : code) (ty : S.t) : int =
  k.locals <- ty :: k.locals; k.nlocals <- k.nlocals + 1; k.nlocals - 1

let finish (c : t) (k : code) (meth : int) : unit =
  let at l = Hashtbl.find k.labels l in
  let ops = Array.of_list (List.rev_map (fun op -> match op with
      | Il.Br l -> Il.Br (at l) | Il.Brfalse l -> Il.Brfalse (at l)
      | Il.Brtrue l -> Il.Brtrue (at l) | Il.Bcmp (x, u, l) -> Il.Bcmp (x, u, at l)
      | Il.Leave l -> Il.Leave (at l) | op -> op) k.ops) in
  let clauses = List.rev_map (fun (ts, te, hs, he, cls) ->
      { W.kind = 0; try_start = at ts; try_end = at te; handler_start = at hs;
        handler_end = at he; catch = cls }) k.clauses in
  W.set_body c.w meth (List.rev k.locals) ops clauses

(* ------------------------------------------------------------------ *)
(* Variables *)
(* ------------------------------------------------------------------ *)

(* the frame of [f], from the function running: its own local, or the
 * static link (argument 0, the parent's frame) followed up *)
let frame_of (c : t) (k : code) (f : func) : unit =
  if k.fn == f then emit k (Il.Ldloc 0)
  else begin
    emit k (Il.Ldarg 0);
    let rec up (g : func) =
      if g != f then
        match g.parent with
        | Some p -> emit k (Il.Ldfld (link c g)); up p
        | None -> failwith "Tiger_emit: a frame not above" in
    match k.fn.parent with
    | Some p -> up p
    | None -> failwith "Tiger_emit: main has no link"
  end

let arg_of (k : code) (v : var) : int = v.param + (if k.fn.parent = None then 0 else 1)

let slot (c : t) (k : code) (v : var) : int =
  match Hashtbl.find_opt k.slots v.vid with
  | Some i -> i
  | None -> let i = local k (sig_of c v.vty) in Hashtbl.replace k.slots v.vid i; i

let load_var (c : t) (k : code) (v : var) : unit =
  if v.escapes then (frame_of c k v.vfun; emit k (Il.Ldfld (var_field c v)))
  else if v.param >= 0 then emit k (Il.Ldarg (arg_of k v))
  else emit k (Il.Ldloc (slot c k v))

(* a variable given the value [value] pushes *)
let store_var (c : t) (k : code) (v : var) (value : unit -> unit) : unit =
  if v.escapes then (frame_of c k v.vfun; value (); emit k (Il.Stfld (var_field c v)))
  else if v.param >= 0 then (value (); emit k (Il.Starg (arg_of k v)))
  else (value (); emit k (Il.Stloc (slot c k v)))

let kind_of (ty : ty) : Il.kind = if ty = Int then Il.K_i4 else Il.K_ref

(* ------------------------------------------------------------------ *)
(* The library: the class Tiger, its methods on System's *)
(* ------------------------------------------------------------------ *)

let builtin (c : t) (name : string) : int =
  memo c ("builtin " ^ name) (fun () ->
      let str = S.String and int = S.I4 and void = S.Void in
      let char_to_string = lib c "Char" "ToString" (static [ S.Char ] str) in
      let sg, code = match name with
        | "print" -> static [ str ] void, [ Il.Ldarg 0; Il.Call (lib c "Console" "Write" (static [ str ] void)); Il.Ret ]
        | "printi" -> static [ int ] void, [ Il.Ldarg 0; Il.Call (lib c "Console" "Write" (static [ int ] void)); Il.Ret ]
        | "flush" -> static [] void, [ Il.Ret ]
        | "getchar" ->
            static [] str, [ Il.Call (lib c "Console" "Read" (static [] int)); Il.Dup;
                             Il.Ldc_i4 Int32.minus_one; Il.Bcmp (Il.Ne, false, 7);
                             Il.Pop; Il.Ldstr (W.user_string c.w ""); Il.Ret;
                             (* 7 *) Il.Conv (Il.K_u2, false, false); Il.Call char_to_string; Il.Ret ]
        | "ord" ->
            let length = lib c "String" "get_Length" (instance [] int) in
            (* (not one character: the program stops, status 1, as
             * fork-tiger's ord; Appel's gives -1 for "") *)
            static [ str ] int, [ Il.Ldarg 0; Il.Callvirt length; Il.Ldc_i4 Int32.one; Il.Bcmp (Il.Eq, false, 8);
                                  Il.Ldc_i4 Int32.one;
                                  Il.Call (lib c "Environment" "Exit" (static [ int ] void));
                                  Il.Ldc_i4 Int32.minus_one; Il.Ret;
                                  (* 8 *) Il.Ldarg 0; Il.Ldc_i4 Int32.zero;
                                  Il.Callvirt (lib c "String" "get_Chars" (instance [ int ] S.Char)); Il.Ret ]
        | "chr" -> static [ int ] str, [ Il.Ldarg 0; Il.Conv (Il.K_u2, false, false); Il.Call char_to_string; Il.Ret ]
        | "size" -> static [ str ] int, [ Il.Ldarg 0; Il.Callvirt (lib c "String" "get_Length" (instance [] int)); Il.Ret ]
        | "substring" ->
            static [ str; int; int ] str,
            [ Il.Ldarg 0; Il.Ldarg 1; Il.Ldarg 2;
              Il.Callvirt (lib c "String" "Substring" (instance [ int; int ] str)); Il.Ret ]
        | "concat" -> static [ str; str ] str, [ Il.Ldarg 0; Il.Ldarg 1; Il.Call (lib c "String" "Concat" (static [ str; str ] str)); Il.Ret ]
        | "not" -> static [ int ] int, [ Il.Ldarg 0; Il.Ldc_i4 Int32.zero; Il.Ceq; Il.Ret ]
        | "exit" -> static [ int ] void, [ Il.Ldarg 0; Il.Call (lib c "Environment" "Exit" (static [ int ] void)); Il.Ret ]
        | n -> failwith ("Tiger_emit: no builtin " ^ n) in
      (* (a branch's target: the index of an instruction in the list) *)
      let m = W.method_def c.w c.library name 0x0096 sg in
      W.set_body c.w m [] (Array.of_list code) [];
      m)

(* ------------------------------------------------------------------ *)
(* Expressions *)
(* ------------------------------------------------------------------ *)

let rec exp (c : t) (k : code) (x : exp) : unit =
  match x.e with
  | Nil_e -> emit k Il.Ldnull
  | Int_e n -> emit k (Il.Ldc_i4 n)
  | String_e s -> emit k (Il.Ldstr (W.user_string c.w s))
  | Var_e lv -> load c k lv
  | Op_e (a, op, b) -> exp c k a; exp c k b; oper c k a.ty op
  | Call_e (f, args) ->
      (match f.parent with Some p -> frame_of c k p | None -> ());
      List.iter (exp c k) args;
      emit k (Il.Call (method_of c f))
  | Builtin_e ("sizea", [ a ]) -> exp c k a; emit k Il.Ldlen; emit k (Il.Conv (Il.K_i4, false, false))
  | Builtin_e (name, args) -> List.iter (exp c k) args; emit k (Il.Call (builtin c name))
  | Record_e (r, es) ->
      emit k (Il.Newobj (snd (record c r)));
      List.iteri (fun i e -> emit k Il.Dup; exp c k e; emit k (Il.Stfld (field_tok c r i))) es
  | Array_e (a, size, init) ->
      (* a = new T[size]; for (i = 0; i < size; i++) a[i] = init: init
       * evaluated for each element, as fork-tiger does (Appel's
       * initArray takes it once, all the elements then the same record) *)
      let n = local k S.I4 and i = local k S.I4 in
      let arr = local k (sig_of c (Array a)) in
      exp c k size; emit k (Il.Stloc n);
      emit k (Il.Ldloc n); emit k (Il.Newarr (elem_tok c a.elem)); emit k (Il.Stloc arr);
      emit k (Il.Ldc_i4 Int32.zero); emit k (Il.Stloc i);
      let test = label k and out = label k in
      place k test;
      emit k (Il.Ldloc i); emit k (Il.Ldloc n); emit k (Il.Bcmp (Il.Ge, false, out));
      emit k (Il.Ldloc arr); emit k (Il.Ldloc i); exp c k init; emit k (Il.Stelem (kind_of a.elem));
      emit k (Il.Ldloc i); emit k (Il.Ldc_i4 Int32.one); emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
      emit k (Il.Br test);
      place k out;
      emit k (Il.Ldloc arr)
  | Seq_e l ->
      let rec go l = match l with
        | [] -> ()
        | [ e ] -> exp c k e
        | e :: rest -> stmt c k e; go rest in
      go l
  | Assign_e (lv, e) -> assign c k lv (fun () -> exp c k e)
  | If_e (cond, t, f) ->
      let other = label k and out = label k in
      exp c k cond; emit k (Il.Brfalse other);
      exp c k t; emit k (Il.Br out);
      place k other;
      (match f with Some f -> exp c k f | None -> ());
      place k out
  | While_e (cond, body) ->
      let test = label k and out = label k in
      place k test;
      exp c k cond; emit k (Il.Brfalse out);
      loop c k out (fun () -> stmt c k body);
      emit k (Il.Br test);
      place k out
  | For_e (v, lo, hi, body) ->
      (* i = lo; limit = hi; if i <= limit: loop { body; if i >= limit
       * out; i++ } (never past int's largest) *)
      let limit = local k S.I4 in
      let top = label k and out = label k in
      store_var c k v (fun () -> exp c k lo);
      exp c k hi; emit k (Il.Stloc limit);
      load_var c k v; emit k (Il.Ldloc limit); emit k (Il.Bcmp (Il.Gt, false, out));
      place k top;
      loop c k out (fun () -> stmt c k body);
      load_var c k v; emit k (Il.Ldloc limit); emit k (Il.Bcmp (Il.Ge, false, out));
      store_var c k v (fun () -> load_var c k v; emit k (Il.Ldc_i4 Int32.one); emit k (Il.Binop Il.Add));
      emit k (Il.Br top);
      place k out
  | Break_e ->
      (match k.loops with
       | (out, trys) :: _ -> emit k (if k.trys > trys then Il.Leave out else Il.Br out)
       | [] -> failwith "Tiger_emit: break outside a loop")
  | Let_e (vars, body) ->
      List.iter (fun (v, init) -> store_var c k v (fun () -> exp c k init)) vars;
      exp c k body
  | Try_e (body, handlers) ->
      (* .try { body; leave } catch E1 { pop; h1; leave } catch E2 ... *)
      let result = if x.ty = Unit then -1 else local k (sig_of c x.ty) in
      let keep () = if result >= 0 then emit k (Il.Stloc result) in
      let start = label k and out = label k in
      let starts = List.map (fun _ -> label k) handlers in
      k.trys <- k.trys + 1;
      place k start;
      exp c k body; keep (); emit k (Il.Leave out);
      List.iteri (fun i (xn, h) ->
          place k (List.nth starts i);
          emit k Il.Pop;
          exp c k h; keep (); emit k (Il.Leave out);
          let stop = if i + 1 < List.length starts then List.nth starts (i + 1) else out in
          k.clauses <- (start, List.hd starts, List.nth starts i, stop, fst (exn_ctor c xn)) :: k.clauses)
        handlers;
      k.trys <- k.trys - 1;
      place k out;
      if result >= 0 then emit k (Il.Ldloc result)
  | Raise_e xn -> emit k (Il.Newobj (snd (exn_ctor c xn))); emit k Il.Throw

(* an expression whose value, if it has one, is not wanted *)
and stmt (c : t) (k : code) (x : exp) : unit =
  exp c k x;
  if x.ty <> Unit then emit k Il.Pop

and loop (_c : t) (k : code) (out : int) (body : unit -> unit) : unit =
  k.loops <- (out, k.trys) :: k.loops;
  body ();
  k.loops <- List.tl k.loops

and load (c : t) (k : code) (lv : lvalue) : unit =
  match lv with
  | Simple v -> load_var c k v
  | Field (lv, r, i) -> load c k lv; emit k (Il.Ldfld (field_tok c r i))
  | Subscript (lv, a, i) -> load c k lv; exp c k i; emit k (Il.Ldelem (kind_of a.elem))

and assign (c : t) (k : code) (lv : lvalue) (value : unit -> unit) : unit =
  match lv with
  | Simple v -> store_var c k v value
  | Field (lv, r, i) -> load c k lv; value (); emit k (Il.Stfld (field_tok c r i))
  | Subscript (lv, a, i) -> load c k lv; exp c k i; value (); emit k (Il.Stelem (kind_of a.elem))

(* an operator, its two operands pushed; a comparison leaves 0 or 1 *)
and oper (c : t) (k : code) (ty : ty) (op : Tiger_ast.oper) : unit =
  let negate () = emit k (Il.Ldc_i4 Int32.zero); emit k Il.Ceq in
  let str = S.String and int = S.I4 in
  match op, ty with
  | Tiger_ast.Plus, _ -> emit k (Il.Binop Il.Add)
  | Tiger_ast.Minus, _ -> emit k (Il.Binop Il.Sub)
  | Tiger_ast.Times, _ -> emit k (Il.Binop Il.Mul)
  | Tiger_ast.Divide, _ -> emit k (Il.Binop Il.Div)
  | (Tiger_ast.Eq | Tiger_ast.Neq), String ->
      emit k (Il.Call (lib c "String" "op_Equality" (static [ str; str ] S.Bool)));
      if op = Tiger_ast.Neq then negate ()
  | Tiger_ast.Eq, _ -> emit k Il.Ceq
  | Tiger_ast.Neq, _ -> emit k Il.Ceq; negate ()
  | _, String ->
      (* String.CompareOrdinal(a, b), then compared with 0 *)
      emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ str; str ] int)));
      emit k (Il.Ldc_i4 Int32.zero);
      oper c k Int op
  | Tiger_ast.Lt, _ -> emit k (Il.Clt false)
  | Tiger_ast.Gt, _ -> emit k (Il.Cgt false)
  | Tiger_ast.Le, _ -> emit k (Il.Cgt false); negate ()
  | Tiger_ast.Ge, _ -> emit k (Il.Clt false); negate ()

(* ------------------------------------------------------------------ *)
(* Functions *)
(* ------------------------------------------------------------------ *)

let func (c : t) (f : func) : unit =
  let k = { ops = []; n = 0; labels = Hashtbl.create 16; nlabels = 0; locals = []; nlocals = 0;
            slots = Hashtbl.create 8; clauses = []; fn = f; loops = []; trys = 0 } in
  (* its frame, when it has functions of its own: local 0; its link,
   * its parameters that escape copied in *)
  if f.nested then begin
    let cls, ctor = frame c f in
    ignore (local k (S.Class cls));
    emit k (Il.Newobj ctor); emit k (Il.Stloc 0);
    (match f.parent with
     | Some _ -> emit k (Il.Ldloc 0); emit k (Il.Ldarg 0); emit k (Il.Stfld (link c f))
     | None -> ());
    List.iter (fun v -> if v.escapes then begin
        emit k (Il.Ldloc 0); emit k (Il.Ldarg (arg_of k v)); emit k (Il.Stfld (var_field c v))
      end) f.params
  end;
  let body = match f.fbody with Some b -> b | None -> failwith "Tiger_emit: a function without its body" in
  if f.parent = None then begin
    (* Tiger's strings are bytes: the console's text read and written as
     * Latin-1, a byte a character (.NET's default, UTF-8, would make
     * two of a byte above 127, and read them back as one) *)
    let latin1 = lib c "Encoding" "get_Latin1" (static [] (S.Class (sys c "Encoding"))) in
    List.iter (fun dir ->
        emit k (Il.Call latin1);
        emit k (Il.Call (lib c "Console" ("set_" ^ dir ^ "Encoding") (static [ S.Class (sys c "Encoding") ] S.Void))))
      [ "Input"; "Output" ];
    (* Main: the program's value, if an int, its exit status *)
    if body.ty = Int then exp c k body else (stmt c k body; emit k (Il.Ldc_i4 Int32.zero))
  end else exp c k body;
  emit k Il.Ret;
  finish c k (method_of c f)

let program (name : string) (p : program) : string =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console = W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  let program = W.type_def w "" "Program" 0x00100181 obj in
  let library = W.type_def w "" "Tiger" 0x00100181 obj in
  let c = { w; runtime; console; program; library; memo = Hashtbl.create 64 } in
  Hashtbl.replace c.memo "type Object" obj;
  let main = method_of c p.main in
  W.set_entry_point w main;
  func c p.main;
  List.iter (func c) p.funcs;
  W.write w
