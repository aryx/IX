(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ssa_build.mli *)

(* Ir for its types' I and F, Ssa for the instructions *)
open Ir
open Ssa

(*****************************************************************************)
(* Blocks, from the labels and the jumps *)
(*****************************************************************************)

(* a run of instructions, and the jump that ends it if any *)
type raw = { label : int option; code : Ir.t list; last : Ir.t option }

let ends : Ir.t -> bool = function
  | Jmp _ | Jz _ | Jnz _ | Br _ | Ret _ -> true | _ -> false

let split (code : Ir.t list) =
  let out = ref [] and label = ref None and cur = ref [] in
  let close last =
    out := { label = !label; code = List.rev !cur; last } :: !out;
    label := None; cur := [] in
  List.iter (fun (i : Ir.t) ->
    match i with
    | Label l ->
        if !cur <> [] || !label <> None then close None; label := Some l
    | i when ends i -> close (Some i)
    | i -> cur := i :: !cur) code;
  if !cur <> [] || !label <> None then close None;
  Array.of_list (List.rev !out)

(* the run of each label *)
let runs (raws : raw array) =
  let at = Hashtbl.create 16 in
  Array.iteri (fun i r ->
    Option.iter (fun l -> Hashtbl.replace at l i) r.label) raws;
  Hashtbl.find at

(* each run's successors: the next run, a label's; a branch to the next
 * run has one *)
let successors (raws : raw array) =
  let lbl = runs raws in
  Array.mapi (fun i r ->
    let next = if i + 1 < Array.length raws then [ i + 1 ] else [] in
    match r.last with
    | None -> next
    | Some (Jmp l) -> [ lbl l ]
    | Some (Jz l | Jnz l | Br (_, _, _, _, l)) ->
        List.sort_uniq compare (next @ [ lbl l ])
    | Some _ -> []) raws

(*****************************************************************************)
(* Braun et al.'s construction *)
(*****************************************************************************)

(* the variables: one a register may hold, and a position of the stack
 * at a block's edge *)
type var = Mem_var of mem | Stack_var of int

(* the C variables SSA names: Opti.variables's, and those it leaves for
 * being read or written as integers of one size but another sign (a
 * value read as a uvalue, gc.c's): the type of the first access, a
 * conversion at the others *)
let variables (code : Ir.t array) =
  let seen = Hashtbl.create 16 and out = Hashtbl.create 16 in
  let is_var (m : Asm.mem) =
    (m.base = Asm.SP || m.base = Asm.FP)
    && (match m.name with Some n -> n.sym <> ".safe" | None -> false) in
  let size = function I (n, _) -> Some n | F _ -> None in
  Array.iter (fun (i : Ir.t) ->
    match i with
    | LoadAt (m, t) | StoreAt (m, t) | PutAt (m, t) when is_var m -> (
        match Hashtbl.find_opt seen m with
        | Some t' when t' <> t && (size t = None || size t <> size t') ->
            Hashtbl.replace out m ()
        | Some _ -> ()
        | None -> Hashtbl.replace seen m t)
    | Lea m -> Hashtbl.replace out m ()
    | _ -> ()) code;
  List.sort compare
    (Hashtbl.fold (fun m t acc ->
       if Hashtbl.mem out m then acc else (m, t) :: acc) seen [])

let build (f : Ir.func) =
  let code = Array.of_list f.code in
  let vars = variables code in
  let is_var m = List.mem_assoc m vars in
  let word = Ir.I ((if Emit.arm () then 4 else 8), false) in
  (* the entry has no predecessor: an empty one before a first label *)
  let raws = split f.code in
  let raws =
    if Array.length raws > 0 && raws.(0).label <> None then
      Array.append [| { label = None; code = []; last = None } |] raws
    else raws in
  let succ = successors raws and run = runs raws in
  (* the runs the entry reaches, numbered in order *)
  let n = Array.length raws in
  let reach = Array.make n false in
  let rec visit i =
    if not reach.(i) then (reach.(i) <- true; List.iter visit succ.(i)) in
  if n > 0 then visit 0;
  let ids = Array.make n (-1) and count = ref 0 in
  Array.iteri (fun i r -> if r then (ids.(i) <- !count; incr count)) reach;
  let blocks =
    Array.init !count (fun id ->
      { id; phis = []; body = []; term = Ret None; preds = [] }) in
  let raw_of = Array.make !count 0 in
  Array.iteri (fun i r -> if r then raw_of.(ids.(i)) <- i) reach;
  let bsucc b = List.map (fun i -> ids.(i)) succ.(raw_of.(b)) in
  Array.iter (fun (b : block) ->
    List.iter (fun s -> blocks.(s).preds <- blocks.(s).preds @ [ b.id ])
      (bsucc b.id)) blocks;
  (* each block's stack at its entry *)
  let depth = Array.make !count (-1) in
  let rec flow b d =
    if depth.(b) < 0 then begin
      depth.(b) <- d;
      let r = raws.(raw_of.(b)) in
      let d =
        List.fold_left (fun d i -> let p, q = Opti.arity i in d - p + q)
          d r.code in
      let d =
        match r.last with
        | Some i -> let p, q = Opti.arity i in d - p + q
        | None -> d in
      List.iter (fun s -> flow s d) (bsucc b)
    end
  in
  if !count > 0 then flow 0 0;
  (* the values *)
  let defs = Hashtbl.create 256 and types = Hashtbl.create 256
  and next = ref 0 in
  let fresh ins t =
    let v = !next in
    incr next; Hashtbl.replace defs v ins; Hashtbl.replace types v t; v in
  let emit b ins t =
    let v = fresh ins t in blocks.(b).body <- blocks.(b).body @ [ v ]; v in
  let ty v = Hashtbl.find types v in
  (* a phi's type: its variable's, or (a stack's slot) its operands' *)
  let var_ty = function
    | Mem_var m -> Some (List.assoc m vars) | Stack_var _ -> None in
  let new_phi var b =
    let v =
      fresh (Phi []) (match var_ty var with Some t -> t | None -> word) in
    blocks.(b).phis <- blocks.(b).phis @ [ v ];
    v
  in
  let set_operands var phi ops =
    Hashtbl.replace defs phi (Phi ops);
    (* a stack slot's phi: the type of the value it chooses *)
    if var_ty var = None then
      List.iter (fun (_, v) ->
        match Hashtbl.find defs v with
        | Phi _ -> ()
        | _ -> Hashtbl.replace types phi (ty v)) ops
  in
  let missing var b =
    let t = match var_ty var with Some t -> t | None -> word in
    emit b (Undef t) t
  in
  (* Braun et al.'s reads and seals, lib_code's (old: their copy here,
   * a block's incomplete phis given their operands oldest first) *)
  let br =
    Braun.create ~preds:(fun b -> blocks.(b).preds) ~new_phi ~set_operands
      ~missing !count in
  let write var b v = Braun.write br var b v
  and read var b = Braun.read br var b in
  let seal b = Braun.seal br b and seal_ready () = Braun.seal_ready br in
  (* the entry: the parameters, as the prologue leaves them *)
  if !count > 0 then begin
    seal 0;
    List.iter (fun ((m : mem), t) ->
      if m.base = Asm.FP then write (Mem_var m) 0 (emit 0 (Param (m, t)) t))
      vars
  end;
  Array.iter (fun (b : block) ->
    let id = b.id in
    let r = raws.(raw_of.(id)) in
    let stack =
      ref (List.init depth.(id) (fun d -> read (Stack_var d) id) |> List.rev)
    in
    let push v = stack := v :: !stack in
    let pop () =
      match !stack with
      | v :: rest -> stack := rest; v
      | [] -> failwith (f.name.name ^ ": ssa: the stack is empty") in
    let top () =
      match !stack with
      | v :: _ -> v
      | [] -> failwith (f.name.name ^ ": ssa: the stack is empty") in
    let value ins t = push (emit id ins t) in
    let for_effect ins = ignore (emit id ins word) in
    (* a variable read or written as another type of its size: its
     * bits as that type, what a load would extend them to; none for a
     * register's size (arm's int and unsigned) *)
    let conv x y v =
      match x, y with
      | _ when x = y -> v
      | I (n, _), I (n', _) when n = n' && I (n, false) = word -> v
      | _ -> emit id (Cvt (x, y, v)) y
    in
    List.iter (fun (i : Ir.t) ->
      match i with
      | Int (c, t) -> value (Const (c, t)) t
      | Flt (x, t) -> value (Fconst (x, t)) t
      | Lea m -> value (Addr m) word
      | Load t -> let a = pop () in value (Load (t, a, 0)) t
      | Store t ->
          let v = pop () in
          let a = pop () in
          for_effect (Store (t, a, 0, v)); push v
      | Copy k ->
          let s = pop () in
          let d = pop () in
          for_effect (Copy (k, d, s)); push d
      | Op (o, t) ->
          let b = pop () in let a = pop () in
          value (Op (o, t, a, b)) (if Tree_helpers.is_rel o then word else t)
      | Neg t -> let a = pop () in value (Neg (t, a)) t
      | Com t -> let a = pop () in value (Com (t, a)) t
      | Cvt (x, y) -> let a = pop () in value (Cvt (x, y, a)) y
      | Dup -> push (top ())
      | Drop -> ignore (pop ())
      | Swap -> let b = pop () in let a = pop () in push b; push a
      | Over -> let b = pop () in let a = pop () in push a; push b; push a
      | Arg (o, t) -> let v = pop () in for_effect (Arg (o, t, v))
      | ArgBlock (o, k) -> let v = pop () in for_effect (ArgBlock (o, k, v))
      | Call (target, r0, rt) ->
          let a = if target = Indirect then Some (pop ()) else None in
          (match rt with
           | Some t -> value (Call (target, a, r0, rt)) t
           | None -> for_effect (Call (target, a, r0, rt)))
      | LoadAt (m, t) ->
          if is_var m then
            push (conv (List.assoc m vars) t (read (Mem_var m) id))
          else value (LoadAt (m, t)) t
      | StoreAt (m, t) ->
          let v = top () in
          if is_var m then write (Mem_var m) id (conv t (List.assoc m vars) v)
          else for_effect (StoreAt (m, t, v))
      | Put t ->
          let v = pop () in let a = pop () in for_effect (Store (t, a, 0, v))
      | PutAt (m, t) ->
          let v = pop () in
          if is_var m then write (Mem_var m) id (conv t (List.assoc m vars) v)
          else for_effect (StoreAt (m, t, v))
      | OpImm (o, t, c) ->
          let a = pop () in
          value (OpImm (o, t, a, c)) (if Tree_helpers.is_rel o then word else t)
      | Label _ | Jmp _ | Jz _ | Jnz _ | Br _ | Ret _ -> ()
      | GetReg _ | SetReg _ | KeepReg _ ->
          failwith (f.name.name ^ ": ssa: Opti's regs before ssa/")) r.code;
    let succs = bsucc id in
    let target l = ids.(run l) in
    (b.term <-
       match r.last, succs with
       | (Some (Jmp _) | None), [ s ] -> Jmp s
       | Some (Jz _ | Jnz _ | Br _), [ s ] ->
           (match r.last with
            | Some (Br (_, _, None, _, _)) -> ignore (pop ())
            | _ -> ());
           ignore (pop ()); Jmp s
       | Some (Jz l), [ _; _ ] ->
           let v = pop () in
           Br (Eq, ty v, v, Imm 0L, target l,
               List.find (fun s -> s <> target l) succs)
       | Some (Jnz l), [ _; _ ] ->
           let v = pop () in
           Br (Ne, ty v, v, Imm 0L, target l,
               List.find (fun s -> s <> target l) succs)
       | Some (Br (o, t, c, tr, l)), [ _; _ ] ->
           let b = match c with Some c -> Imm c | None -> V (pop ()) in
           let a = pop () in
           let nx = List.find (fun s -> s <> target l) succs in
           if tr then Br (o, t, a, b, target l, nx)
           else Br (o, t, a, b, nx, target l)
       | Some (Ret t), _ -> Ret (Option.map (fun _ -> pop ()) t)
       | None, [] -> Ret None
       | _ -> failwith (f.name.name ^ ": ssa: a block's end"));
    (* the stack left, for the successors *)
    List.iteri (fun d v -> write (Stack_var d) id v) (List.rev !stack);
    Braun.fill br id;
    seal_ready ()) blocks;
  Braun.seal_rest br;
  { name = f.name; locals = f.locals; args = f.args; r0 = f.r0; blocks; defs;
    types }

(*****************************************************************************)
(* Trivial phis out *)
(*****************************************************************************)

let operands = function
  | Const _ | Fconst _ | Addr _ | Undef _ | Param _ | LoadAt _ -> []
  | Phi ops -> List.map snd ops
  | Load (_, a, _) | StoreAt (_, _, a) | OpImm (_, _, a, _) | Neg (_, a)
  | Com (_, a) | Cvt (_, _, a) | Arg (_, _, a) | ArgBlock (_, _, a) -> [ a ]
  | Store (_, a, _, b) | Copy (_, a, b) | Op (_, _, a, b) -> [ a; b ]
  | Call (_, a, _, _) -> Option.to_list a

let map_ins f = function
  | Phi ops -> Phi (List.map (fun (b, v) -> b, f v) ops)
  | Load (t, a, k) -> Load (t, f a, k)
  | StoreAt (m, t, a) -> StoreAt (m, t, f a)
  | OpImm (o, t, a, c) -> OpImm (o, t, f a, c)
  | Neg (t, a) -> Neg (t, f a)
  | Com (t, a) -> Com (t, f a)
  | Cvt (x, y, a) -> Cvt (x, y, f a)
  | Arg (o, t, a) -> Arg (o, t, f a)
  | ArgBlock (o, k, a) -> ArgBlock (o, k, f a)
  | Store (t, a, k, b) -> Store (t, f a, k, f b)
  | Copy (k, a, b) -> Copy (k, f a, f b)
  | Op (o, t, a, b) -> Op (o, t, f a, f b)
  | Call (g, a, r0, rt) -> Call (g, Option.map f a, r0, rt)
  | i -> i

let term_uses = function
  | Br (_, _, a, V b, _, _) -> [ a; b ]
  | Br (_, _, a, Imm _, _, _) -> [ a ]
  | Ret (Some v) -> [ v ]
  | Jmp _ | Ret None -> []

let map_term f = function
  | Br (o, t, a, b, x, y) ->
      Br (o, t, f a, (match b with V b -> V (f b) | b -> b), x, y)
  | Ret v -> Ret (Option.map f v)
  | t -> t

(* a phi whose operands are one value (and itself) is that value; until
 * none is (Braun et al.'s tryRemoveTrivialPhi, as a fixpoint) *)
let simplify (fn : func) =
  (* (lib_code's Braun.trivial) *)
  let find =
    Braun.trivial ~phis:(fun b -> fn.blocks.(b).phis)
      ~set_phis:(fun b l -> fn.blocks.(b).phis <- l)
      ~operands:(fun phi ->
        match Hashtbl.find fn.defs phi with
        | Phi ops -> Some (List.map snd ops)
        | _ -> None)
      (Array.length fn.blocks)
  in
  Array.iter (fun (b : block) ->
    List.iter (fun v ->
      Hashtbl.replace fn.defs v (map_ins find (Hashtbl.find fn.defs v)))
      (b.phis @ b.body);
    b.term <- map_term find b.term) fn.blocks;
  (* a stack slot's phi of phis: its type from the values they choose *)
  let changed = ref true in
  while !changed do
    changed := false;
    Array.iter (fun (b : block) ->
      List.iter (fun phi ->
        match Hashtbl.find fn.defs phi with
        | Phi ((_, v) :: _) ->
            let t = Hashtbl.find fn.types v in
            if Hashtbl.find fn.types phi <> t then
              (Hashtbl.replace fn.types phi t; changed := true)
        | _ -> ()) b.phis) fn.blocks
  done;
  fn

(*****************************************************************************)
(* The check: every use dominated by its definition *)
(*****************************************************************************)

let successors_of (b : block) =
  match b.term with
  | Jmp s -> [ s ] | Br (_, _, _, _, a, b) -> [ a; b ] | Ret _ -> []

(* the immediate dominators (lib_code's Dominators: Cooper, Harvey and
 * Kennedy's) *)
let dominators (fn : func) =
  Dominators.idoms ~succs:(fun b -> successors_of fn.blocks.(b))
    ~preds:(fun b -> fn.blocks.(b).preds) (Array.length fn.blocks)

let check (fn : func) =
  let idom = dominators fn in
  let dominates = Dominators.dominates idom in
  let block_of = Hashtbl.create 256 and index = Hashtbl.create 256 in
  Array.iter (fun (b : block) ->
    List.iter (fun v ->
      Hashtbl.replace block_of v b.id; Hashtbl.replace index v (-1)) b.phis;
    List.iteri (fun i v ->
      Hashtbl.replace block_of v b.id; Hashtbl.replace index v i) b.body)
    fn.blocks;
  let fail fmt =
    Printf.ksprintf (fun m -> failwith (fn.name.name ^ ": ssa: " ^ m)) fmt in
  let defined v =
    if not (Hashtbl.mem block_of v) then fail "v%d used, never defined" v in
  (* v's definition before position i of block b (at its end: max_int) *)
  let before v b i =
    defined v;
    let db = Hashtbl.find block_of v in
    if db = b then
      (if Hashtbl.find index v >= i then
         fail "v%d used before its definition in b%d" v b)
    else if not (dominates db b) then
      fail "v%d (b%d) does not dominate its use in b%d" v db b
  in
  Array.iter (fun (b : block) ->
    List.iter (fun phi ->
      match Hashtbl.find fn.defs phi with
      | Phi ops ->
          if List.sort compare (List.map fst ops) <> List.sort compare b.preds
          then fail "v%d: a phi's operands are not b%d's predecessors" phi b.id;
          List.iter (fun (p, v) -> before v p max_int) ops
      | _ -> fail "v%d: a phi that is not" phi) b.phis;
    List.iteri (fun i v ->
      List.iter (fun u -> before u b.id i) (operands (Hashtbl.find fn.defs v)))
      b.body;
    List.iter (fun u -> before u b.id max_int) (term_uses b.term)) fn.blocks

(*****************************************************************************)
(* -dssa *)
(*****************************************************************************)

let show_ty : ty -> string = function
  | I (n, s) -> Printf.sprintf "%s%d" (if s then "i" else "u") (8 * n)
  | F n -> Printf.sprintf "f%d" (8 * n)

let show_mem = Show_asm.show_mem
let op o = Tree_helpers.binop_name o
let vs l = String.concat " " (List.map (Printf.sprintf "v%d") l)

let show_ins = function
  | Const (c, _) -> Printf.sprintf "$%Ld" c
  | Fconst (x, _) -> Printf.sprintf "$%g" x
  | Addr m -> "$" ^ show_mem m
  | Undef _ -> "undef"
  | Param (m, _) -> "param " ^ show_mem m
  | Phi ops ->
      "phi " ^ String.concat " "
        (List.map (fun (b, v) -> Printf.sprintf "[b%d v%d]" b v) ops)
  | Load (_, a, k) -> Printf.sprintf "load %d(v%d)" k a
  | LoadAt (m, _) -> "load " ^ show_mem m
  | Store (_, a, k, v) -> Printf.sprintf "store %d(v%d) v%d" k a v
  | StoreAt (m, _, v) -> Printf.sprintf "store %s v%d" (show_mem m) v
  | Copy (k, d, s) -> Printf.sprintf "copy %d v%d v%d" k d s
  | Op (o, _, a, b) -> Printf.sprintf "%s v%d v%d" (op o) a b
  | OpImm (o, _, a, c) -> Printf.sprintf "%s v%d $%Ld" (op o) a c
  | Neg (_, a) -> Printf.sprintf "neg v%d" a
  | Com (_, a) -> Printf.sprintf "com v%d" a
  | Cvt (x, y, a) -> Printf.sprintf "cvt %s %s v%d" (show_ty x) (show_ty y) a
  | Arg (o, _, a) -> Printf.sprintf "arg %d v%d" o a
  | ArgBlock (o, k, a) -> Printf.sprintf "argblock %d %d v%d" o k a
  | Call (Direct m, _, _, _) -> "call " ^ show_mem m
  | Call (Indirect, a, _, _) -> "call " ^ vs (Option.to_list a)

let show_term = function
  | Jmp s -> Printf.sprintf "jmp b%d" s
  | Br (o, _, a, b, x, y) ->
      Printf.sprintf "br %s v%d %s b%d b%d" (op o) a
        (match b with
         | V b -> Printf.sprintf "v%d" b
         | Imm c -> Printf.sprintf "$%Ld" c) x y
  | Ret v ->
      "ret" ^ (match v with Some v -> Printf.sprintf " v%d" v | None -> "")

let show (fn : func) =
  let b = Buffer.create 1024 in
  Printf.bprintf b "%s:\n" fn.name.name;
  Array.iter (fun (bl : block) ->
    Printf.bprintf b "b%d:%s\n" bl.id
      (if bl.preds = [] then ""
       else "\t\t; from "
            ^ String.concat " " (List.map (Printf.sprintf "b%d") bl.preds));
    List.iter (fun v ->
      Printf.bprintf b "\tv%d = %s\t; %s\n" v
        (show_ins (Hashtbl.find fn.defs v))
        (show_ty (Hashtbl.find fn.types v))) (bl.phis @ bl.body);
    Printf.bprintf b "\t%s\n" (show_term bl.term)) fn.blocks;
  Buffer.contents b

(*****************************************************************************)
(* Sinking: q + 4 after q's last use *)
(*****************************************************************************)

(* OPTIMIZATION (sink): a pure value of one operand (q + 4, a
 * conversion) moved down its block to after the operand's last use
 * before its own first: the operand may then die where the value is
 * made, the value take its register (Alloc's walk, a phi's register),
 * and an access through q then its add be one post-indexed access
 * (Ssa_gen). Never more values live at once than before: where both
 * were live, now only the operand is. Before, *q++ = *p++ kept q and
 * q + 4 live together, and the loop's edge moved q + 4 into q's
 * register.
 * old: the stack code's order *)
let sink (fn : func) =
  let reads x u = List.mem u (operands (Hashtbl.find fn.defs x)) in
  let operand v =
    match Hashtbl.find fn.defs v with
    | OpImm (_, _, a, _) | Cvt (_, _, a) -> Some a
    | _ -> None in
  (* each moved once: two conversions of one operand would pass each
   * other forever *)
  let moved = Hashtbl.create 16 in
  let rec go = function
    | v :: rest -> (
        match operand v with
        | Some a when not (Hashtbl.mem moved v) ->
            (* the last use of a before the first of v *)
            let rec last k found = function
              | x :: _ when reads x v -> found
              | x :: more ->
                  last (k + 1) (if reads x a then Some k else found) more
              | [] -> found
            in
            (match last 0 None rest with
             | Some k ->
                 Hashtbl.replace moved v ();
                 go (List.filteri (fun i _ -> i <= k) rest
                     @ (v :: List.filteri (fun i _ -> i > k) rest))
             | None -> v :: go rest)
        | _ -> v :: go rest)
    | [] -> []
  in
  Array.iter (fun (b : block) -> b.body <- go b.body) fn.blocks;
  fn

(* OPTIMIZATION (offsets): an integer's load or store through b + k is
 * one at k(b), the add left to no one if nothing else reads it (and
 * then not made: Ssa_gen); k within the smallest of the machines'
 * offsets, arm's MOVH's 8 bits. copy's header, at v - 4, was an ADD
 * then a load.
 * old: the address computed, then the access at 0 *)
let offsets (fn : func) =
  let word = if Emit.arm () then 4 else 8 in
  (* (arm's -4 an unsigned 4294967292: its 32 bits sign-extended) *)
  let fold a k =
    match Hashtbl.find fn.defs a with
    | OpImm (Add, I (n, _), b, c)
      when n = word
           && Int64.abs (Int64.add (Emit.sx c) (Int64.of_int k)) <= 255L ->
        b, k + Int64.to_int (Emit.sx c)
    | _ -> a, k
  in
  Array.iter (fun (b : block) ->
    List.iter (fun v ->
      match Hashtbl.find fn.defs v with
      | Load ((I _ as t), a, k) ->
          let a, k = fold a k in Hashtbl.replace fn.defs v (Load (t, a, k))
      | Store ((I _ as t), a, k, x) ->
          let a, k = fold a k in
          Hashtbl.replace fn.defs v (Store (t, a, k, x))
      | _ -> ()) b.body) fn.blocks;
  fn

let func (f : Ir.func) =
  let fn = sink (offsets (simplify (build f))) in
  check fn;
  fn
