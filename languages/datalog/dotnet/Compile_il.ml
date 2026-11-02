(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Compile_il.mli *)

module D = Datalog
module E = Datalog_eval
module S = Signature
module W = Writer

(*****************************************************************************)
(* The assembly, its references to datalog_rt's classes *)
(*****************************************************************************)

type c = {
  w : W.t;
  cls : int;                                (* the program's class *)
  t : S.t;                                  (* Datalog.t *)
  rel : S.t;                                (* Datalog.relation *)
  rt : int;                                 (* Datalog_rt *)
  idx : S.t;                                (* Index.t *)
  p : int;                                  (* the field holding the program *)
  relations : (string, int) Hashtbl.t;      (* name/arity: its field *)
  symbols : (int, int) Hashtbl.t;           (* a constant: its field *)
  mutable inits : Il.op list list;          (* the fields set, reversed *)
}

let static (ps : S.t list) (r : S.t) : S.meth =
  { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps }
let instance (ps : S.t list) (r : S.t) : S.meth =
  { (static ps r) with has_this = true }

let call (c : c) (name : string) (ps : S.t list) (r : S.t) : Il.op =
  Il.Call (W.member_ref c.w c.rt name (static ps r))

(* a relation's field, set at the start *)
let relation (c : c) (r : D.relation) : int =
  let key = Printf.sprintf "%s/%d" r.name r.arity in
  match Hashtbl.find_opt c.relations key with
  | Some f -> f
  | None ->
      let f = W.field_def c.w c.cls ("<rel>" ^ key) 0x0011 c.rel in
      Hashtbl.replace c.relations key f;
      c.inits <-
        [ Il.Ldsfld c.p; Il.Ldstr (W.user_string c.w r.name);
          Il.Ldc_i8 (Int64.of_int r.arity);
          call c "relation" [ c.t; S.String; S.I8 ] c.rel; Il.Stsfld f ]
        :: c.inits;
      f

(* a constant's field: its symbol in the program run, by its text *)
let symbol (c : c) (p : D.t) (k : int) : int =
  match Hashtbl.find_opt c.symbols k with
  | Some f -> f
  | None ->
      let f = W.field_def c.w c.cls (Printf.sprintf "<sym>%d" k) 0x0011 S.I8 in
      Hashtbl.replace c.symbols k f;
      c.inits <-
        [ Il.Ldsfld c.p; Il.Ldstr (W.user_string c.w (D.text p k));
          call c "symbol" [ c.t; S.String ] S.I8; Il.Stsfld f ]
        :: c.inits;
      f

(*****************************************************************************)
(* A method's code *)
(*****************************************************************************)

type code = {
  mutable ops : Il.op list;                 (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;
  mutable nlabels : int;
  mutable locals : S.t list;                (* reversed *)
  mutable nlocals : int;
}

let new_code () : code =
  { ops = []; n = 0; labels = Hashtbl.create 8; nlabels = 0; locals = [];
    nlocals = 0 }

let emit (k : code) (op : Il.op) : unit =
  k.ops <- op :: k.ops;
  k.n <- k.n + 1

let label (k : code) : int =
  k.nlabels <- k.nlabels + 1;
  k.nlabels

let place (k : code) (l : int) : unit = Hashtbl.replace k.labels l k.n

let local (k : code) (t : S.t) : int =
  k.locals <- t :: k.locals;
  k.nlocals <- k.nlocals + 1;
  k.nlocals - 1

let finish (c : c) (k : code) (meth : int) : unit =
  let at (l : int) : int = Hashtbl.find k.labels l in
  let ops =
    List.rev_map
      (fun (op : Il.op) ->
        match op with
        | Il.Br l -> Il.Br (at l)
        | Il.Brfalse l -> Il.Brfalse (at l)
        | Il.Brtrue l -> Il.Brtrue (at l)
        | Il.Bcmp (x, u, l) -> Il.Bcmp (x, u, at l)
        | op -> op)
      k.ops in
  W.set_body c.w meth (List.rev k.locals) (Array.of_list ops) []

(* a loop: i from the first (pushed) while below the end (pushed), the
 * body given where to go for the next *)
let loop (k : code) (i : int) (start : unit -> unit) (stop : unit -> unit)
    (one : Il.op) (body : int -> unit) : unit =
  let top = label k and next = label k and out = label k in
  start ();
  emit k (Il.Stloc i);
  place k top;
  emit k (Il.Ldloc i);
  stop ();
  emit k (Il.Bcmp (Il.Ge, false, out));
  body next;
  place k next;
  emit k (Il.Ldloc i);
  emit k one;
  emit k (Il.Binop Il.Add);
  emit k (Il.Stloc i);
  emit k (Il.Br top);
  place k out

(*****************************************************************************)
(* A plan: nested loops *)
(*****************************************************************************)

(* a rule's plan as a method: each scan a loop (over a range of the
 * relation's tuples, or the numbers an index gives), each test a
 * branch past what follows, the head's tuple added at the innermost *)
let plan (c : c) (p : D.t) (rule : D.rule) (steps : E.step list) (name : string)
    : int =
  let meth = W.method_def c.w c.cls name 0x0091 (static [] S.Void) in
  let k = new_code () in
  let env = Array.init rule.slots (fun (_ : int) -> local k S.I8) in
  let ints = S.SzArray S.I8 in
  let value (x : D.arg) : unit =
    match x with
    | D.Const s -> emit k (Il.Ldsfld (symbol c p s))
    | D.Slot v -> emit k (Il.Ldloc env.(v))
    | D.Any -> emit k (Il.Ldc_i8 (-1L)) in
  (* the method's start: each index it walks, each int64[] of keys it
   * fills, made once (in the order the steps below take them) *)
  let made : int Queue.t = Queue.create () in
  let int64 = W.type_ref c.w (W.assembly_ref c.w "System.Runtime") "System" "Int64" in
  let buffer (n : int) =
    let b = local k ints in
    emit k (Il.Ldc_i4 (Int32.of_int n)); emit k (Il.Newarr int64); emit k (Il.Stloc b);
    Queue.add b made in
  let index_of (r : D.relation) (mask : int) =
    let x = local k c.idx in
    emit k (Il.Ldsfld (relation c r)); emit k (Il.Ldc_i8 (Int64.of_int mask));
    emit k (call c "index" [ c.rel; S.I8 ] c.idx); emit k (Il.Stloc x);
    Queue.add x made in
  List.iter
    (fun (step : E.step) ->
      match step with
      | E.Test (D.Neg a) -> buffer (List.length (List.filter (fun (x : D.arg) -> x <> D.Any) (Array.to_list a.args)))
      | E.Test _ -> ()
      | E.Scan s when s.from_new || s.mask = 0 -> ()
      | E.Scan s when Array.length s.keys = s.atom.rel.arity -> buffer (Array.length s.keys)
      | E.Scan s -> index_of s.atom.rel s.mask; buffer (Array.length s.keys))
    steps;
  buffer rule.head.rel.arity;
  (* the next of them; an int64[] of them, its values put *)
  let made_next () = Queue.pop made in
  let array (xs : D.arg list) : unit =
    let b = made_next () in
    List.iteri
      (fun (i : int) (x : D.arg) ->
        emit k (Il.Ldloc b); emit k (Il.Ldc_i4 (Int32.of_int i)); value x;
        emit k (Il.Stelem Il.K_i8))
      xs;
    emit k (Il.Ldloc b) in
  let get (r : int) (id : unit -> unit) (col : int) : unit =
    emit k (Il.Ldsfld r);
    id ();
    emit k (Il.Ldc_i8 (Int64.of_int col));
    emit k (call c "get" [ c.rel; S.I8; S.I8 ] S.I8) in
  (* the tuple id's columns: those known compared (keys), the variables
   * bound, one bound again compared *)
  let tuple (s : E.scan) (r : int) (id : unit -> unit) (keys : bool) (skip : int) =
    let differs () = emit k (Il.Bcmp (Il.Ne, true, skip)) in
    if keys then
      Array.iter
        (fun ((col, x) : int * D.arg) -> get r id col; value x; differs ())
        s.keys;
    List.iter
      (fun ((col, v) : int * int) -> get r id col; emit k (Il.Stloc env.(v)))
      s.binds;
    List.iter
      (fun ((col, v) : int * int) ->
        get r id col; emit k (Il.Ldloc env.(v)); differs ())
      s.same in
  let rec steps_of (l : E.step list) : unit =
    match l with
    | [] ->
        emit k (Il.Ldsfld (relation c rule.head.rel));
        array (Array.to_list rule.head.args);
        emit k (call c "add" [ c.rel; ints ] S.Void)
    | E.Test t :: rest ->
        let skip = label k in
        test t skip;
        steps_of rest;
        place k skip
    | E.Scan s :: rest ->
        let r = relation c s.atom.rel in
        let keys = Array.to_list (Array.map snd s.keys) in
        if s.from_new || s.mask = 0 then begin
          (* (the range read once: what is added during it is the next
           * round's) *)
          let id = local k S.I8 and hi = local k S.I8 in
          let range (f : string) =
            emit k (Il.Ldsfld r); emit k (call c f [ c.rel ] S.I8) in
          range (if s.from_new then "delta_to" else "count");
          emit k (Il.Stloc hi);
          loop k id
            (fun () ->
              if s.from_new then range "delta_from" else emit k (Il.Ldc_i8 0L))
            (fun () -> emit k (Il.Ldloc hi))
            (Il.Ldc_i8 1L)
            (fun (next : int) ->
              tuple s r (fun () -> emit k (Il.Ldloc id)) true next;
              steps_of rest)
        end
        else if Array.length s.keys = s.atom.rel.arity then begin
          let skip = label k in
          emit k (Il.Ldsfld r);
          array keys;
          emit k (call c "mem" [ c.rel; ints ] S.Bool);
          emit k (Il.Brfalse skip);
          steps_of rest;
          place k skip
        end
        else begin
          (* (an index's chain: the tuples with the keys, the last first) *)
          let x = made_next () in
          let id = local k S.I8 in
          let top = label k and next = label k and stop = label k in
          emit k (Il.Ldloc x);
          array keys;
          emit k (call c "first" [ c.idx; ints ] S.I8);
          emit k (Il.Stloc id);
          place k top;
          emit k (Il.Ldloc id);
          emit k (Il.Ldc_i8 0L);
          emit k (Il.Bcmp (Il.Lt, false, stop));
          tuple s r (fun () -> emit k (Il.Ldloc id)) false next;
          steps_of rest;
          place k next;
          emit k (Il.Ldloc x);
          emit k (Il.Ldloc id);
          emit k (call c "next" [ c.idx; S.I8 ] S.I8);
          emit k (Il.Stloc id);
          emit k (Il.Br top);
          place k stop
        end
  (* to skip when the test fails *)
  and test (t : D.literal) (skip : int) : unit =
    match t with
    | D.Pos _ -> ()
    | D.Neg a ->
        let args = Array.to_list a.args in
        let known = List.filter (fun (x : D.arg) -> x <> D.Any) args in
        let bit (i : int) (x : D.arg) = if x = D.Any then 0 else 1 lsl i in
        let mask = List.fold_left ( + ) 0 (List.mapi bit args) in
        emit k (Il.Ldsfld (relation c a.rel));
        emit k (Il.Ldc_i8 (Int64.of_int mask));
        array known;
        emit k (call c "absent" [ c.rel; S.I8; ints ] S.Bool);
        emit k (Il.Brfalse skip)
    | D.Cmp (("=" | "=="), x, y) ->
        value x; value y; emit k (Il.Bcmp (Il.Ne, true, skip))
    | D.Cmp (("\\=" | "\\=="), x, y) ->
        value x; value y; emit k (Il.Bcmp (Il.Eq, false, skip))
    | D.Cmp (op, x, y) ->
        emit k (Il.Ldsfld c.p);
        value x;
        value y;
        emit k (call c "compare" [ c.t; S.I8; S.I8 ] S.I8);
        emit k (Il.Ldc_i8 0L);
        (* (the comparison's negation, to skip) *)
        let x =
          match op with "<" -> Il.Ge | ">" -> Il.Le | "=<" -> Il.Gt | _ -> Il.Lt in
        emit k (Il.Bcmp (x, false, skip)) in
  steps_of steps;
  emit k Il.Ret;
  finish c k meth;
  meth

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* each stratum: its heads, its rules' plans on everything and with an
 * atom from the new tuples (Datalog_eval.run's) *)
let strata (c : c) (p : D.t) : (int list * int list * int list) list =
  let top = E.stratify p in
  let rules = List.rev p.rule_list in
  let n = ref 0 in
  let compile (r : D.rule) (steps : E.step list) =
    incr n;
    plan c p r steps (Printf.sprintf "plan%d" !n) in
  List.init (top + 1) (fun (s : int) ->
      let mine = List.filter (fun (r : D.rule) -> r.head.rel.stratum = s) rules in
      let heads =
        List.fold_left
          (fun (acc : D.relation list) (r : D.rule) ->
            if List.memq r.head.rel acc then acc else r.head.rel :: acc)
          [] mine in
      let whole =
        List.map (fun (r : D.rule) -> compile r (E.plan r.slots None r.body)) mine in
      let by_new =
        List.concat_map
          (fun (r : D.rule) ->
            List.concat
              (List.mapi
                 (fun (k : int) (l : D.literal) ->
                   match l with
                   | D.Pos a when a.rel.stratum = s && a.rel.rules > 0 ->
                       [ compile r (E.from_new r k a) ]
                   | _ -> [])
                 r.body))
          mine in
      (List.map (relation c) heads, whole, by_new))

let assembly ((rt_name, entry) : string * string) (name : string) (p : D.t)
    (texts : (string * string) list) (queries : string list) : string =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let rt_asm = W.assembly_ref w rt_name in
  let datalog = W.type_ref w rt_asm "" "Datalog" in
  let rel_tok = W.type_ref w datalog "" "relation" in
  let idx = S.Class (W.type_ref w (W.type_ref w rt_asm "" "Index") "" "t") in
  let t = S.Class (W.type_ref w datalog "" "t") and rel = S.Class rel_tok in
  let rt = W.type_ref w rt_asm "" "Datalog_rt" in
  let obj = W.type_ref w runtime "System" "Object" in
  let cls = W.type_def w "" "Compiled" 0x00000181 obj in
  let pf = W.field_def w cls "<p>" 0x0011 t in
  let c =
    { w; cls; t; rel; rt; idx; p = pf; relations = Hashtbl.create 16;
      symbols = Hashtbl.create 16; inits = [] } in
  let strata = strata c p in
  (* rules(p): the fields set, then each stratum's rounds *)
  let rules_m = W.method_def w cls "rules" 0x0091 (static [ t ] S.Object) in
  let k = new_code () in
  emit k (Il.Ldarg 0);
  emit k (Il.Stsfld pf);
  List.iter (List.iter (emit k)) (List.rev c.inits);
  List.iter
    (fun ((heads, whole, by_new) : int list * int list * int list) ->
      let a = local k (S.SzArray rel) in
      emit k (Il.Ldc_i4 (Int32.of_int (List.length heads)));
      emit k (Il.Newarr rel_tok);
      List.iteri
        (fun (i : int) (f : int) ->
          emit k Il.Dup; emit k (Il.Ldc_i4 (Int32.of_int i)); emit k (Il.Ldsfld f);
          emit k (Il.Stelem Il.K_ref))
        heads;
      emit k (Il.Stloc a);
      let heads_call (f : string) (r : S.t) =
        emit k (Il.Ldloc a); emit k (call c f [ S.SzArray rel ] r) in
      heads_call "begin_stratum" S.Void;
      List.iter (fun (m : int) -> emit k (Il.Call m)) whole;
      let top = label k and stop = label k in
      place k top;
      heads_call "turn" S.Bool;
      emit k (Il.Brfalse stop);
      List.iter (fun (m : int) -> emit k (Il.Call m)) by_new;
      emit k (Il.Br top);
      place k stop;
      heads_call "end_stratum" S.Void)
    strata;
  emit k Il.Ldnull;
  emit k Il.Ret;
  finish c k rules_m;
  (* Main: datalog_rt's main given the texts, the queries, rules *)
  let string = W.type_ref w runtime "System" "String" in
  let strings (l : string list) =
    let one (i : int) (s : string) =
      [ Il.Dup; Il.Ldc_i4 (Int32.of_int i); Il.Ldstr (W.user_string w s);
        Il.Stelem Il.K_ref ] in
    [ Il.Ldc_i4 (Int32.of_int (List.length l)); Il.Newarr string ]
    @ List.concat (List.mapi one l) in
  let func_cls = W.type_ref w runtime "System" "Func`2" in
  let func = S.GenericInst (S.Class func_cls, [ t; S.Object ]) in
  let func_ctor =
    W.member_ref w (W.type_spec w func) ".ctor" (instance [ S.Object; S.I ] S.Void) in
  let rt_main = static [ S.SzArray S.String; S.SzArray S.String; func ] S.Void in
  let main =
    W.method_def w cls "Main" 0x0096 (static [ S.SzArray S.String ] S.Void) in
  let ops =
    strings (List.concat_map (fun ((n, text) : string * string) -> [ n; text ]) texts)
    @ strings queries
    @ [ Il.Ldnull; Il.Ldftn rules_m; Il.Newobj func_ctor;
        Il.Call (W.member_ref w (W.type_ref w rt_asm "" entry) "main" rt_main); Il.Ret ] in
  W.set_body w main [] (Array.of_list ops) [];
  W.set_entry_point w main;
  W.write w
