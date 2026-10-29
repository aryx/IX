(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Machine.mli *)

open Value

exception Error of string
exception Unhandled of string * string

let trace : (string -> unit) option ref = ref None
let steps = ref 0

let error (s : string) = raise (Error s)

type frame = {
  meth : meth;
  code : code;
  args : value array;
  locals : value array;
  stack : value array;
  mutable sp : int;
  mutable pc : int;              (* the next instruction *)
  mutable at : int;              (* the one running *)
  mutable caught : store option; (* the exception of the catch running: rethrow's *)
}

(* the frames running, the innermost first *)
let frames : frame list ref = ref []

(* how a run of a method's instructions ends *)
type outcome = Returned of value | End_finally | Filtered of bool

let name_of (m : meth) : string = m.mcls.name ^ "::" ^ m.mname

(* ------------------------------------------------------------------ *)
(* Exceptions *)
(* ------------------------------------------------------------------ *)

(* pass 1's choice: the frame and the clause that will catch, a filter
 * having said yes *)
let chosen : (frame * int) option ref = ref None

(* a filter run: in its frame, as that frame stands, the exception its
 * argument; true if it takes it (an exception in it: false) *)
let filter_hook : (frame -> clause -> store -> bool) ref = ref (fun _ _ _ -> false)

(* pass 1: which frame's clause will catch it? Nothing is unwound; a
 * filter's code is run to say *)
let handled (exn : store) : bool =
  chosen := None;
  let rec frames_from l = match l with
    | [] -> false
    | f :: rest ->
        let rec clauses i =
          if i >= Array.length f.code.clauses then frames_from rest
          else
            let c = f.code.clauses.(i) in
            if f.at >= c.tstart && f.at < c.tend
               && (match c.ckind, c.catch with
                   | 0, Some k -> subclass exn.cls k
                   | 1, _ -> !filter_hook f c exn
                   | _ -> false)
            then (chosen := Some (f, i); true)
            else clauses (i + 1) in
        clauses 0 in
  frames_from !frames

let message (st : store) : string =
  let rec find (c : cls) = match List.find_opt (fun (f : field) -> f.fname = "_message") c.fields with
    | Some f -> (match st.r.(f.roff) with Str s -> s | _ -> "")
    | None -> (match c.parent with Some p -> find p | None -> "") in
  find st.cls

let throw (exn : store) : 'a =
  if handled exn then raise (Thrown exn)
  else raise (Unhandled (exn.cls.name, message exn))

(* an exception of the library's, made by the machine *)
let throw_new (name : string) (msg : string) : 'a =
  let c = Types.find_class name [||] in
  let st = make_store c 0 in
  let rec set (c : cls) = match List.find_opt (fun (f : field) -> f.fname = "_message") c.fields with
    | Some f -> st.r.(f.roff) <- Str msg
    | None -> (match c.parent with Some p -> set p | None -> ()) in
  set c;
  throw st

let null_ref () = throw_new "System.NullReferenceException" "Object reference not set to an instance of an object."
let out_of_range () = throw_new "System.IndexOutOfRangeException" "Index was outside the bounds of the array."
let overflow () = throw_new "System.OverflowException" "Arithmetic operation resulted in an overflow."
let invalid_cast (from : cls) (to_ : cls) =
  throw_new "System.InvalidCastException"
    ("Unable to cast object of type '" ^ from.name ^ "' to type '" ^ to_.name ^ "'.")

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
  | _ -> error "a struct expected"

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
      | Null -> null_ref ()
      | _ -> error "a pointer to a number used as an object")
  | Ptr (Inside (st, so, ro, _)) -> (st, so, ro)
  | Null -> null_ref ()
  | _ -> error "not an object"

let copy_value (v : value) : value = match v with Vt st -> Vt (copy st) | v -> v

let deref (p : value) : value =
  match p with
  | Ptr (Slot (a, i)) -> copy_value a.(i)
  | Ptr (Bytes (st, off, t)) -> load st.s off t
  | Ptr (Inside (st, so, ro, c)) -> extract st so ro c
  | Null -> null_ref ()
  | _ -> error "not a pointer"

let assign (p : value) (v : value) : unit =
  match p with
  | Ptr (Slot (a, i)) -> a.(i) <- v
  | Ptr (Bytes (st, off, t)) -> store_at st.s off t v
  | Ptr (Inside (st, so, ro, _)) -> blit v st so ro
  | Null -> null_ref ()
  | _ -> error "not a pointer"

let element_type (st : store) : typ =
  match st.cls.element with Some e -> e | None -> error "not an array"

let element (v : value) (i : value) : store * int * int * typ =
  let st = match v with Obj st -> st | Null -> null_ref () | _ -> error "not an array" in
  let i = match i with I4 n -> Int32.to_int n | I8 n -> Int64.to_int n | _ -> error "an index" in
  if i < 0 || i >= st.len then out_of_range ();
  let e = element_type st in
  let b, r = footprint e in
  (st, i * b, i * r, e)

(* ------------------------------------------------------------------ *)
(* Numbers *)
(* ------------------------------------------------------------------ *)

let i4 (n : int) : value = I4 (Int32.of_int n)
let bool_v (b : bool) : value = if b then I4 Int32.one else I4 Int32.zero

let truthy (v : value) : bool =
  match v with
  | I4 n -> Int32.compare n Int32.zero <> 0
  | I8 n -> Int64.compare n Int64.zero <> 0
  | R8 f -> f <> 0.0
  | Null -> false
  | _ -> true

let int_of (v : value) : int =
  match v with
  | I4 n -> Int32.to_int n
  | I8 n -> Int64.to_int n
  | _ -> error "an integer expected"

(* unsigned, as an int64 *)
let u32 (n : int32) : int64 = Int64.logand (Int64.of_int32 n) 0xFFFFFFFFL

let ucompare64 (a : int64) (b : int64) : int =
  Int64.compare (Int64.add a Int64.min_int) (Int64.add b Int64.min_int)

(* a comparison of two values; None when unordered (a NaN) *)
let compare_values (un : bool) (a : value) (b : value) : int option =
  match a, b with
  | I4 x, I4 y -> Some (if un then Int64.compare (u32 x) (u32 y) else Int32.compare x y)
  | I8 x, I8 y -> Some (if un then ucompare64 x y else Int64.compare x y)
  | I4 x, I8 y -> Some (Int64.compare (Int64.of_int32 x) y)
  | I8 x, I4 y -> Some (Int64.compare x (Int64.of_int32 y))
  | R8 x, R8 y -> if Float.is_nan x || Float.is_nan y then None else Some (compare x y)
  | Null, Null -> Some 0
  | Null, _ -> Some (-1)
  | _, Null -> Some 1
  | Obj x, Obj y -> Some (if x == y then 0 else 1)
  | Str x, Str y -> Some (if x == y then 0 else 1)
  | Fn x, Fn y -> Some (if x == y then 0 else 1)
  | _ -> Some 1

let test (c : Il.cmp) (un : bool) (a : value) (b : value) : bool =
  match compare_values un a b with
  | None -> un && c <> Il.Eq || c = Il.Ne
  | Some k ->
      match c with
      | Il.Eq -> k = 0 | Il.Ne -> k <> 0 | Il.Ge -> k >= 0
      | Il.Gt -> k > 0 | Il.Le -> k <= 0 | Il.Lt -> k < 0

let divide_by_zero () = throw_new "System.DivideByZeroException" "Attempted to divide by zero."

let binop (op : Il.binop) (a : value) (b : value) : value =
  match a, b with
  | I4 x, I4 y -> (
      match op with
      | Add -> I4 (Int32.add x y) | Sub -> I4 (Int32.sub x y) | Mul -> I4 (Int32.mul x y)
      | Div ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else if Int32.compare x Int32.min_int = 0 && Int32.compare y Int32.minus_one = 0 then overflow ()
          else I4 (Int32.div x y)
      | Rem ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else if Int32.compare y Int32.minus_one = 0 then I4 Int32.zero
          else I4 (Int32.rem x y)
      | Div_un ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else I4 (Int64.to_int32 (Int64.div (u32 x) (u32 y)))
      | Rem_un ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else I4 (Int64.to_int32 (Int64.rem (u32 x) (u32 y)))
      | And -> I4 (Int32.logand x y) | Or -> I4 (Int32.logor x y) | Xor -> I4 (Int32.logxor x y)
      | Shl -> I4 (Int32.shift_left x (Int32.to_int y land 31))
      | Shr -> I4 (Int32.shift_right x (Int32.to_int y land 31))
      | Shr_un -> I4 (Int32.shift_right_logical x (Int32.to_int y land 31))
      | Add_ovf | Sub_ovf | Mul_ovf ->
          let r = (match op with Add_ovf -> Int64.add | Sub_ovf -> Int64.sub | _ -> Int64.mul)
                    (Int64.of_int32 x) (Int64.of_int32 y) in
          if Int64.compare r (Int64.of_int32 Int32.max_int) > 0 || Int64.compare r (Int64.of_int32 Int32.min_int) < 0
          then overflow () else I4 (Int64.to_int32 r)
      | Add_ovf_un | Sub_ovf_un | Mul_ovf_un ->
          let r = (match op with Add_ovf_un -> Int64.add | Sub_ovf_un -> Int64.sub | _ -> Int64.mul)
                    (u32 x) (u32 y) in
          if Int64.compare r 0xFFFFFFFFL > 0 || Int64.compare r 0L < 0 then overflow ()
          else I4 (Int64.to_int32 r))
  | (I8 _ | I4 _), (I8 _ | I4 _) -> (
      let w v = match v with I8 n -> n | I4 n -> Int64.of_int32 n | _ -> assert false in
      let x = w a and y = w b in
      match op with
      | Shl -> I8 (Int64.shift_left x (int_of b land 63))
      | Shr -> I8 (Int64.shift_right x (int_of b land 63))
      | Shr_un -> I8 (Int64.shift_right_logical x (int_of b land 63))
      | Add | Add_ovf | Add_ovf_un -> I8 (Int64.add x y)
      | Sub | Sub_ovf | Sub_ovf_un -> I8 (Int64.sub x y)
      | Mul | Mul_ovf | Mul_ovf_un -> I8 (Int64.mul x y)
      | Div | Div_un -> if Int64.compare y 0L = 0 then divide_by_zero () else I8 (Int64.div x y)
      | Rem | Rem_un -> if Int64.compare y 0L = 0 then divide_by_zero () else I8 (Int64.rem x y)
      | And -> I8 (Int64.logand x y) | Or -> I8 (Int64.logor x y) | Xor -> I8 (Int64.logxor x y))
  | R8 x, R8 y -> (
      match op with
      | Add -> R8 (x +. y) | Sub -> R8 (x -. y) | Mul -> R8 (x *. y)
      | Div -> R8 (x /. y) | Rem -> R8 (Float.rem x y)
      | _ -> error "a float in an integer's operation")
  | _ -> error "an arithmetic on what is not a number"

let conv (k : Il.kind) (ovf : bool) (un : bool) (v : value) : value =
  (* the value as an int64, and a float if it is one *)
  let wide = match v with
    | I4 n -> if un then u32 n else Int64.of_int32 n
    | I8 n -> n
    | R8 f -> Int64.of_float f
    | Ptr _ | Obj _ | Str _ | Null | Fn _ -> 0L
    | _ -> error "a conversion of what is not a number" in
  let check lo hi =
    if ovf && (Int64.compare wide lo < 0 || Int64.compare wide hi > 0
               || (match v with R8 f -> Float.is_nan f | _ -> false)) then overflow () in
  let small bits signed =
    let m = Int64.of_int ((1 lsl bits) - 1) in
    let x = Int64.logand wide m in
    let x = if signed && Int64.compare x (Int64.of_int (1 lsl (bits - 1))) >= 0 then Int64.sub x (Int64.add m 1L) else x in
    I4 (Int64.to_int32 x) in
  match k with
  | K_i1 -> check (-128L) 127L; small 8 true
  | K_u1 -> check 0L 255L; small 8 false
  | K_i2 -> check (-32768L) 32767L; small 16 true
  | K_u2 -> check 0L 65535L; small 16 false
  | K_i4 | K_i -> check (-2147483648L) 2147483647L;
      (match v with Ptr _ | Obj _ | Str _ | Fn _ -> v | _ -> I4 (Int64.to_int32 wide))
  | K_u4 | K_u -> check 0L 4294967295L;
      (match v with Ptr _ | Obj _ | Str _ | Fn _ -> v | _ -> I4 (Int64.to_int32 wide))
  | K_i8 -> (match v with I4 n when not un -> I8 (Int64.of_int32 n) | _ -> I8 wide)
  | K_u8 -> (match v with I4 n -> I8 (u32 n) | _ -> I8 wide)
  | K_r4 -> let f = (match v with R8 f -> f | I4 n when un -> Int64.to_float (u32 n) | _ -> Int64.to_float wide) in
      R8 (Int32.float_of_bits (Int32.bits_of_float f))
  | K_r8 -> R8 (match v with R8 f -> f | _ -> Int64.to_float wide)
  | K_ref -> v

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
  | Null -> null_ref ()
  | _ -> error "the class of a pointer"

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
  | Null -> null_ref ()
  | Obj st ->
      let c = Types.class_of_typ t in
      if st.cls != c then invalid_cast st.cls c;
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
  | None -> error ("no static storage for " ^ f.fname)

(* ------------------------------------------------------------------ *)
(* Calls *)
(* ------------------------------------------------------------------ *)

and invoke (m : meth) (args : value array) : value =
  match m.body with
  | Native f -> f args
  | Runtime ->
      if m.mname = "Invoke" then begin
        let st = match args.(0) with Obj st -> st | Null -> null_ref () | _ -> error "a delegate" in
        match st.native with
        | N_delegate (target, fn) ->
            let rest = Array.sub args 1 (Array.length args - 1) in
            if fn.static then invoke fn rest
            else call_virtual_this fn (Array.append [| target |] rest) false
        | _ -> error "a delegate without its method"
      end
      else error (name_of m ^ ": a runtime method mini-dotnet has not")
  | No_body -> error (name_of m ^ ": abstract, called")
  | Il_body _ | Decoded _ -> run_method m args

(* a call whose `this` is in args.(0): to a value type's method, a
 * pointer to the struct (a box's inside) *)
and call_virtual_this (m : meth) (args : value array) (virt : bool) : value =
  let this = args.(0) in
  (match this with Null -> null_ref () | _ -> ());
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
  let code = Types.code m in
  let f = { meth = m; code; args;
            locals = Array.map zero code.locals;
            stack = Array.make (code.max_stack + 1) Null; sp = 0; pc = 0; at = 0; caught = None } in
  frames := f :: !frames;
  match run f with
  | Returned v -> frames := List.tl !frames; v
  | End_finally | Filtered _ -> error "endfinally or endfilter outside their block"
  | exception e -> frames := List.tl !frames; raise e

(* the instructions run, an exception caught by this frame's clauses *)
and run (f : frame) : outcome =
  match loop f with
  | o -> o
  | exception Thrown exn ->
      let at = f.at in
      let rec search i =
        if i >= Array.length f.code.clauses then raise (Thrown exn)
        else
          let c = f.code.clauses.(i) in
          if at >= c.tstart && at < c.tend then
            let mine = match !chosen with Some (g, j) -> g == f && j = i | None -> false in
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

and run_finally (f : frame) (start : int) : unit =
  let pc = f.pc and at = f.at in
  f.sp <- 0;
  f.pc <- start;
  (match run f with End_finally -> () | _ -> error "a return in a finally");
  f.pc <- pc; f.at <- at

and run_filter (f : frame) (c : clause) (exn : store) : bool =
  let pc = f.pc and at = f.at and sp = f.sp in
  let saved = Array.copy f.stack in
  f.sp <- 0;
  f.stack.(0) <- Obj exn; f.sp <- 1;
  f.pc <- c.filter;
  let r = match run f with Filtered b -> b | _ -> false | exception Thrown _ -> false in
  Array.blit saved 0 f.stack 0 (Array.length saved);
  f.pc <- pc; f.at <- at; f.sp <- sp;
  r

and loop (f : frame) : outcome =
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
  let rec go () : outcome =
    let ins = f.code.instrs.(f.pc) in
    f.at <- f.pc;
    f.pc <- f.pc + 1;
    incr steps;
    (match !trace with
     | Some say -> say (Printf.sprintf "%s IL_%04x: %s  [%d]" (name_of f.meth) ins.at ins.name f.sp)
     | None -> ());
    match ins.op with
    | Ret -> Returned (if f.meth.ret = T_void then Null else pop ())
    | Endfinally -> End_finally
    | Endfilter -> Filtered (truthy (pop ()))
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
                   | _ -> error "a delegate made of what?");
                  push (Obj st)
              | Struct | Enum ->
                  let cell = [| Vt (make_store c 0) |] in
                  ignore (invoke m (Array.append [| Ptr (Slot (cell, 0)) |] a));
                  push cell.(0)
              | _ when Types.is_value_type (Types.typ_of_cls c) ->
                  (* (a primitive's constructor: none we know) *)
                  error ("new " ^ c.name)
              | _ ->
                  let o = Obj (make_store c 0) in
                  ignore (invoke m (Array.append [| o |] a));
                  push o)
         | Br t -> f.pc <- t
         | Brfalse t -> if not (truthy (pop ())) then f.pc <- t
         | Brtrue t -> if truthy (pop ()) then f.pc <- t
         | Bcmp (c, un, t) -> let b = pop () in let a = pop () in if test c un a b then f.pc <- t
         | Switch ts ->
             let i = int_of (pop ()) in
             if i >= 0 && i < Array.length ts then f.pc <- ts.(i)
         | Ceq -> let b = pop () in let a = pop () in push (bool_v (test Il.Eq false a b))
         | Cgt un -> let b = pop () in let a = pop () in
             push (bool_v (match compare_values un a b with Some k -> k > 0 | None -> un))
         | Clt un -> let b = pop () in let a = pop () in
             push (bool_v (match compare_values un a b with Some k -> k < 0 | None -> un))
         | Binop o -> let b = pop () in let a = pop () in push (binop o a b)
         | Neg -> push (match pop () with
             | I4 n -> I4 (Int32.neg n) | I8 n -> I8 (Int64.neg n) | R8 x -> R8 (-. x)
             | _ -> error "neg of what is not a number")
         | Not -> push (match pop () with
             | I4 n -> I4 (Int32.lognot n) | I8 n -> I8 (Int64.lognot n)
             | _ -> error "not of what is not an integer")
         | Conv (k, ovf, un) -> push (conv k ovf un (pop ()))
         | Conv_r_un -> push (match pop () with
             | I4 n -> R8 (Int64.to_float (u32 n)) | I8 n -> R8 (Int64.to_float n) | v -> v)
         | Ckfinite -> (match f.stack.(f.sp - 1) with
             | R8 x when Float.is_nan x || Float.abs x = infinity ->
                 throw_new "System.ArithmeticException" "Function does not accept floating point Not-a-Number values."
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
             let n = int_of (pop ()) in
             if n < 0 then overflow ();
             push (Obj (make_store (Types.array_class e) n))
         | Ldlen -> (match pop () with Obj st -> push (i4 st.len) | Null -> null_ref () | _ -> error "ldlen of what?")
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
                  throw_new "System.ArrayTypeMismatchException"
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
              | _ -> error "initobj of what?")
         | Box tok -> let t = typ tok in push (box t (pop ()))
         | Unbox_any tok ->
             let t = typ tok in
             let v = pop () in
             if Types.is_value_type t then push (unbox t v)
             else (match v with
                 | Null -> push Null
                 | v -> let c = Types.class_of_typ t in
                   if instance_of (class_of_value v) c then push v else invalid_cast (class_of_value v) c)
         | Unbox tok ->
             let t = typ tok in
             (match pop () with
              | Obj st ->
                  let c = Types.class_of_typ t in
                  if st.cls != c then invalid_cast st.cls c;
                  push (Ptr (match t with T_value c -> Inside (st, 0, 0, c) | t -> Bytes (st, 0, t)))
              | Null -> null_ref ()
              | _ -> error "unbox of what?")
         | Castclass tok ->
             let c = Types.class_of_typ (typ tok) in
             (match f.stack.(f.sp - 1) with
              | Null -> ()
              | v -> let k = class_of_value v in if not (instance_of k c) then invalid_cast k c)
         | Isinst tok ->
             let c = Types.class_of_typ (typ tok) in
             (match pop () with
              | Null -> push Null
              | v -> push (if instance_of (class_of_value v) c then v else Null))
         | Throw ->
             (match pop () with
              | Obj st -> throw st
              | Null -> null_ref ()
              | _ -> error "throw of what is not an exception")
         | Rethrow -> (match f.caught with Some st -> throw st | None -> error "rethrow outside a catch")
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
               if r > img.rows.(t) then error "ldtoken of a field without data"
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
         | Sizeof tok -> let b, _ = footprint (typ tok) in push (i4 b)
         | Jmp _ | Calli _ | Refanyval _ | Mkrefany _ | Refanytype | Arglist | Localloc
         | Cpblk | Initblk ->
             error (Printf.sprintf "%s IL_%04x: %s, not in mini-dotnet" (name_of f.meth) ins.at ins.name)
         | Ret | Endfinally | Endfilter -> assert false);
        go () in
  go ()

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
  | v -> (match call_method "ToString" v with Str s -> s | Null -> "" | _ -> error "ToString's result")

let install () : unit =
  filter_hook := run_filter;
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
          truthy (invoke (Types.virtual_target c m) [| a; b |]));
  h.hash <- (fun v ->
      match v with
      | Str s -> Hashtbl.hash s
      | I4 n -> Int32.to_int n
      | I8 _ | R8 _ -> Hashtbl.hash v
      | Null -> 0
      | v -> int_of (call_method "GetHashCode" v));
  h.throw <- throw_new;
  h.instance <- Types.find_class

let run_main (im : image) (argv : string list) : int =
  let tok = im.img.entry_point in
  if tok = 0 then error "no entry point: a library, not a program";
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
