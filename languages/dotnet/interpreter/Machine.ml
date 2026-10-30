(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Machine.mli *)

open Value

let jit : (meth -> (value array -> value) option) option ref = ref None

(* Tiers (.NET's tiered compilation, Core 3.0): a method interpreted
 * first (tier 0), compiled (tier 1) at its call after [tier] calls, so
 * that the code run once, a Main, an initialization, is not compiled;
 * but a method with a loop at its first call, its loop maybe the
 * program's time (.NET's QuickJitForLoops off, before its on-stack
 * replacement). The JIT asked once: refused, the method stays the
 * interpreter's. *)
let tier = ref 30

let hot (m : meth) (code : code) : bool =
  m.calls <- m.calls + 1;
  let loops () = Array.exists (fun (x : Il.instr) -> match x.op with
      | Il.Br t | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) | Il.Leave t -> t <= Il.index code.instrs x.at
      | Il.Switch ts -> Array.exists (fun t -> t <= Il.index code.instrs x.at) ts
      | _ -> false) code.instrs in
  m.calls = !tier + 1 || (m.calls = 1 && loops ())

(* ------------------------------------------------------------------ *)
(* Places: fields, elements, pointers *)
(* ------------------------------------------------------------------ *)

(* a struct's copy out of a store *)
let extract (st : store) (so : int) (ro : int) (c : cls) : value =
  let s = Bytes.sub st.s so c.nbytes and r = Array.sub st.r ro c.nrefs in
  Vt { cls = c; s; r; len = 0; native = No_native }

let blit (v : value) (st : store) (so : int) (ro : int) : unit =
  match v with
  | Vt src | Obj src ->
      Bytes.blit src.s 0 st.s so (Bytes.length src.s);
      Array.blit src.r 0 st.r ro (Array.length src.r)
  | _ -> Frame.error "a struct expected"

(* a value of type [t] at (so, ro) in a store *)
let read (st : store) (so : int) (ro : int) (t : typ) : value =
  match t with
  | T_value c -> extract st so ro c
  | t when is_ref t -> st.r.(ro)
  | t -> load st.s so t

let write (st : store) (so : int) (ro : int) (t : typ) (v : value) : unit =
  match t with
  | T_value _ -> blit v st so ro
  | t when is_ref t -> st.r.(ro) <- v
  | t -> store_at st.s so t v

(* the store an object reference, a struct or a pointer to one is in *)
let view (v : value) : store * int * int =
  match v with
  | Obj st | Vt st -> (st, 0, 0)
  | Ptr (Slot (a, i)) -> (match a.(i) with
      | Vt st | Obj st -> (st, 0, 0)
      | Null -> Frame.null_ref ()
      | _ -> Frame.error "a pointer to a number used as an object")
  | Ptr (Inside (st, so, ro, _)) -> (st, so, ro)
  | Null -> Frame.null_ref ()
  | _ -> Frame.error "not an object"

let copy_value (v : value) : value = match v with Vt st -> Vt (copy st) | v -> v

let deref (p : value) : value =
  match p with
  | Ptr (Slot (a, i)) -> copy_value a.(i)
  | Ptr (Bytes (st, off, t)) -> load st.s off t
  | Ptr (Inside (st, so, ro, c)) -> extract st so ro c
  | Null -> Frame.null_ref ()
  | _ -> Frame.error "not a pointer"

let assign (p : value) (v : value) : unit =
  match p with
  | Ptr (Slot (a, i)) -> a.(i) <- v
  | Ptr (Bytes (st, off, t)) -> store_at st.s off t v
  | Ptr (Inside (st, so, ro, _)) -> blit v st so ro
  | Null -> Frame.null_ref ()
  | _ -> Frame.error "not a pointer"

let element_type (st : store) : typ =
  match st.cls.element with Some e -> e | None -> Frame.error "not an array"

let element (v : value) (i : value) : store * int * int * typ =
  let st = match v with Obj st -> st | Null -> Frame.null_ref () | _ -> Frame.error "not an array" in
  let i = match i with I4 n -> Int32.to_int n | I8 n -> Int64.to_int n | _ -> Frame.error "an index" in
  if i < 0 || i >= st.len then Frame.out_of_range ();
  let e = element_type st in
  let b, r = footprint e in
  (st, i * b, i * r, e)

(* ------------------------------------------------------------------ *)
(* Classes at run time *)
(* ------------------------------------------------------------------ *)

let string_class () = Types.find_class "System.String" [||]

let class_of_value (v : value) : cls =
  match v with
  | Obj st | Vt st -> st.cls
  | Str _ -> string_class ()
  | I4 _ -> Types.find_class "System.Int32" [||]
  | I8 _ -> Types.find_class "System.Int64" [||]
  | R8 _ -> Types.find_class "System.Double" [||]
  | Null -> Frame.null_ref ()
  | _ -> Frame.error "the class of a pointer"

(* can a value of class [c] be seen as of type [t]? *)
let rec instance_of (c : cls) (t : cls) : bool =
  subclass c t
  || (match c.element, t.element with
      | Some e, Some f -> (match e, f with
          | (T_class a | T_value a), (T_class b | T_value b) -> instance_of a b
          | _ -> typ_key e = typ_key f)
      | Some _, None -> t.name = "System.Object" || t.name = "System.Array"
      | _ -> false)

(* a value type's box, a reference type's value as it is *)
let box (t : typ) (v : value) : value =
  match t, v with
  | T_value _, Vt st -> Obj (copy st)
  | t, (I4 _ | I8 _ | R8 _) when Types.is_value_type t ->
      let c = Types.class_of_typ t in
      let st = make_store c 0 in
      store_at st.s 0 t v;
      Obj st
  | _, v -> v

let unbox (t : typ) (v : value) : value =
  match v with
  | Null -> Frame.null_ref ()
  | Obj st ->
      let c = Types.class_of_typ t in
      if st.cls != c then Frame.invalid_cast st.cls c;
      (match t with T_value _ -> Vt (copy st) | t -> load st.s 0 t)
  | v -> v

(* a static constructor, before the class is first used *)
let rec ensure_init (c : cls) : unit =
  if c.init = Not_run then begin
    c.init <- Running;
    (match List.find_opt (fun (m : meth) -> m.mname = ".cctor" && m.static) c.methods with
     | Some m -> ignore (invoke m [||])
     | None -> ());
    c.init <- Done
  end

and statics (f : field) : store =
  ensure_init f.fcls;
  match f.fcls.statics with
  | Some st -> st
  | None -> Frame.error ("no static storage for " ^ f.fname)

(* ------------------------------------------------------------------ *)
(* Calls *)
(* ------------------------------------------------------------------ *)

and invoke (m : meth) (args : value array) : value =
  match m.body with
  | Native f -> f args
  | Il_body _ | Decoded _
    when (match !jit with
        | Some compile when hot m (Types.code m) ->
            (match compile m with Some f -> m.body <- Native f; true | None -> false)
        | _ -> false) ->
      invoke m args
  | Runtime ->
      if m.mname = "Invoke" then begin
        let st = match args.(0) with Obj st -> st | Null -> Frame.null_ref () | _ -> Frame.error "a delegate" in
        match st.native with
        | N_delegate (target, fn) ->
            let rest = Array.sub args 1 (Array.length args - 1) in
            if fn.static then invoke fn rest
            else call_virtual_this fn (Array.append [| target |] rest) false
        | _ -> Frame.error "a delegate without its method"
      end
      else Frame.error (Frame.name_of m ^ ": a runtime method mini-dotnet has not")
  | No_body -> Frame.error (Frame.name_of m ^ ": abstract, called")
  | Il_body _ | Decoded _ -> run_method m args

(* a call whose `this` is in args.(0): to a value type's method, a
 * pointer to the struct (a box's inside) *)
and call_virtual_this (m : meth) (args : value array) (virt : bool) : value =
  let this = args.(0) in
  (match this with Null -> Frame.null_ref () | _ -> ());
  let target = match this with
    | (Obj _ | Str _ | Vt _ | I4 _ | I8 _ | R8 _) when virt && m.virt ->
        Types.virtual_target (class_of_value this) m
    | _ -> m in
  (match this, Types.typ_of_cls target.mcls with
   | Obj st, (T_value _ | T_bool | T_char | T_i1 | T_u1 | T_i2 | T_u2 | T_i4 | T_u4
             | T_i8 | T_u8 | T_r4 | T_r8 | T_i | T_u) when target.def <> None ->
       args.(0) <- Ptr (Inside (st, 0, 0, st.cls))
   | _ -> ());
  invoke target args

and run_method (m : meth) (args : value array) : value =
  (* (a recursion with no end: .NET's stack is a megabyte, here OCaml's
   * own stack would be used up first, its Frame.frames bigger) *)
  incr Frame.depth;
  if !Frame.depth > Frame.max_depth then raise Frame.Stack_overflow;
  let code = Types.code m in
  let (f : Frame.frame) = { meth = m; code; args;
            locals = Array.map zero code.locals;
            stack = Array.make (code.max_stack + 1) Null; sp = 0; pc = 0; at = 0; caught = None } in
  Frame.frames := f :: !Frame.frames;
  match run f with
  | Frame.Returned v -> Frame.frames := List.tl !Frame.frames; decr Frame.depth; v
  | Frame.End_finally | Frame.Filtered _ -> Frame.error "endfinally or endfilter outside their block"
  | exception e -> Frame.frames := List.tl !Frame.frames; decr Frame.depth; raise e

(* the instructions run, an exception caught by this frame's clauses *)
and run (f : Frame.frame) : Frame.outcome =
  match loop (-1) f with
  | o -> o
  | exception Thrown exn ->
      let at = f.at in
      let rec search i =
        if i >= Array.length f.code.clauses then raise (Thrown exn)
        else
          let c = f.code.clauses.(i) in
          if at >= c.tstart && at < c.tend then
            let mine = match !Frame.chosen with Some (g, j) -> g == f && j = i | None -> false in
            match c.ckind, c.catch with
            | 0, Some k when subclass exn.cls k || mine ->
                f.sp <- 0;
                f.stack.(0) <- Obj exn; f.sp <- 1;
                f.pc <- c.hstart;
                f.caught <- Some exn
            | 1, _ when mine ->
                f.sp <- 0;
                f.stack.(0) <- Obj exn; f.sp <- 1;
                f.pc <- c.hstart;
                f.caught <- Some exn
            | (2 | 4), _ -> run_finally f c.hstart; search (i + 1)
            | _ -> search (i + 1)
          else search (i + 1) in
      search 0;
      run f

and run_finally (f : Frame.frame) (start : int) : unit =
  let pc = f.pc and at = f.at in
  f.sp <- 0;
  f.pc <- start;
  (match run f with Frame.End_finally -> () | _ -> Frame.error "a return in a finally");
  f.pc <- pc; f.at <- at

and run_filter (f : Frame.frame) (c : clause) (exn : store) : bool =
  let pc = f.pc and at = f.at and sp = f.sp in
  let saved = Array.copy f.stack in
  f.sp <- 0;
  f.stack.(0) <- Obj exn; f.sp <- 1;
  f.pc <- c.filter;
  let r = match run f with Frame.Filtered b -> b | _ -> false | exception Thrown _ -> false in
  Array.blit saved 0 f.stack 0 (Array.length saved);
  f.pc <- pc; f.at <- at; f.sp <- sp;
  r

(* the instructions from f.pc; [until] (exec's, else -1): to the one
 * at that index, alone or after its prefix *)
and loop (until : int) (f : Frame.frame) : Frame.outcome =
  let push v = f.stack.(f.sp) <- v; f.sp <- f.sp + 1 in
  let pop () = f.sp <- f.sp - 1; f.stack.(f.sp) in
  let pop_n n = let a = Array.sub f.stack (f.sp - n) n in f.sp <- f.sp - n; a in
  let ctx = Types.ctx_of f.meth in
  let resolve tok (make : unit -> resolved) : resolved =
    match Hashtbl.find_opt f.meth.cache tok with
    | Some r -> r
    | None -> let r = make () in Hashtbl.replace f.meth.cache tok r; r in
  let typ tok = match resolve tok (fun () -> R_type (Types.typ_of_token ctx tok)) with
    | R_type t -> t | _ -> assert false in
  let meth tok = match resolve tok (fun () -> R_meth (Types.meth_of_token ctx tok)) with
    | R_meth m -> m | _ -> assert false in
  let field tok = match resolve tok (fun () -> R_field (Types.field_of_token ctx tok)) with
    | R_field x -> x | _ -> assert false in
  let args_of (m : meth) =
    pop_n (List.length m.params + if m.static then 0 else 1) in
  let result (m : meth) (v : value) = if m.ret <> T_void then push v in
  let constrained = ref None in
  let rec go () : Frame.outcome =
    let ins = f.code.instrs.(f.pc) in
    f.at <- f.pc;
    f.pc <- f.pc + 1;
    incr Frame.steps;
    (match !Frame.trace with
     | Some say -> say (Printf.sprintf "%s IL_%04x: %s  [%d]" (Frame.name_of f.meth) ins.at ins.name f.sp)
     | None -> ());
    match ins.op with
    | Ret -> Frame.Returned (if f.meth.ret = T_void then Null else pop ())
    | Endfinally -> Frame.End_finally
    | Endfilter -> Frame.Filtered (Arith.truthy (pop ()))
    | op ->
        (match op with
         | Nop | Prefix _ | Break -> ()
         | Ldarg n -> push (copy_value f.args.(n))
         | Ldarga n -> push (Ptr (Slot (f.args, n)))
         | Starg n -> f.args.(n) <- pop ()
         | Ldloc n -> push (copy_value f.locals.(n))
         | Ldloca n -> push (Ptr (Slot (f.locals, n)))
         | Stloc n -> f.locals.(n) <- pop ()
         | Ldnull -> push Null
         | Ldc_i4 n -> push (I4 n)
         | Ldc_i8 n -> push (I8 n)
         | Ldc_r x -> push (R8 x)
         | Dup -> let v = pop () in push v; push (copy_value v)
         | Pop -> ignore (pop ())
         | Call tok ->
             let m = meth tok in
             if m.static then ensure_init m.mcls;
             let a = args_of m in
             let v = match !constrained with
               | Some _ -> constrained := None; invoke m a
               | None -> if m.static then invoke m a else call_virtual_this m a false in
             result m v
         | Callvirt tok ->
             let m = meth tok in
             let a = args_of m in
             (match !constrained with
              | Some t ->
                  constrained := None;
                  (* the `this` a pointer to a T: a value type's own
                   * method on it, or the value boxed; a reference's
                   * value *)
                  if Types.is_value_type t then begin
                    let c = Types.class_of_typ t in
                    match List.find_opt (fun (x : meth) -> x.mname = m.mname && not x.static
                                          && Types.virtual_target c m == x) c.methods with
                    | Some own -> result m (invoke own a)
                    | None -> a.(0) <- box t (deref a.(0)); result m (call_virtual_this m a true)
                  end else begin
                    a.(0) <- deref a.(0);
                    result m (call_virtual_this m a true)
                  end
              | None -> result m (call_virtual_this m a true))
         | Constrained tok -> constrained := Some (typ tok)
         | Newobj tok ->
             let m = meth tok in
             let c = m.mcls in
             ensure_init c;
             let a = pop_n (List.length m.params) in
             (match c.kind with
              | Delegate ->
                  let st = make_store c 0 in
                  (match a.(1) with
                   | Fn fn -> st.native <- N_delegate (a.(0), fn)
                   | _ -> Frame.error "a delegate made of what?");
                  push (Obj st)
              | Struct | Enum ->
                  let cell = [| Vt (make_store c 0) |] in
                  ignore (invoke m (Array.append [| Ptr (Slot (cell, 0)) |] a));
                  push cell.(0)
              | _ when Types.is_value_type (Types.typ_of_cls c) ->
                  (* (a primitive's constructor: none we know) *)
                  Frame.error ("new " ^ c.name)
              | _ ->
                  let o = Obj (make_store c 0) in
                  ignore (invoke m (Array.append [| o |] a));
                  push o)
         | Br t -> f.pc <- t
         | Brfalse t -> if not (Arith.truthy (pop ())) then f.pc <- t
         | Brtrue t -> if Arith.truthy (pop ()) then f.pc <- t
         | Bcmp (c, un, t) -> let b = pop () in let a = pop () in if Arith.test c un a b then f.pc <- t
         | Switch ts ->
             let i = Arith.int_of (pop ()) in
             if i >= 0 && i < Array.length ts then f.pc <- ts.(i)
         | Ceq -> let b = pop () in let a = pop () in push (Arith.bool_v (Arith.test Il.Eq false a b))
         | Cgt un -> let b = pop () in let a = pop () in
             push (Arith.bool_v (match Arith.compare_values un a b with Some k -> k > 0 | None -> un))
         | Clt un -> let b = pop () in let a = pop () in
             push (Arith.bool_v (match Arith.compare_values un a b with Some k -> k < 0 | None -> un))
         | Binop o -> let b = pop () in let a = pop () in push (Arith.binop o a b)
         | Neg -> push (match pop () with
             | I4 n -> I4 (Int32.neg n) | I8 n -> I8 (Int64.neg n) | R8 x -> R8 (-. x)
             | _ -> Frame.error "neg of what is not a number")
         | Not -> push (match pop () with
             | I4 n -> I4 (Int32.lognot n) | I8 n -> I8 (Int64.lognot n)
             | _ -> Frame.error "not of what is not an integer")
         | Conv (k, ovf, un) -> push (Arith.conv k ovf un (pop ()))
         | Conv_r_un -> push (match pop () with
             | I4 n -> R8 (Int64.to_float (Arith.u32 n)) | I8 n -> R8 (Int64.to_float n) | v -> v)
         | Ckfinite -> (match f.stack.(f.sp - 1) with
             | R8 x when Float.is_nan x || Float.abs x = infinity ->
                 Frame.throw_new "System.ArithmeticException" "Function does not accept floating point Not-a-Number values."
             | _ -> ())
         | Ldstr tok ->
             let row = Metadata.token_row tok in
             push (match Hashtbl.find_opt ctx.im.strings row with
                 | Some s -> s
                 | None -> let s = Str (Image.user_string ctx.im.img row) in
                   Hashtbl.replace ctx.im.strings row s; s)
         | Ldfld tok ->
             let fd = field tok in
             let o = pop () in
             if fd.fstatic then (ignore o; let st = statics fd in push (read st fd.off fd.roff fd.ftype))
             else let st, so, ro = view o in push (read st (so + fd.off) (ro + fd.roff) fd.ftype)
         | Ldflda tok ->
             let fd = field tok in
             let st, so, ro = view (pop ()) in
             push (Ptr (match fd.ftype with
                 | T_value c -> Inside (st, so + fd.off, ro + fd.roff, c)
                 | t when is_ref t -> Slot (st.r, ro + fd.roff)
                 | t -> Bytes (st, so + fd.off, t)))
         | Stfld tok ->
             let fd = field tok in
             let v = pop () in
             let st, so, ro = view (pop ()) in
             write st (so + fd.off) (ro + fd.roff) fd.ftype v
         | Ldsfld tok -> let fd = field tok in let st = statics fd in push (read st fd.off fd.roff fd.ftype)
         | Ldsflda tok ->
             let fd = field tok in
             let st = statics fd in
             push (Ptr (match fd.ftype with
                 | T_value c -> Inside (st, fd.off, fd.roff, c)
                 | t when is_ref t -> Slot (st.r, fd.roff)
                 | t -> Bytes (st, fd.off, t)))
         | Stsfld tok -> let fd = field tok in let v = pop () in write (statics fd) fd.off fd.roff fd.ftype v
         | Newarr tok ->
             let e = typ tok in
             let n = Arith.int_of (pop ()) in
             if n < 0 then Frame.overflow ();
             push (Obj (make_store (Types.array_class e) n))
         | Ldlen -> (match pop () with Obj st -> push (Arith.i4 st.len) | Null -> Frame.null_ref () | _ -> Frame.error "ldlen of what?")
         | Ldelema _ ->
             let i = pop () in
             let st, so, ro, e = element (pop ()) i in
             push (Ptr (match e with
                 | T_value c -> Inside (st, so, ro, c)
                 | t when is_ref t -> Slot (st.r, ro)
                 | t -> Bytes (st, so, t)))
         | Ldelem _ | Ldelem_any _ ->
             let i = pop () in
             let st, so, ro, e = element (pop ()) i in
             push (read st so ro e)
         | Stelem _ | Stelem_any _ ->
             let v = pop () in
             let i = pop () in
             let st, so, ro, e = element (pop ()) i in
             (match v, e with
              | (Obj o), T_class k when not (instance_of o.cls k) ->
                  Frame.throw_new "System.ArrayTypeMismatchException"
                    "Attempted to access an element as a type incompatible with the array."
              | _ -> ());
             write st so ro e v
         | Ldind _ | Ldobj _ -> push (deref (pop ()))
         | Stind _ | Stobj _ -> let v = pop () in assign (pop ()) v
         | Cpobj _ -> let src = pop () in assign (pop ()) (deref src)
         | Initobj tok ->
             let t = typ tok in
             (match pop () with
              | Ptr (Slot (a, i)) -> a.(i) <- zero t
              | Ptr (Bytes (st, off, t)) -> store_at st.s off t (zero t)
              | Ptr (Inside (st, so, ro, c)) ->
                  Bytes.fill st.s so c.nbytes '\000'; Array.fill st.r ro c.nrefs Null
              | _ -> Frame.error "initobj of what?")
         | Box tok -> let t = typ tok in push (box t (pop ()))
         | Unbox_any tok ->
             let t = typ tok in
             let v = pop () in
             if Types.is_value_type t then push (unbox t v)
             else (match v with
                 | Null -> push Null
                 | v -> let c = Types.class_of_typ t in
                   if instance_of (class_of_value v) c then push v else Frame.invalid_cast (class_of_value v) c)
         | Unbox tok ->
             let t = typ tok in
             (match pop () with
              | Obj st ->
                  let c = Types.class_of_typ t in
                  if st.cls != c then Frame.invalid_cast st.cls c;
                  push (Ptr (match t with T_value c -> Inside (st, 0, 0, c) | t -> Bytes (st, 0, t)))
              | Null -> Frame.null_ref ()
              | _ -> Frame.error "unbox of what?")
         | Castclass tok ->
             let c = Types.class_of_typ (typ tok) in
             (match f.stack.(f.sp - 1) with
              | Null -> ()
              | v -> let k = class_of_value v in if not (instance_of k c) then Frame.invalid_cast k c)
         | Isinst tok ->
             let c = Types.class_of_typ (typ tok) in
             (match pop () with
              | Null -> push Null
              | v -> push (if instance_of (class_of_value v) c then v else Null))
         | Throw ->
             (match pop () with
              | Obj st -> Frame.throw st
              | Null -> Frame.null_ref ()
              | _ -> Frame.error "Frame.throw of what is not an exception")
         | Rethrow -> (match f.caught with Some st -> Frame.throw st | None -> Frame.error "rethrow outside a catch")
         | Leave t ->
             (* the finally blocks of the trys left, the innermost first *)
             Array.iter (fun c ->
                 if c.ckind = 2 && f.at >= c.tstart && f.at < c.tend
                    && not (t >= c.tstart && t < c.tend) then run_finally f c.hstart)
               f.code.clauses;
             f.sp <- 0;
             f.pc <- t
         | Ldtoken tok when Metadata.token_table tok = Metadata.t_field ->
             (* { 5, 3, 8 }: the field's bytes, in the file *)
             let img = ctx.im.img in
             let t = Metadata.t_field_rva in
             let rec find r =
               if r > img.rows.(t) then Frame.error "ldtoken of a field without data"
               else if Image.get img t r "Field" = Metadata.token_row tok then
                 Data (img.file, Image.offset img (Image.get img t r "RVA"))
               else find (r + 1) in
             push (find 1)
         | Ldtoken tok -> push (Handle (typ tok))
         | Ldftn tok -> push (Fn (meth tok))
         | Ldvirtftn tok ->
             let m = meth tok in
             let o = pop () in
             push (Fn (Types.virtual_target (class_of_value o) m))
         | Sizeof tok -> let b, _ = footprint (typ tok) in push (Arith.i4 b)
         | Jmp _ | Calli _ | Refanyval _ | Mkrefany _ | Refanytype | Arglist | Localloc
         | Cpblk | Initblk ->
             Frame.error (Printf.sprintf "%s IL_%04x: %s, not in mini-dotnet" (Frame.name_of f.meth) ins.at ins.name)
         | Ret | Endfinally | Endfilter -> assert false);
        if until >= 0 && f.at >= until then Frame.Returned Null else go () in
  go ()

(* the JIT's call-outs: the instruction at [i] of m's code run on the
 * operands, its result the value it pushes (Null if none) *)
let exec (m : meth) (code : code) (i : int) (operands : value array) : value =
  let n = Array.length operands in
  let stack = Array.make (n + 1) Null in
  Array.blit operands 0 stack 0 n;
  (* (a constrained. prefix run first: the callvirt is told its type) *)
  let start = if i > 0 && (match code.instrs.(i - 1).op with Constrained _ -> true | _ -> false) then i - 1 else i in
  let (f : Frame.frame) = { meth = m; code; args = [||]; locals = [||]; stack; sp = n;
                            pc = start; at = start; caught = None } in
  ignore (loop i f);
  if f.sp > 0 then f.stack.(0) else Null

(* OPTIMIZATION (call-outs): the instructions the JIT's code asks for
 * most, each made once for its call-out, its token resolved at its
 * first run (a class loaded then, as the interpreter would); the
 * others by exec. A static field read by the counter of
 * jit/objects.cs took 350 ns by exec, the loop set up for one
 * instruction (its closures).
 * old: exec for every call-out *)
let once (make : unit -> 'a) : unit -> 'a =
  let cell = ref None in
  fun () -> match !cell with
    | Some x -> x
    | None -> let x = make () in cell := Some x; x

let call_out (m : meth) (code : code) (i : int) : value array -> value =
  let ctx = Types.ctx_of m in
  match code.instrs.(i).op with
  | Ldsfld tok ->
      let fd = once (fun () -> Types.field_of_token ctx tok) in
      fun _ -> let fd = fd () in read (statics fd) fd.off fd.roff fd.ftype
  | Stsfld tok ->
      let fd = once (fun () -> Types.field_of_token ctx tok) in
      fun a -> let fd = fd () in write (statics fd) fd.off fd.roff fd.ftype a.(0); Null
  | Stfld tok ->
      let fd = once (fun () -> Types.field_of_token ctx tok) in
      fun a -> let fd = fd () in let st, so, ro = view a.(0) in
        write st (so + fd.off) (ro + fd.roff) fd.ftype a.(1); Null
  | Call tok ->
      let callee = once (fun () -> Types.meth_of_token ctx tok) in
      fun a -> let c = callee () in
        if c.static then (ensure_init c.mcls; invoke c a) else call_virtual_this c a false
  | Callvirt _ when i > 0 && (match code.instrs.(i - 1).op with Constrained _ -> true | _ -> false) -> exec m code i
  | Callvirt tok ->
      let callee = once (fun () -> Types.meth_of_token ctx tok) in
      fun a -> call_virtual_this (callee ()) a true
  | Newobj tok ->
      let ctor = once (fun () -> Types.meth_of_token ctx tok) in
      fun a -> let c = ctor () in
        (match c.mcls.kind with
         | Class when not (Types.is_value_type (Types.typ_of_cls c.mcls)) ->
             ensure_init c.mcls;
             let o = Obj (make_store c.mcls 0) in
             ignore (invoke c (Array.append [| o |] a));
             o
         | _ -> exec m code i a)
  | _ -> exec m code i

let call_method (name : string) (v : value) : value =
  let c = class_of_value v in
  let obj = Types.find_class "System.Object" [||] in
  let m = List.find (fun (m : meth) -> m.mname = name) obj.methods in
  let target = Types.virtual_target c m in
  let this = match v with
    | Vt st -> (match target.def with Some _ -> Ptr (Slot ([| Vt st |], 0)) | None -> v)
    | Obj st when Types.is_value_type (Types.typ_of_cls c) && target.def <> None -> Ptr (Inside (st, 0, 0, c))
    | v -> v in
  invoke target [| this |]

let to_string (v : value) : string =
  match v with
  | Null -> ""
  | Str s -> s
  | I4 _ | I8 _ | R8 _ -> Library.format T_i4 v
  | v -> (match call_method "ToString" v with Str s -> s | Null -> "" | _ -> Frame.error "ToString's result")

let install () : unit =
  Frame.filter_hook := run_filter;
  let h = Library.hooks in
  h.to_string <- to_string;
  h.equals <- (fun a b ->
      match a, b with
      | Str x, Str y -> x = y
      | (I4 _ | I8 _ | R8 _), _ -> a = b
      | Null, _ | _, Null -> a == b
      | a, b ->
          let c = class_of_value a in
          let obj = Types.find_class "System.Object" [||] in
          let m = List.find (fun (m : meth) -> m.mname = "Equals") obj.methods in
          Arith.truthy (invoke (Types.virtual_target c m) [| a; b |]));
  h.hash <- (fun v ->
      match v with
      | Str s -> Hashtbl.hash s
      | I4 n -> Int32.to_int n
      | I8 _ | R8 _ -> Hashtbl.hash v
      | Null -> 0
      | v -> Arith.int_of (call_method "GetHashCode" v));
  h.throw <- Frame.throw_new;
  h.instance <- Types.find_class

let run_main (im : image) (argv : string list) : int =
  let tok = im.img.entry_point in
  if tok = 0 then Frame.error "no entry point: a library, not a program";
  let m = Types.meth_of_def im (Metadata.token_row tok) in
  ensure_init m.mcls;
  let args =
    if m.params = [] then [||]
    else begin
      let st = make_store (Types.array_class (T_class (string_class ()))) (List.length argv) in
      List.iteri (fun i a -> st.r.(i) <- Str a) argv;
      [| Obj st |]
    end in
  match invoke m args with
  | I4 n -> Int32.to_int n
  | _ -> 0
