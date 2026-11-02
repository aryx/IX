(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cil_exprs.mli *)

open Tree
open Tree_helpers
open Cil_types
module S = Signature
module W = Writer
module Str = Cil_strings

(*****************************************************************************)
(* The file's globals *)
(*****************************************************************************)

(* each global: its name, type, field (an array: of one element for
 * all but an array) *)
let globals : (string * typ * int) list ref = ref []

let reset () : unit =
  Str.reset ();
  globals := []

let global (c : c) (line : int) (name : string) (t : typ) : int =
  match List.find_opt (fun ((n, _, _) : string * typ * int) -> n = name) !globals with
  | Some (_, _, f) -> f
  | None ->
      let f = W.field_def c.w c.cls name 0x0016 (S.SzArray (cts c line (base t))) in
      globals := (name, t, f) :: !globals;
      f

(*****************************************************************************)
(* A function being compiled *)
(*****************************************************************************)

(* a local's or a parameter's place: its slot, or a local holding an
 * array (a C array, or one element: a variable whose address is taken) *)
type var = Slot of bool * int | Boxed of int | Array_var of int

type fn = {
  c : c;
  k : code;
  fname : string;
  vars : (string, var) Hashtbl.t;     (* by key *)
}

(* a local's key: two blocks' may share an offset *)
let key (s : sym) (off : int) (t : typ) : string =
  Printf.sprintf "%s@%d:%s%d" s.name off (tname t.etype) t.width

(* where an l-value is: what is pushed before its value (re-pushed as
 * often as asked: a temporary's, or a variable's) *)
type place =
  | Pslot of bool * int               (* an argument, a local *)
  | Pelem of (unit -> unit) * typ     (* an array and an index; the element's type *)
  | Pfield of (unit -> unit) * int    (* an object; its field *)
  | Pptr of (unit -> unit) * S.t      (* a Ptr; what it points to *)

let is_ptr (t : typ) : bool = t.etype = Tind
let is_float (t : typ) : bool = t.etype = Tfloat || t.etype = Tdouble
let is_wide (t : typ) : bool = t.etype = Tvlong || t.etype = Tuvlong

let load (f : fn) (p : place) : unit =
  match p with
  | Pslot (true, i) -> emit f.k (Il.Ldarg i)
  | Pslot (false, i) -> emit f.k (Il.Ldloc i)
  | Pelem (pre, t) -> pre (); emit f.k (Il.Ldelem (load_kind f.c 0 t))
  | Pfield (pre, fld) -> pre (); emit f.k (Il.Ldfld fld)
  | Pptr (pre, t) -> pre (); emit f.k (Il.Call (ptr_get f.c t))

let store (f : fn) (p : place) (v : unit -> unit) : unit =
  match p with
  | Pslot (true, i) -> v (); emit f.k (Il.Starg i)
  | Pslot (false, i) -> v (); emit f.k (Il.Stloc i)
  | Pelem (pre, t) -> pre (); v (); emit f.k (Il.Stelem (store_kind f.c 0 t))
  | Pfield (pre, fld) -> pre (); v (); emit f.k (Il.Stfld fld)
  | Pptr (pre, t) -> pre (); v (); emit f.k (Il.Call (ptr_set f.c t))

(* a char's or short's value as its type keeps it, in an int32 *)
let narrow (k : code) (t : typ) : unit =
  match t.etype with
  | Tchar -> emit k (Il.Conv (Il.K_i1, false, false))
  | Tuchar -> emit k (Il.Conv (Il.K_u1, false, false))
  | Tshort -> emit k (Il.Conv (Il.K_i2, false, false))
  | Tushort -> emit k (Il.Conv (Il.K_u2, false, false))
  | _ -> ()

(* C's conversion of a number: the stack's int32 (C's int and smaller),
 * int64 or float, to another *)
let conv (k : code) (from : typ) (t : typ) : unit =
  let c (kind : Il.kind) = emit k (Il.Conv (kind, false, false)) in
  let fl = is_float from in
  match t.etype with
  | Tchar | Tuchar | Tshort | Tushort -> narrow k t
  | Tint | Tlong | Tenum | Tuint | Tulong ->
      if fl then c (if typeu t.etype then Il.K_u4 else Il.K_i4)
      else if is_wide from then c Il.K_i4
  | Tvlong | Tuvlong ->
      if fl then c (if t.etype = Tuvlong then Il.K_u8 else Il.K_i8)
      else if not (is_wide from) then
        c (if typeu from.etype then Il.K_u8 else Il.K_i8)
  | Tfloat | Tdouble ->
      let r = if t.etype = Tfloat then Il.K_r4 else Il.K_r8 in
      if (not fl) && typeu from.etype then emit k Il.Conv_r_un;
      c r
  | _ -> ()

(* an operand of a pointer's + that is its offset, though the typing
 * typed it a pointer: a number scaled, converted *)
let rec is_offset (x : expr) : bool =
  match x.e with
  | Const _ -> true
  | Unary (Cast, y) -> not (is_ptr y.t)
  | Binary ((Mul | Lmul | Div | Ldiv | Ashl | Ashr | Lshr), _, _) -> true
  | Binary ((Add | Sub), a, b) -> is_offset a && is_offset b
  | _ -> not (is_ptr x.t)

let const (f : fn) (line : int) (t : typ) (v : int64) : unit =
  match t.etype with
  | Tvlong | Tuvlong -> emit f.k (Il.Ldc_i8 v)
  | Tfloat | Tdouble -> emit f.k (Il.Ldc_r (Int64.to_float v))
  | Tind when v = 0L -> emit f.k Il.Ldnull
  | Tind -> refuse line "an integer made a pointer"
  | _ -> emit f.k (Il.Ldc_i4 (Int64.to_int32 v))

let binop (o : binop) : Il.binop =
  match o with
  | Add -> Il.Add
  | Sub -> Il.Sub
  | Mul | Lmul -> Il.Mul
  | Div -> Il.Div
  | Ldiv -> Il.Div_un
  | Mod -> Il.Rem
  | Lmod -> Il.Rem_un
  | And -> Il.And
  | Or -> Il.Or
  | Xor -> Il.Xor
  | Ashl -> Il.Shl
  | Ashr -> Il.Shr
  | Lshr -> Il.Shr_un
  | _ -> failwith "binop"

(* a function's method, by its name and type: made at its first call
 * or its definition, whichever comes first *)
let func_method (c : c) (line : int) (name : string) (t : typ) : int =
  memo c ("fn " ^ name) (fun () ->
      let m = static (params c line t) (slot c line (link t)) in
      W.method_def c.w c.cls name 0x0096 m)

(* the functions C's library has from .NET or the compiler *)
let builtins = [ "print"; "sprint"; "malloc"; "free"; "_write"; "_exit" ]

(* a function as a value: its delegate, one for the program (kept in a
 * field), so that two are equal as their functions are *)
let delegate_value (f : fn) (line : int) (name : string) (t : typ) : unit =
  if List.mem name builtins then refuse line (name ^ " as a value");
  let c = f.c and k = f.k in
  let d = delegate c line t in
  let fld =
    memo c ("delegate " ^ name) (fun () ->
        W.field_def c.w c.cls ("<fn>" ^ name) 0x0016 d) in
  let l = label k in
  emit k (Il.Ldsfld fld);
  emit k Il.Dup;
  emit k (Il.Brtrue l);
  emit k Il.Pop;
  emit k Il.Ldnull;
  emit k (Il.Ldftn (func_method c line name t));
  emit k (Il.Newobj (delegate_ctor c line t));
  emit k Il.Dup;
  emit k (Il.Stsfld fld);
  place k l

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

let rec expr (f : fn) (n : expr) : unit =
  let k = f.k and c = f.c and line = n.line in
  match n.e with
  | Const v -> const f line n.t v
  | Fconst x -> emit k (Il.Ldc_r x)
  | Name (s, _, _) when n.t.etype = Tfunc -> delegate_value f line s.name n.t
  | Name _ when n.t.etype = Tarray -> refuse line "an array as a value"
  | Name _ | Dot _ -> load f (place_of f n)
  | Unary (Ind, p) when (link p.t).etype = Tfunc -> expr f p
  | Unary (Ind, _) -> load f (place_of f n)
  | Unary (Addr, l) -> address f l
  | Unary (Cast, x) -> cast f x n.t
  | Unary (Neg, x) -> expr f x; emit k Il.Neg
  | Unary (Com, x) -> expr f x; emit k Il.Not
  | Unary (Pos, x) -> expr f x
  | Unary (Not, _) | Binary ((Andand | Oror), _, _) -> truth_value f n
  | Unary ((Preinc | Predec | Postinc | Postdec) as o, l) -> incdec f o l true
  | Binary (Comma, a, b) -> drop f a; expr f b
  | Binary (o, a, b) when is_rel o ->
      compare_value f (operands f o a b) (is_float a.t)
  | Binary (Sub, a, b)
    when is_ptr a.t && is_ptr b.t && not (is_offset a || is_offset b) ->
      (* (the difference's bytes: the typing divides by the size) *)
      let t = pointee c line (link a.t) in
      expr f a; expr f b;
      emit k (Il.Call (ptr_diff c t));
      ldc k (base (link a.t)).width;
      emit k (Il.Binop Il.Mul)
  | Binary ((Add | Sub) as o, a, b) when is_ptr a.t || is_ptr b.t ->
      let p, off = if is_ptr a.t && not (is_offset a) then (a, b) else (b, a) in
      expr f p;
      elements f off (base (link p.t)).width;
      if o = Sub then emit k Il.Neg;
      emit k (Il.Call (ptr_add c (pointee c line (link p.t))))
  | Binary (o, a, b) -> expr f a; expr f b; emit k (Il.Binop (binop o))
  | Assign (None, l, r) ->
      let p = place_of f l in
      store f p (fun () -> assigned f l.t r);
      load f p
  | Assign (Some o, l, r) -> opassign f n o l r; load f (place_of f l)
  | Cond (cnd, a, b) ->
      let other = label k and stop = label k in
      branch f cnd false other;
      expr f a;
      emit k (Il.Br stop);
      place k other;
      expr f b;
      place k stop
  | Call (fn, args) -> call f n fn args true
  | Sizeof _ | Sizeof_type _ | Str _ | Lstr _ | Reg _ | Indreg _ | Elem _ | Typed _ ->
      refuse line "a tree the typing does not leave"

(* a value given to a variable or an argument: a structure's copy *)
and value (f : fn) (n : expr) : unit =
  expr f n;
  if n.t.etype = Tstruct then
    emit f.k (Il.Callvirt (struct_info f.c n.line n.t).sclone)

(* a value given to a place of type t: malloc's, an array of t's
 * elements, whether the typing made the conversion a cast or not *)
and assigned (f : fn) (t : typ) (n : expr) : unit =
  match n.e with
  | Call ({ e = Name (s, _, _); _ }, [ size ]) when s.name = "malloc" && is_ptr t ->
      alloc f t size
  | _ -> value f n

(* malloc(size) given to a t: an array of size's elements, a Ptr to its
 * first *)
and alloc (f : fn) (t : typ) (size : expr) : unit =
  let line = size.line in
  let b = base (link t) in
  if b.etype = Tvoid then refuse line "malloc's memory given no type";
  new_array f.c f.k line b (fun () -> elements f size b.width);
  ldc f.k 0;
  emit f.k (Il.Newobj (ptr_ctor f.c (pointee f.c line b)))

(* n for its effects *)
and drop (f : fn) (n : expr) : unit =
  let k = f.k in
  match n.e with
  | Assign (None, l, r) ->
      let p = place_of f l in
      store f p (fun () -> assigned f l.t r)
  | Assign (Some o, l, r) -> opassign f n o l r
  | Unary ((Preinc | Predec | Postinc | Postdec) as o, l) -> incdec f o l false
  | Unary (Cast, x) -> drop f x
  | Binary (Comma, a, b) -> drop f a; drop f b
  | Call (fn, args) -> call f n fn args false
  | Cond (cnd, a, b) ->
      let other = label k and stop = label k in
      branch f cnd false other;
      drop f a;
      emit k (Il.Br stop);
      place k other;
      drop f b;
      place k stop
  | _ -> expr f n; if n.t.etype <> Tvoid then emit k Il.Pop

(* a pointer's offset, which the typing made bytes (of the pointer's
 * type: the index converted to it, then multiplied), as elements of bw
 * bytes *)
and elements (f : fn) (off : expr) (bw : int) : unit =
  let k = f.k in
  let by (x : expr) (v : int64) =
    let n = Int64.to_int v / bw in
    offset f x;
    if n <> 1 then (ldc k n; emit k (Il.Binop Il.Mul)) in
  let whole (v : int64) = Int64.to_int v mod bw = 0 in
  let power (v : int64) = Int64.shift_left 1L (Int64.to_int v) in
  match off.e with
  | Const v when whole v -> ldc k (Int64.to_int v / bw)
  | Binary ((Mul | Lmul), x, { e = Const v; _ }) when whole v -> by x v
  | Binary ((Mul | Lmul), { e = Const v; _ }, x) when whole v -> by x v
  | Binary (Ashl, x, { e = Const v; _ }) when whole (power v) -> by x (power v)
  | _ -> offset f off; if bw <> 1 then (ldc k bw; emit k (Il.Binop Il.Div))

(* an offset, an int32, though typed a pointer *)
and offset (f : fn) (x : expr) : unit =
  let k = f.k in
  let int32 (t : typ) = if is_wide t then emit k (Il.Conv (Il.K_i4, false, false)) in
  match x.e with
  | Const v -> emit k (Il.Ldc_i4 (Int64.to_int32 v))
  | Unary (Cast, y) when not (is_ptr y.t) -> expr f y; int32 y.t
  | Binary ((Add | Sub | Mul | Lmul | Div | Ldiv | Ashl | Ashr | Lshr) as o, a, b)
    when is_ptr x.t ->
      offset f a; offset f b; emit k (Il.Binop (binop o))
  | _ when is_ptr x.t -> refuse x.line "a pointer as an offset"
  | _ -> expr f x; int32 x.t

(* an l-value's place, its parts computed once *)
and place_of (f : fn) (n : expr) : place =
  let c = f.c and line = n.line in
  match n.e with
  | Name (s, cl, off) -> (
      match cl with
      | Cauto | Cparam -> (
          match Hashtbl.find_opt f.vars (key s off n.t) with
          | Some (Slot (a, i)) -> Pslot (a, i)
          | Some (Boxed i) ->
              Pelem ((fun () -> emit f.k (Il.Ldloc i); ldc f.k 0), n.t)
          | Some (Array_var _) -> refuse line "an array as a value"
          | None -> refuse line ("the variable " ^ s.name ^ ", unseen"))
      | Cextern | Cglobl | Cstatic | Clocal ->
          let fld = global c line (global_name f s cl) n.t in
          Pelem ((fun () -> emit f.k (Il.Ldsfld fld); ldc f.k 0), n.t)
      | _ -> refuse line ("a variable of class " ^ cname cl))
  | Unary (Ind, p) -> Pptr (stash f p, pointee c line (link p.t))
  | Dot (l, o) -> (
      let s = struct_info c line l.t in
      match List.find_opt (fun ((o', _, _) : int * typ * int) -> o' = o) s.fields with
      | Some (_, _, fld) -> Pfield (stash f l, fld)
      | None -> refuse line "a member of an unnamed structure")
  | _ -> refuse line "not an l-value"

(* a static's name: a function's own, or the file's *)
and global_name (f : fn) (s : sym) (cl : cls) : string =
  if cl = Clocal then f.fname ^ "." ^ s.name else s.name

(* n's value, pushed as often as asked: a variable's again, or a
 * temporary's *)
and stash (f : fn) (n : expr) : unit -> unit =
  let slot_var (s : sym) (off : int) =
    match Hashtbl.find_opt f.vars (key s off n.t) with
    | Some (Slot _) -> true
    | _ -> false in
  match n.e with
  | Name (s, (Cauto | Cparam), off) when slot_var s off -> fun () -> expr f n
  | _ ->
      let t = local f.k (slot f.c n.line n.t) in
      expr f n;
      emit f.k (Il.Stloc t);
      fun () -> emit f.k (Il.Ldloc t)

(* an array's: what holds it *)
and array_of (f : fn) (l : expr) : unit =
  let line = l.line in
  match l.e with
  | Name (s, Cstatic, off) when s.name = ".string" ->
      Str.literal_array f.c f.k (Str.literal_bytes line l.t off)
  | Name (s, ((Cauto | Cparam) as cl), off) -> (
      match Hashtbl.find_opt f.vars (key s off l.t) with
      | Some (Boxed i | Array_var i) -> emit f.k (Il.Ldloc i)
      | _ -> refuse line ("the address of " ^ s.name ^ ", a " ^ cname cl))
  | Name (s, cl, _) -> emit f.k (Il.Ldsfld (global f.c line (global_name f s cl) l.t))
  | Dot _ when l.t.etype = Tarray -> load f (place_of f l)
  | Dot _ -> refuse line "the address of a member"
  | _ -> refuse line "an address of this"

(* &l: a Ptr to its array's first element *)
and address (f : fn) (l : expr) : unit =
  let line = l.line in
  match l.e with
  | Name (s, _, _) when l.t.etype = Tfunc -> delegate_value f line s.name l.t
  | Unary (Ind, p) -> expr f p
  | _ ->
      array_of f l;
      ldc f.k 0;
      emit f.k (Il.Newobj (ptr_ctor f.c (pointee f.c line l.t)))

and cast (f : fn) (x : expr) (t : typ) : unit =
  let line = x.line in
  if t.etype = Tvoid then drop f x
  else if is_ptr t then begin
    match x.e with
    | Call ({ e = Name (s, _, _); _ }, [ size ]) when s.name = "malloc" ->
        alloc f t size
    | Const 0L -> emit f.k Il.Ldnull
    | _ when is_ptr x.t && cts f.c line x.t = cts f.c line t -> expr f x
    | _ when is_ptr x.t -> refuse line "a pointer cast to another type"
    | _ -> refuse line "an integer made a pointer"
  end
  else if is_ptr x.t then refuse line "a pointer made an integer"
  else begin
    expr f x;
    conv f.k x.t t
  end

(* x op= y: x converted to the operation's type n.t, the result back *)
and opassign (f : fn) (n : expr) (o : binop) (l : expr) (r : expr) : unit =
  let p = place_of f l in
  if is_ptr l.t then
    store f p (fun () ->
        load f p;
        elements f r (base (link l.t)).width;
        if o = Sub then emit f.k Il.Neg;
        emit f.k (Il.Call (ptr_add f.c (pointee f.c n.line (link l.t)))))
  else
    store f p (fun () ->
        load f p;
        conv f.k l.t n.t;
        expr f r;
        emit f.k (Il.Binop (binop o));
        conv f.k n.t l.t)

and incdec (f : fn) (o : unop) (l : expr) (used : bool) : unit =
  let k = f.k and line = l.line in
  let p = place_of f l in
  let up = o = Preinc || o = Postinc in
  let step () =
    if is_ptr l.t then begin
      ldc k (if up then 1 else -1);
      emit k (Il.Call (ptr_add f.c (pointee f.c line (link l.t))))
    end
    else begin
      if is_wide l.t then emit k (Il.Ldc_i8 1L)
      else if is_float l.t then emit k (Il.Ldc_r 1.0)
      else ldc k 1;
      emit k (Il.Binop (if up then Il.Add else Il.Sub));
      narrow k l.t
    end in
  if used && (o = Postinc || o = Postdec) then begin
    let old = local k (slot f.c line l.t) in
    load f p;
    emit k (Il.Stloc old);
    store f p (fun () -> emit k (Il.Ldloc old); step ());
    emit k (Il.Ldloc old)
  end
  else begin
    store f p (fun () -> load f p; step ());
    if used then load f p
  end

(*****************************************************************************)
(* Conditions *)
(*****************************************************************************)

(* a relation's operands pushed; the comparison of them to make, and
 * whether it is unsigned (for floats: unordered) *)
and operands (f : fn) (o : binop) (a : expr) (b : expr) : Il.cmp * bool =
  let c = f.c and k = f.k and line = a.line in
  let data = is_ptr a.t && (link a.t).etype <> Tfunc in
  let null (x : expr) = match x.e with Const 0L -> true | _ -> false in
  let rel o =
    match o with
    | Eq -> (Il.Eq, false)
    | Ne -> (Il.Ne, true)
    | Lt | Lo -> (Il.Lt, o = Lo)
    | Le | Ls -> (Il.Le, o = Ls)
    | Gt | Hi -> (Il.Gt, o = Hi)
    | Ge | Hs -> (Il.Ge, o = Hs)
    | _ -> failwith "rel" in
  if data && not (null a || null b) then begin
    let t = pointee c line (link a.t) in
    expr f a;
    expr f b;
    match o with
    | Eq | Ne -> emit k (Il.Call (ptr_eq c t)); ldc k 1; rel o
    | _ ->
        emit k (Il.Call (ptr_diff c t));
        ldc k 0;
        (* (an order of pointers is of their indexes, signed) *)
        fst (rel o), false
  end
  else begin
    expr f a;
    expr f b;
    rel o
  end

and negate (x : Il.cmp) : Il.cmp =
  match x with
  | Il.Eq -> Il.Ne | Il.Ne -> Il.Eq | Il.Lt -> Il.Ge
  | Il.Ge -> Il.Lt | Il.Gt -> Il.Le | Il.Le -> Il.Gt

(* a comparison's 0 or 1: ceq, clt, cgt, and their negations *)
and compare_value (f : fn) ((x, un) : Il.cmp * bool) (fl : bool) : unit =
  let k = f.k in
  let not_ () = ldc k 0; emit k Il.Ceq in
  let un' = if fl then not un else un in
  match x with
  | Il.Eq -> emit k Il.Ceq
  | Il.Ne -> emit k Il.Ceq; not_ ()
  | Il.Lt -> emit k (Il.Clt un)
  | Il.Gt -> emit k (Il.Cgt un)
  | Il.Le -> emit k (Il.Cgt un'); not_ ()
  | Il.Ge -> emit k (Il.Clt un'); not_ ()

(* to l if n's truth is sense *)
and branch (f : fn) (n : expr) (sense : bool) (l : int) : unit =
  let k = f.k in
  match n.e with
  | Unary (Not, x) -> branch f x (not sense) l
  | Binary (Andand, a, b) ->
      if sense then begin
        let skip = label k in
        branch f a false skip;
        branch f b true l;
        place k skip
      end
      else (branch f a false l; branch f b false l)
  | Binary (Oror, a, b) ->
      if sense then (branch f a true l; branch f b true l)
      else begin
        let skip = label k in
        branch f a true skip;
        branch f b false l;
        place k skip
      end
  | Binary (o, a, b) when is_rel o ->
      let x, un = operands f o a b in
      let fl = is_float a.t in
      let x, un = if sense then (x, un) else (negate x, if fl then not un else un) in
      (* (beq has no .un, bne only its .un) *)
      let un = match x with Il.Eq -> false | Il.Ne -> true | _ -> un in
      emit k (Il.Bcmp (x, un, l))
  | _ when is_float n.t ->
      expr f n;
      emit k (Il.Ldc_r 0.0);
      emit k (if sense then Il.Bcmp (Il.Ne, true, l) else Il.Bcmp (Il.Eq, false, l))
  | _ -> expr f n; emit k (if sense then Il.Brtrue l else Il.Brfalse l)

and truth_value (f : fn) (n : expr) : unit =
  let k = f.k in
  let yes = label k and stop = label k in
  branch f n true yes;
  ldc k 0;
  emit k (Il.Br stop);
  place k yes;
  ldc k 1;
  place k stop

(*****************************************************************************)
(* Calls *)
(*****************************************************************************)

and call (f : fn) (n : expr) (fn : expr) (args : expr list) (used : bool) : unit =
  let c = f.c and k = f.k and line = n.line in
  (match fn.e with
   | Name (s, _, _) -> (
       match s.name, args with
       | "print", _ -> format f line None args
       | "sprint", buf :: rest -> format f line (Some buf) rest
       | "malloc", _ -> refuse line "malloc's memory given no type"
       | "free", _ -> List.iter (drop f) args
       | "_write", [ p; len ] ->
           (* (a Ptr<uint8>'s bytes, by the console's Stream) *)
           let t = pointee c line (link p.t) in
           let p = stash f p in
           let stream = S.Class (sys c "IO.Stream") in
           emit k (Il.Call (lib c "Console" "OpenStandardOutput" (static [] stream)));
           p (); emit k (Il.Ldfld (ptr_array c t));
           p (); emit k (Il.Ldfld (ptr_index c t));
           expr f len;
           let write = instance [ S.SzArray S.U1; S.I4; S.I4 ] S.Void in
           emit k (Il.Callvirt (lib c "IO.Stream" "Write" write))
       | "_exit", _ ->
           List.iter (expr f) args;
           emit k (Il.Call (lib c "Environment" "Exit" (static [ S.I4 ] S.Void)))
       | name, _ ->
           if List.mem name builtins then refuse line (name ^ "'s arguments");
           List.iter (value f) args;
           emit k (Il.Call (func_method c line name fn.t)))
   | Unary (Ind, p) ->
       expr f p;
       List.iter (value f) args;
       emit k (Il.Callvirt (invoke c line (link p.t)))
   | _ -> refuse line "a call of this");
  if (not used) && n.t.etype <> Tvoid then emit k Il.Pop
  else if used && n.t.etype = Tvoid then refuse line "a void function's value"

(* print's and sprint's format, a literal, compiled (Cil_strings): its
 * arguments computed first *)
and format (f : fn) (line : int) (buf : expr option) (args : expr list) : unit =
  match args with
  | { e = Unary (Addr, { e = Name (s, Cstatic, off); t; _ }); _ } :: rest
    when s.name = ".string" ->
      let text = Str.literal_bytes line t off in
      let buf = Option.map (stash f) buf in
      let args = List.map (fun (a : expr) -> (a, stash f a)) rest in
      Str.format f.c f.k line buf args text
  | _ -> refuse line "a format that is not a literal"
