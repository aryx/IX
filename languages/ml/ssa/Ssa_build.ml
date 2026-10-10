(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ssa_build.mli *)

module L = Ir

open Ssa

(*****************************************************************************)
(* Blocks, from the labels and the jumps *)
(*****************************************************************************)

(* a run of instructions, and the jump that ends it if any *)
type raw = { label : int option; code : L.t list; last : L.t option }

let ends : L.t -> bool = function
  | Jmp _ | Jz _ | Jnz _ | Ret | Raise | TryEnter _ | Call (_, _, true) -> true
  | _ -> false

let split (code : L.t list) =
  let out = ref [] and label = ref None and cur = ref [] in
  let close last = out := { label = !label; code = List.rev !cur; last } :: !out; label := None; cur := [] in
  List.iter (fun (i : L.t) ->
    match i with
    | Label l -> if !cur <> [] || !label <> None then close None; label := Some l
    | i when ends i -> close (Some i)
    | i -> cur := i :: !cur) code;
  if !cur <> [] || !label <> None then close None;
  Array.of_list (List.rev !out)

(* each run's successors: the next run, a label's *)
let successors (raws : raw array) =
  let at = Hashtbl.create 16 in
  Array.iteri (fun i r -> Option.iter (fun l -> Hashtbl.replace at l i) r.label) raws;
  let lbl l = Hashtbl.find at l in
  Array.mapi (fun i r ->
    let next = if i + 1 < Array.length raws then [ i + 1 ] else [] in
    match r.last with
    | None -> next
    | Some (Jmp l) -> [ lbl l ]
    | Some (Jz l | Jnz l | TryEnter (_, l)) -> next @ [ lbl l ]
    | Some _ -> []) raws

(* the slots an instruction pops, and pushes *)
let arity : L.t -> int * int = function
  | Int _ | Block _ | Sym _ | Get _ | GetG _ | Catch _ -> 0, 1
  | Set _ | SetG _ | Drop | Ret | Raise | Jz _ | Jnz _ -> 1, 0
  | Field _ -> 1, 1
  | SetField _ -> 2, 0
  | Index -> 2, 1
  | SetIndex -> 3, 0
  | ByteGet -> 2, 1
  | ByteSet -> 3, 0
  | StrLen -> 1, 1
  | Float2 _ -> 2, 1
  | Float1 _ | FloatOfInt | IntOfFloat -> 1, 1
  | Alloc (_, n) -> n, 1
  | Op (Neg | Not | IsInt | Tag | Size) -> 1, 1
  | Op _ -> 2, 1
  | Call (_, _, tail) -> 0, if tail then 0 else 1
  | CallC (_, n) -> n, 1
  | Label _ | Jmp _ | TryEnter _ | TryExit _ -> 0, 0

