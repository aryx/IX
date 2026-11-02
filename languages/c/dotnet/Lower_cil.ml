(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower_cil.mli *)

open Tree
open Tree_helpers
open Cil_types
module E = Cil_exprs
module S = Signature
module W = Writer

(* the assembly being made, its file's name, its functions defined,
 * the globals' initializers (gextern's) *)
type state = {
  c : c;
  name : string;
  mutable defined : string list;
  mutable inits : (sym * typ * int * expr) list;   (* reversed *)
}

let current : state option ref = ref None

let state () : state =
  match !current with Some s -> s | None -> failwith "Lower_cil.start not called"

(* a refusal, the front end's error at its line *)
let guard (f : unit -> 'a) : 'a =
  try f () with Refused (line, m) -> error_at line "%s" m

let start (name : string) : unit =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console =
    W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  (* (a static class, its initializer run at its first use) *)
  let cls = W.type_def w "" name 0x00000181 obj in
  let c =
    { w; runtime; console; cls; memo = Hashtbl.create 64; structs = [];
      classes = [] } in
  Hashtbl.replace c.memo "type Object" obj;
  make_ptr_class c;
  E.reset ();
  current := Some { c; name; defined = []; inits = [] }

(*****************************************************************************)
(* A function's variables *)
(*****************************************************************************)

(* the subexpressions of n, n first *)
let rec walk (visit : expr -> unit) (n : expr) : unit =
  visit n;
  match n.e with
  | Unary (_, a) | Dot (a, _) | Elem (a, _) | Sizeof a | Typed a -> walk visit a
  | Binary (_, a, b) | Assign (_, a, b) -> walk visit a; walk visit b
  | Cond (a, b, x) -> walk visit a; walk visit b; walk visit x
  | Call (fn, args) -> walk visit fn; List.iter (walk visit) args
  | Name _ | Const _ | Fconst _ | Str _ | Lstr _ | Reg _ | Indreg _
  | Sizeof_type _ -> ()

let rec exprs (visit : expr -> unit) (s : stmt) : unit =
  let go = exprs visit and e = walk visit in
  match s with
  | Expr x -> e x
  | Block l -> List.iter go l
  | If (x, a, b) -> e x; go a; Option.iter go b
  | While (x, a) | Dowhile (a, x) | Switch (x, a) -> e x; go a
  | For (a, x, b, body) -> go a; Option.iter e x; go b; go body
  | Case (Some x) -> e x
  | Return (Some x, _) -> e x
  | Case None | Label _ | Goto _ | Break | Continue | Return (None, _)
  | Used _ | Set _ -> ()

(* the statement typed (Check.complex), its expressions in their order *)
let rec checked (s : stmt) : stmt =
  match s with
  | Expr x -> Expr (Check.complex x)
  | Block l -> Block (List.map checked l)
  | If (x, a, b) ->
      let x = Check.complex x in
      let a = checked a in
      If (x, a, Option.map checked b)
  | While (x, a) -> let x = Check.complex x in While (x, checked a)
  | Dowhile (a, x) -> let a = checked a in Dowhile (a, Check.complex x)
  | For (a, x, b, body) ->
      let a = checked a in
      let x = Option.map Check.complex x in
      let b = checked b in
      For (a, x, b, checked body)
  | Switch (x, a) -> let x = Check.complex x in Switch (x, checked a)
  | Case (Some x) -> Case (Some (Check.complex x))
  | Return (Some x, rt) -> Return (Some (Check.complex_ret rt x), rt)
  | s -> s

(* each parameter's offset, in order (Declare's param) *)
let parameter_offsets (t : typ) : int list =
  let offset =
    ref (match t.link with Some r -> Declare.align 0 r Declare.Aarg0 | None -> 0) in
  let rec go (p : typ option) : int list =
    match p with
    | None -> []
    | Some p when p.etype = Tvoid -> []
    | Some p ->
        offset := Declare.align !offset p Declare.Aarg1;
        let here = !offset in
        offset := Declare.align !offset p Declare.Aarg2;
        here :: go p.down in
  go t.down

(* the function's variables: each a slot, or a local holding an array
 * (made here, at the start) when it is one or its address is taken *)
let variables (f : E.fn) (t : typ) (body : stmt) : unit =
  let c = f.c and k = f.k in
  let taken = Hashtbl.create 8 and names = ref [] in
  exprs
    (fun (n : expr) ->
      match n.e with
      | Unary (Addr, { e = Name (s, (Cauto | Cparam), off); t; _ }) ->
          Hashtbl.replace taken (E.key s off t) ()
      | Name (s, ((Cauto | Cparam) as cl), off) ->
          let key = E.key s off n.t in
          if not (List.mem_assoc key !names) then
            names := (key, (cl, off, n.t, n.line)) :: !names
      | _ -> ())
    body;
  let offsets = parameter_offsets t in
  List.iter
    (fun ((key, (cl, off, t, line)) : string * (cls * int * typ * int)) ->
      let boxed = Hashtbl.mem taken key && t.etype <> Tarray in
      let var =
        match cl with
        | Cparam ->
            let rec index (i : int) (l : int list) =
              match l with
              | o :: rest -> if o = off then i else index (i + 1) rest
              | [] -> refuse line "a parameter not in the prototype" in
            let i = index 0 offsets in
            if boxed then begin
              let a = local k (S.SzArray (cts c line t)) in
              ldc k 1;
              emit k (Il.Newarr (type_token c line t));
              emit k (Il.Stloc a);
              emit k (Il.Ldloc a); ldc k 0; emit k (Il.Ldarg i);
              emit k (Il.Stelem (store_kind c line t));
              E.Boxed a
            end
            else E.Slot (true, i)
        | _ when t.etype = Tarray || boxed ->
            let a = local k (S.SzArray (cts c line (base t))) in
            new_array c k line t (fun () ->
                ldc k (if boxed then 1 else count line t));
            emit k (Il.Stloc a);
            if boxed then E.Boxed a else E.Array_var a
        | _ when t.etype = Tstruct ->
            let l = local k (S.Class (struct_class c line t)) in
            emit k (Il.Newobj (struct_info c line t).sctor);
            emit k (Il.Stloc l);
            E.Slot (false, l)
        | _ -> E.Slot (false, local k (slot c line t)) in
      Hashtbl.replace f.vars key var)
    (List.rev !names)

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)

type ctx = {
  brk : int option;
  cont : int option;
  cases : int list ref;                  (* the switch's labels not yet placed *)
  labels : (string, int) Hashtbl.t;      (* the function's *)
}

(* a switch's cases, in order, not those of a switch inside *)
let rec cases (s : stmt) : expr option list =
  match s with
  | Case x -> [ x ]
  | Block l -> List.concat_map cases l
  | If (_, a, b) -> cases a @ (match b with Some b -> cases b | None -> [])
  | While (_, a) | Dowhile (a, _) | For (_, _, _, a) -> cases a
  | _ -> []

let rec stmt (f : E.fn) (ctx : ctx) (s : stmt) : unit =
  let k = f.k in
  let go = stmt f ctx in
  let named (l : label) = match Hashtbl.find_opt ctx.labels l.lsym.name with
    | Some x -> x
    | None -> let x = label k in Hashtbl.replace ctx.labels l.lsym.name x; x in
  match s with
  | Expr x -> E.drop f x
  | Block l -> List.iter go l
  | If (x, a, b) ->
      let other = label k and stop = label k in
      E.branch f x false other;
      go a;
      emit k (Il.Br stop);
      place k other;
      Option.iter go b;
      place k stop
  | While (x, a) ->
      let top = label k and stop = label k in
      place k top;
      E.branch f x false stop;
      stmt f { ctx with brk = Some stop; cont = Some top } a;
      emit k (Il.Br top);
      place k stop
  | Dowhile (a, x) ->
      let top = label k and test = label k and stop = label k in
      place k top;
      stmt f { ctx with brk = Some stop; cont = Some test } a;
      place k test;
      E.branch f x true top;
      place k stop
  | For (a, x, b, body) ->
      let top = label k and step = label k and stop = label k in
      go a;
      place k top;
      Option.iter (fun (x : expr) -> E.branch f x false stop) x;
      stmt f { ctx with brk = Some stop; cont = Some step } body;
      place k step;
      stmt f ctx b;
      emit k (Il.Br top);
      place k stop
  | Switch (x, body) ->
      let line = x.line in
      let v = local k (slot f.c line x.t) and stop = label k in
      E.expr f x;
      emit k (Il.Stloc v);
      let cs = cases body in
      let ls = List.map (fun (_ : expr option) -> label k) cs in
      List.iter2
        (fun (cs : expr option) (l : int) ->
          match cs with
          | Some { e = Const n; _ } ->
              emit k (Il.Ldloc v);
              E.const f line x.t n;
              emit k (Il.Bcmp (Il.Eq, false, l))
          | Some _ -> refuse line "a case of no constant"
          | None -> ())
        cs ls;
      emit k (Il.Br (match List.assoc_opt None (List.combine cs ls) with
                     | Some l -> l | None -> stop));
      stmt f { ctx with brk = Some stop; cases = ref ls } body;
      place k stop
  | Case _ -> (
      match !(ctx.cases) with
      | l :: rest -> ctx.cases := rest; place k l
      | [] -> refuse !lineno "a case outside a switch")
  | Label l -> place k (named l)
  | Goto l -> emit k (Il.Br (named l))
  | Break -> (
      match ctx.brk with
      | Some l -> emit k (Il.Br l)
      | None -> refuse !lineno "a break outside a loop")
  | Continue -> (
      match ctx.cont with
      | Some l -> emit k (Il.Br l)
      | None -> refuse !lineno "a continue outside a loop")
  | Return (None, _) -> emit k Il.Ret
  | Return (Some x, rt) -> E.assigned f rt x; emit k Il.Ret
  | Used _ | Set _ -> ()

(* a function: its method's body *)
let func (fs : sym) (body : stmt) : unit =
  guard (fun () ->
      let st = state () in
      let c = st.c and line = !lineno in
      let t =
        match fs.typ with Some t -> t | None -> refuse line "a function, no type" in
      let meth = E.func_method c line fs.name t in
      st.defined <- fs.name :: st.defined;
      let body = checked body in
      let f = { E.c; k = new_code (); fname = fs.name; vars = Hashtbl.create 16 } in
      variables f t body;
      stmt f { brk = None; cont = None; cases = ref []; labels = Hashtbl.create 4 }
        body;
      (* (the end: a value of none if the function has a result) *)
      (match slot c line (link t) with
       | S.Void -> ()
       | S.I8 | S.U8 -> emit f.k (Il.Ldc_i8 0L)
       | S.R4 | S.R8 -> emit f.k (Il.Ldc_r 0.0)
       | S.I4 | S.U4 -> ldc f.k 0
       | _ -> emit f.k Il.Ldnull);
      emit f.k Il.Ret;
      finish c f.k meth)

(* a global's initializer at an offset (Declare's gextern) *)
let gextern (s : sym) (x : expr) (o : int) (_ : int) : unit =
  let st = state () in
  match s.typ with
  | Some t -> st.inits <- (s, t, o, x) :: st.inits
  | None -> ()

(*****************************************************************************)
(* The assembly *)
(*****************************************************************************)

(* the globals' initializers (<init>), then their arrays made, before
 * (the class's .cctor) *)
let initializers (st : state) : unit =
  let c = st.c in
  let k = new_code () in
  let f = { E.c; k; fname = "<init>"; vars = Hashtbl.create 1 } in
  List.iter
    (fun ((s, t, o, x) : sym * typ * int * expr) ->
      let line = x.line in
      let b = base t in
      if b.etype = Tstruct then
        refuse line ("the initializer of a structure: " ^ s.name);
      let fld = E.global c line s.name t in
      match x.e with
      | Name (n, Cstatic, off) when n.name = ".string" && b.etype = Tchar ->
          (* (char a[] = "...": the literal's bytes, its NUL) *)
          String.iteri
            (fun (i : int) (ch : char) ->
              emit k (Il.Ldsfld fld); ldc k (o + i); ldc k (Char.code ch);
              emit k (Il.Stelem Il.K_i1))
            (Cil_strings.literal_bytes line x.t off ^ "\000")
      | _ ->
          emit k (Il.Ldsfld fld);
          ldc k (o / b.width);
          (* (an array, a literal: its address, as Declare leaves it) *)
          if x.t.etype = Tarray then E.address f x else E.assigned f b x;
          emit k (Il.Stelem (store_kind c line b)))
    (List.rev st.inits);
  emit k Il.Ret;
  let init = W.method_def c.w c.cls "<init>" 0x0091 (static [] S.Void) in
  finish c k init;
  let k = new_code () in
  List.iter
    (fun ((name, t0, fld) : string * typ * int) ->
      let line = !lineno in
      (* (the declaration's type, complete: int a[] = {...}) *)
      let t =
        match (lookup name).typ with Some t when t.etype = t0.etype -> t | _ -> t0 in
      new_array c k line t (fun () ->
          ldc k (if t.etype = Tarray then count line t else 1));
      emit k (Il.Stsfld fld))
    (List.rev !E.globals);
  emit k (Il.Call init);
  emit k Il.Ret;
  finish c k (W.method_def c.w c.cls ".cctor" 0x1891 (static [] S.Void))

(* the entry point: C's argv of the arguments, after the program's
 * name, main called, then exits(nil) *)
let entry (st : state) (main : sym) : unit =
  let c = st.c in
  let line = !lineno in
  let t = Option.get main.typ in
  let str = ptr_of c S.I1 in
  let k = new_code () in
  let a = local k (S.SzArray str) and i = local k S.I4 in
  let top = label k and stop = label k in
  let cstring () =
    emit k (Il.Call (Cil_strings.cstr c)); ldc k 0;
    emit k (Il.Newobj (ptr_ctor c S.I1)) in
  (* (.NET's arguments, plus n) *)
  let args (n : int) =
    emit k (Il.Ldarg 0); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i4, false, false));
    if n > 0 then (ldc k n; emit k (Il.Binop Il.Add)) in
  args 2;
  emit k (Il.Newarr (token_of c str));
  emit k (Il.Stloc a);
  emit k (Il.Ldloc a); ldc k 0;
  emit k (Il.Ldstr (W.user_string c.w ("./" ^ st.name))); cstring ();
  emit k (Il.Stelem Il.K_ref);
  ldc k 0; emit k (Il.Stloc i);
  place k top;
  emit k (Il.Ldloc i); args 0;
  emit k (Il.Bcmp (Il.Ge, false, stop));
  emit k (Il.Ldloc a); emit k (Il.Ldloc i); ldc k 1; emit k (Il.Binop Il.Add);
  emit k (Il.Ldarg 0); emit k (Il.Ldloc i); emit k (Il.Ldelem Il.K_ref); cstring ();
  emit k (Il.Stelem Il.K_ref);
  emit k (Il.Ldloc i); ldc k 1; emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
  emit k (Il.Br top);
  place k stop;
  (match params c line t with
   | [] -> ()
   | [ _; _ ] ->
       args 1;
       emit k (Il.Ldloc a); ldc k 0; emit k (Il.Newobj (ptr_ctor c str))
   | _ -> refuse line "a main of other than argc and argv");
  emit k (Il.Call (E.func_method c line "main" t));
  if slot c line (link t) <> S.Void then emit k Il.Pop;
  emit k Il.Ldnull;
  emit k (Il.Call (Cil_strings.helper c "exits"));
  emit k Il.Ret;
  let m =
    W.method_def c.w c.cls "Main" 0x0096 (static [ S.SzArray S.String ] S.Void) in
  finish c k m;
  W.set_entry_point c.w m

(* the assembly's bytes: every function called is defined *)
let finish () : string =
  guard (fun () ->
      let st = state () in
      let c = st.c in
      initializers st;
      if List.mem "main" st.defined then entry st (lookup "main");
      Hashtbl.iter
        (fun (key : string) (_ : int) ->
          if String.length key > 3 && String.sub key 0 3 = "fn " then begin
            let name = String.sub key 3 (String.length key - 3) in
            if not (List.mem name st.defined) then
              error_at !lineno "%s: called, not defined (libc.c: Plan 9's few)" name
          end)
        c.memo;
      W.write c.w)