(*****************************************************************************)
(* Braun et al.'s construction *)
(*****************************************************************************)

(* the variables: a frame's slot, and a position of the stack at a
 * block's edge *)
type var = Slot_var of int | Stack_var of int

let build (f : L.func) =
  (* the entry has no predecessor: an empty one before a first label,
   * which a jump may target (opti's tails) *)
  let raws = split f.code in
  let raws = if Array.length raws > 0 && raws.(0).label <> None then Array.append [| { label = None; code = []; last = None } |] raws else raws in
  let succ = successors raws in
  (* the runs the entry reaches, numbered in order *)
  let n = Array.length raws in
  let reach = Array.make n false in
  let rec visit i = if not reach.(i) then (reach.(i) <- true; List.iter visit succ.(i)) in
  if n > 0 then visit 0;
  let ids = Array.make n (-1) and count = ref 0 in
  Array.iteri (fun i r -> if r then (ids.(i) <- !count; incr count)) reach;
  let blocks = Array.init !count (fun id -> { id; phis = []; body = []; term = Ret 0; preds = [] }) in
  let raw_of = Array.make !count 0 in
  Array.iteri (fun i r -> if r then raw_of.(ids.(i)) <- i) reach;
  let bsucc b = List.map (fun i -> ids.(i)) succ.(raw_of.(b)) in
  Array.iter (fun (b : block) -> List.iter (fun s -> blocks.(s).preds <- blocks.(s).preds @ [ b.id ]) (bsucc b.id)) blocks;
  (* each block's stack at its entry *)
  let depth = Array.make !count (-1) in
  let rec flow b d =
    if depth.(b) < 0 then begin
      depth.(b) <- d;
      let r = raws.(raw_of.(b)) in
      let d = List.fold_left (fun d i -> let p, q = arity i in d - p + q) d r.code in
      let d = match r.last with Some (Jz _ | Jnz _) -> d - 1 | _ -> d in
      List.iter (fun s -> flow s d) (bsucc b)
    end
  in
  if !count > 0 then flow 0 0;
  (* the values *)
  let defs = Hashtbl.create 256 and where = Hashtbl.create 256 and next = ref 0 in
  let fresh b ins = let v = !next in incr next; Hashtbl.replace defs v ins; Hashtbl.replace where v b; v in
  let emit b ins = let v = fresh b ins in blocks.(b).body <- blocks.(b).body @ [ v ]; v in
  (* with a handler, a slot is read and written in memory: the handler
   * would need its value at each raise *)
  let memory = List.exists (function L.TryEnter _ -> true | _ -> false) f.code in
  let current = Hashtbl.create 64 and sealed = Array.make !count false and filled = Array.make !count false in
  let incomplete = Hashtbl.create 16 in
  let write var b v = Hashtbl.replace current (var, b) v in
  let new_phi b = let v = fresh b (Phi []) in blocks.(b).phis <- blocks.(b).phis @ [ v ]; v in
  let rec read var b = match Hashtbl.find_opt current (var, b) with Some v -> v | None -> read_rec var b
  and read_rec var b =
    let v =
      if not sealed.(b) then (let v = new_phi b in Hashtbl.add incomplete b (var, v); v)
      else
        match blocks.(b).preds with
        | [ p ] -> read var p
        | [] -> emit b Zero
        | _ -> let v = new_phi b in write var b v; add_operands var v b; v
    in
    write var b v;
    v
  and add_operands var phi b =
    let ops = List.map (fun p -> p, read var p) blocks.(b).preds in
    Hashtbl.replace defs phi (Phi ops)
  in
  let seal b =
    List.iter (fun (var, phi) -> add_operands var phi b) (Hashtbl.find_all incomplete b);
    Hashtbl.remove incomplete b;
    sealed.(b) <- true
  in
  let seal_ready () =
    Array.iteri (fun b s -> if (not s) && List.for_all (fun p -> filled.(p)) blocks.(b).preds then seal b) sealed
  in
  (* the entry: the closure and the arguments, as the prologue stores them *)
  if !count > 0 then begin
    seal 0;
    for i = 0 to f.nparams do write (Slot_var i) 0 (emit 0 (Param i)) done
  end;
  Array.iter (fun (b : block) ->
    let id = b.id in
    let r = raws.(raw_of.(id)) in
    let stack = ref (List.init depth.(id) (fun d -> read (Stack_var d) id) |> List.rev) in
    let push v = stack := v :: !stack in
    let pop () = match !stack with v :: rest -> stack := rest; v | [] -> failwith (f.name ^ ": ssa: the stack is empty") in
    let pops k = List.init k (fun _ -> pop ()) in
    let get i = if memory then emit id (Slot i) else read (Slot_var i) id in
    List.iter (fun (i : L.t) ->
      match i with
      | Int n -> push (emit id (Const n))
      | Block s -> push (emit id (Blk s))
      | Sym s -> push (emit id (Symb s))
      | Get i -> push (get i)
      | Set i -> let v = pop () in if memory then ignore (emit id (SetSlot (i, v))) else write (Slot_var i) id v
      | GetG g -> push (emit id (GetG g))
      | SetG g -> let v = pop () in ignore (emit id (SetG (g, v)))
      | Field k -> let b = pop () in push (emit id (Field (k, b)))
      | SetField k -> let b = pop () in let v = pop () in ignore (emit id (SetField (k, b, v)))
      | Index -> let b = pop () in let i = pop () in push (emit id (Index (b, i)))
      | SetIndex -> let b = pop () in let i = pop () in let v = pop () in ignore (emit id (SetIndex (b, i, v)))
      (* (the bytes in place are the stack machine's: here, the runtime's calls as before) *)
      | ByteGet -> let vs = pops 2 in push (emit id (CallC ("ml_string_get", vs)))
      | ByteSet -> let vs = pops 3 in ignore (emit id (CallC ("ml_string_set", vs)))
      | StrLen -> let vs = pops 1 in push (emit id (CallC ("ml_string_length", vs)))
      | Float2 f -> let vs = pops 2 in push (emit id (CallC (f, vs)))
      | Float1 f -> let vs = pops 1 in push (emit id (CallC (f, vs)))
      | FloatOfInt -> let vs = pops 1 in push (emit id (CallC ("caml_floatofint", vs)))
      | IntOfFloat -> let vs = pops 1 in push (emit id (CallC ("caml_intoffloat", vs)))
      | Alloc (tag, n) -> let vs = pops n in push (emit id (Alloc (tag, vs)))
      | Op o -> let p, _ = arity i in let vs = pops p in push (emit id (Op (o, vs)))
      | Call (t, slots, _) -> let vs = List.map get slots in push (emit id (Call (t, vs)))
      | CallC (g, k) -> let vs = pops k in push (emit id (CallC (g, vs)))
      | Drop -> ignore (pop ())
      | TryExit k -> ignore (emit id (TryExit k))
      | Catch k -> push (emit id (Caught k))
      | Label _ | Jmp _ | Jz _ | Jnz _ | Ret | Raise | TryEnter _ -> ()) r.code;
    let succs = bsucc id in
    (b.term <-
       match r.last, succs with
       | Some (Jmp _), [ s ] | None, [ s ] -> Jmp s
       | Some (Jz _), [ nx; l ] -> Br (pop (), nx, l)
       | Some (Jnz _), [ nx; l ] -> Br (pop (), l, nx)
       | Some (TryEnter (k, _)), [ nx; h ] -> Try (k, nx, h)
       | Some Ret, _ -> Ret (pop ())
       | Some Raise, _ -> Raise (pop ())
       | Some (Call (t, slots, true)), _ -> Tail (t, List.map get slots)
       | None, [] -> Ret (emit id Zero)
       | _ -> failwith (f.name ^ ": ssa: a block's end"));
    (* the stack left, for the successors *)
    List.iteri (fun d v -> write (Stack_var d) id v) (List.rev !stack);
    filled.(id) <- true;
    seal_ready ()) blocks;
  Array.iteri (fun b s -> if not s then seal b) sealed;
  { name = f.name; nparams = f.nparams; blocks; defs }

(*****************************************************************************)
(* Trivial phis out *)
(*****************************************************************************)

let operands = function
  | Const _ | Zero | Blk _ | Symb _ | Param _ | GetG _ | Slot _ | Caught _ | TryExit _ -> []
  | Phi ops -> List.map snd ops
  | SetG (_, v) | SetSlot (_, v) | Field (_, v) -> [ v ]
  | SetField (_, a, b) | Index (a, b) -> [ a; b ]
  | SetIndex (a, b, c) -> [ a; b; c ]
  | Alloc (_, vs) | Op (_, vs) | Call (_, vs) | CallC (_, vs) -> vs

let map_ins f = function
  | Phi ops -> Phi (List.map (fun (b, v) -> b, f v) ops)
  | SetG (g, v) -> SetG (g, f v)
  | SetSlot (i, v) -> SetSlot (i, f v)
  | Field (k, v) -> Field (k, f v)
  | SetField (k, a, b) -> SetField (k, f a, f b)
  | Index (a, b) -> Index (f a, f b)
  | SetIndex (a, b, c) -> SetIndex (f a, f b, f c)
  | Alloc (t, vs) -> Alloc (t, List.map f vs)
  | Op (o, vs) -> Op (o, List.map f vs)
  | Call (t, vs) -> Call (t, List.map f vs)
  | CallC (g, vs) -> CallC (g, List.map f vs)
  | i -> i

let map_term f = function
  | Br (v, a, b) -> Br (f v, a, b)
  | Ret v -> Ret (f v)
  | Raise v -> Raise (f v)
  | Tail (t, vs) -> Tail (t, List.map f vs)
  | t -> t

(* a phi whose operands are one value (and itself) is that value; until
 * none is (Braun et al.'s tryRemoveTrivialPhi, as a fixpoint) *)
let simplify (fn : func) =
  let subst = Hashtbl.create 16 in
  let rec find v = match Hashtbl.find_opt subst v with Some w -> let r = find w in Hashtbl.replace subst v r; r | None -> v in
  let changed = ref true in
  while !changed do
    changed := false;
    Array.iter (fun (b : block) ->
      b.phis <- List.filter (fun phi ->
        match Hashtbl.find fn.defs phi with
        | Phi ops -> (
            match List.sort_uniq compare (List.filter (fun v -> v <> phi) (List.map (fun (_, v) -> find v) ops)) with
            | [ v ] -> Hashtbl.replace subst phi v; changed := true; false
            | _ -> true)
        | _ -> true) b.phis) fn.blocks
  done;
  Array.iter (fun (b : block) ->
    List.iter (fun v -> Hashtbl.replace fn.defs v (map_ins find (Hashtbl.find fn.defs v))) (b.phis @ b.body);
    b.term <- map_term find b.term) fn.blocks;
  fn

(*****************************************************************************)
(* The check: every use dominated by its definition *)
(*****************************************************************************)

let successors_of (b : block) = match b.term with Jmp s -> [ s ] | Br (_, a, b) -> [ a; b ] | Try (_, a, b) -> [ a; b ] | _ -> []

(* the immediate dominators (Cooper, Harvey and Kennedy, "A Simple, Fast
 * Dominance Algorithm", 2001), the blocks in reverse postorder *)
let dominators (fn : func) =
  let n = Array.length fn.blocks in
  let order = ref [] and seen = Array.make n false in
  let rec dfs b = if not seen.(b) then (seen.(b) <- true; List.iter dfs (successors_of fn.blocks.(b)); order := b :: !order) in
  if n > 0 then dfs 0;
  let rpo = Array.make n 0 in
  List.iteri (fun i b -> rpo.(b) <- i) !order;
  let idom = Array.make n (-1) in
  if n > 0 then idom.(0) <- 0;
  let rec intersect a b = if a = b then a else if rpo.(a) > rpo.(b) then intersect idom.(a) b else intersect a idom.(b) in
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter (fun b ->
      if b <> 0 then
        match List.filter (fun p -> idom.(p) >= 0) fn.blocks.(b).preds with
        | [] -> ()
        | p :: ps ->
            let d = List.fold_left intersect p ps in
            if idom.(b) <> d then (idom.(b) <- d; changed := true)) !order
  done;
  idom

let check (fn : func) =
  let idom = dominators fn in
  let rec dominates a b = a = b || (b <> 0 && idom.(b) >= 0 && dominates a idom.(b)) in
  let block_of = Hashtbl.create 256 and index = Hashtbl.create 256 in
  Array.iter (fun (b : block) ->
    List.iter (fun v -> Hashtbl.replace block_of v b.id; Hashtbl.replace index v (-1)) b.phis;
    List.iteri (fun i v -> Hashtbl.replace block_of v b.id; Hashtbl.replace index v i) b.body) fn.blocks;
  let fail fmt = Printf.ksprintf (fun m -> failwith (fn.name ^ ": ssa: " ^ m)) fmt in
  let defined v = if not (Hashtbl.mem block_of v) then fail "v%d used, never defined" v in
  (* v's definition before position i of block b (at its end: max_int) *)
  let before v b i =
    defined v;
    let db = Hashtbl.find block_of v in
    if db = b then (if Hashtbl.find index v >= i then fail "v%d used before its definition in b%d" v b)
    else if not (dominates db b) then fail "v%d (b%d) does not dominate its use in b%d" v db b
  in
  Array.iter (fun (b : block) ->
    List.iter (fun phi ->
      match Hashtbl.find fn.defs phi with
      | Phi ops ->
          if List.sort compare (List.map fst ops) <> List.sort compare b.preds then fail "v%d: a phi's operands are not b%d's predecessors" phi b.id;
          List.iter (fun (p, v) -> before v p max_int) ops
      | _ -> fail "v%d: a phi that is not" phi) b.phis;
    List.iteri (fun i v -> List.iter (fun u -> before u b.id i) (operands (Hashtbl.find fn.defs v))) b.body;
    let term_uses = match b.term with Br (v, _, _) | Ret v | Raise v -> [ v ] | Tail (_, vs) -> vs | _ -> [] in
    List.iter (fun u -> before u b.id max_int) term_uses) fn.blocks

(*****************************************************************************)
(* -dssa *)
(*****************************************************************************)

let show_op (o : L.op) = L.show_op o
let show_target = function L.Direct f -> f | L.Code k -> Printf.sprintf "field%d" k
let vs l = String.concat " " (List.map (Printf.sprintf "v%d") l)

let show_ins = function
  | Const n -> Printf.sprintf "int %d" n
  | Zero -> "zero"
  | Blk s -> "block " ^ s
  | Symb s -> "sym " ^ s
  | Param i -> Printf.sprintf "param %d" i
  | Phi ops -> "phi " ^ String.concat " " (List.map (fun (b, v) -> Printf.sprintf "[b%d v%d]" b v) ops)
  | GetG g -> "getg " ^ g
  | SetG (g, v) -> Printf.sprintf "setg %s v%d" g v
  | Slot i -> Printf.sprintf "slot %d" i
  | SetSlot (i, v) -> Printf.sprintf "setslot %d v%d" i v
  | Field (k, v) -> Printf.sprintf "field %d v%d" k v
  | SetField (k, b, v) -> Printf.sprintf "setfield %d v%d v%d" k b v
  | Index (b, i) -> Printf.sprintf "index v%d v%d" b i
  | SetIndex (b, i, v) -> Printf.sprintf "setindex v%d v%d v%d" b i v
  | Alloc (t, l) -> Printf.sprintf "alloc %d %s" t (vs l)
  | Op (o, l) -> Printf.sprintf "%s %s" (show_op o) (vs l)
  | Call (t, l) -> Printf.sprintf "call %s %s" (show_target t) (vs l)
  | CallC (g, l) -> Printf.sprintf "callc %s %s" g (vs l)
  | Caught k -> Printf.sprintf "caught %d" k
  | TryExit k -> Printf.sprintf "untry %d" k

let show_term = function
  | Jmp s -> Printf.sprintf "jmp b%d" s
  | Br (v, a, b) -> Printf.sprintf "br v%d b%d b%d" v a b
  | Try (k, a, h) -> Printf.sprintf "try %d b%d, handler b%d" k a h
  | Ret v -> Printf.sprintf "ret v%d" v
  | Raise v -> Printf.sprintf "raise v%d" v
  | Tail (t, l) -> Printf.sprintf "tail %s %s" (show_target t) (vs l)

let show (fn : func) =
  let b = Buffer.create 1024 in
  Printf.bprintf b "%s:\n" fn.name;
  Array.iter (fun (bl : block) ->
    Printf.bprintf b "b%d:%s\n" bl.id (if bl.preds = [] then "" else "\t\t; from " ^ String.concat " " (List.map (Printf.sprintf "b%d") bl.preds));
    List.iter (fun v -> Printf.bprintf b "\tv%d = %s\n" v (show_ins (Hashtbl.find fn.defs v))) (bl.phis @ bl.body);
    Printf.bprintf b "\t%s\n" (show_term bl.term)) fn.blocks;
  Buffer.contents b

let func (f : L.func) = let fn = simplify (build f) in check fn; fn

(*****************************************************************************)
(* Out of SSA, to the stack machine: every value in its own slot *)
(*****************************************************************************)

(* a label no function of the unit uses (Lower's are the unit's) *)
let labels = ref 0

let highest (u : L.unit_) =
  List.fold_left (fun m (f : L.func) ->
    List.fold_left (fun m -> function L.Label l | Jmp l | Jz l | Jnz l | TryEnter (_, l) -> max m l | _ -> m) m f.code) 0 u.funcs

let label () = incr labels; !labels

(* The simplest correct code (plan's phase 2): each value in a slot of
 * its own, after the stack code's (its slots are the handlers'
 * functions' memory); an instruction its operands pushed from their
 * slots, its stack instruction, its result stored; a phi a parallel
 * copy at each predecessor's end (all pushed, then all stored), on an
 * edge of its own when the predecessor branches. The parameters are
 * their slots already (the prologue stores them), and a Zero's slot is
 * never written (the prologue zeroes them all). simple's Gen compiles
 * the result: its calls, allocations and handlers, unchanged *)
let out (lf : L.func) (fn : func) : L.func =
  let base = lf.nslots in
  let slot v = match Hashtbl.find fn.defs v with Param i -> i | _ -> base + v in
  let code = ref [] in
  let emit i = code := i :: !code in
  let get v = emit (L.Get (slot v)) in
  let set v = emit (L.Set (slot v)) in
  let lbl = Array.map (fun (_ : block) -> label ()) fn.blocks in
  let copies p s =
    let moves = List.filter_map (fun phi -> match Hashtbl.find fn.defs phi with Phi ops -> Some (phi, List.assoc p ops) | _ -> None) fn.blocks.(s).phis in
    List.iter (fun (_, src) -> get src) moves;
    List.iter (fun (dst, _) -> set dst) (List.rev moves)
  in
  (* the edge p -> s, a label to jump to; a block of its own for the
   * copies when p has two successors *)
  let split = ref [] in
  let edge p s ~alone =
    if fn.blocks.(s).phis = [] then lbl.(s)
    else if alone then (copies p s; lbl.(s))
    else (let l = label () in split := (l, p, s) :: !split; l)
  in
  Array.iter (fun (b : block) ->
    if b.id > 0 then emit (L.Label lbl.(b.id));
    List.iter (fun v ->
      match Hashtbl.find fn.defs v with
      | Zero | Param _ -> ()
      | Const n -> emit (L.Int n); set v
      | Blk s -> emit (L.Block s); set v
      | Symb s -> emit (L.Sym s); set v
      | GetG g -> emit (L.GetG g); set v
      | SetG (g, x) -> get x; emit (L.SetG g)
      | Slot i -> emit (L.Get i); set v
      | SetSlot (i, x) -> get x; emit (L.Set i)
      | Field (k, x) -> get x; emit (L.Field k); set v
      | SetField (k, blk, x) -> get x; get blk; emit (L.SetField k)
      | Index (blk, i) -> get i; get blk; emit L.Index; set v
      | SetIndex (blk, i, x) -> get x; get i; get blk; emit L.SetIndex
      | Alloc (t, xs) -> List.iter get (List.rev xs); emit (L.Alloc (t, List.length xs)); set v
      | Op (o, xs) -> List.iter get (List.rev xs); emit (L.Op o); set v
      | Call (t, xs) -> emit (L.Call (t, List.map slot xs, false)); set v
      | CallC (g, xs) -> List.iter get (List.rev xs); emit (L.CallC (g, List.length xs)); set v
      | Caught k -> emit (L.Catch k); set v
      | TryExit k -> emit (L.TryExit k)
      | Phi _ -> ()) b.body;
    match b.term with
    | Jmp s -> let l = edge b.id s ~alone:true in emit (L.Jmp l)
    | Br (v, t, e) ->
        let lt = edge b.id t ~alone:false and le = edge b.id e ~alone:false in
        get v; emit (L.Jz le); emit (L.Jmp lt)
    | Try (k, body, h) -> emit (L.TryEnter (k, lbl.(h))); emit (L.Jmp (edge b.id body ~alone:false))
    | Ret v -> get v; emit L.Ret
    | Raise v -> get v; emit L.Raise
    | Tail (t, xs) -> emit (L.Call (t, List.map slot xs, true))) fn.blocks;
  List.iter (fun (l, p, s) -> emit (L.Label l); copies p s; emit (L.Jmp lbl.(s))) (List.rev !split);
  let values = Hashtbl.fold (fun v _ m -> max m (v + 1)) fn.defs 0 in
  { lf with nslots = base + values; code = List.rev !code }

let unit_ (u : L.unit_) =
  labels := highest u;
  { u with funcs = List.map (fun (f : L.func) -> out f (func f)) u.funcs }
