(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Opti.mli *)

open Ir

(* the stack slots an instruction reads, and the ones it pushes *)
let arity = function
  | Int _ | Flt _ | Lea _ | LoadAt _ -> 0, 1
  | Load _ | Neg _ | Com _ | Cvt _ | OpImm _ | StoreAt _ -> 1, 1
  | Store _ | Copy _ | Op _ -> 2, 1
  | Dup -> 1, 2
  | Drop | Arg _ | ArgBlock _ | PutAt _ | Jz _ | Jnz _ -> 1, 0
  | Swap -> 2, 2
  | Over -> 2, 3
  | Put _ -> 2, 0
  | Br (_, _, c, _, _) -> (if c = None then 2 else 1), 0
  | Call (t, _, rt) -> (if t = Indirect then 1 else 0), if rt = None then 0 else 1
  | Ret t -> (if t = None then 0 else 1), 0
  | Label _ | Jmp _ -> 0, 0
  | GetReg _ -> 0, 1
  | SetReg _ -> 1, 0
  | KeepReg _ -> 1, 1

(*****************************************************************************)
(* incs: x++ as a statement is ++x *)
(*****************************************************************************)

(* Lower's x++ keeps the old value under the address (swap, over), for
 * a statement to drop it *)
let rec incs = function
  | Dup :: Load t :: Swap :: Over :: one :: Op (o, t') :: Store t'' :: Drop :: Drop :: rest ->
      Dup :: Load t :: one :: Op (o, t') :: Store t'' :: Drop :: incs rest
  (* x++ of a variable: as a statement its new value stored; as a value
   * the old one kept by a dup *)
  | Lea m :: Dup :: Load t :: Swap :: Over :: one :: Op (o, t') :: Store t'' :: Drop :: Drop :: rest ->
      LoadAt (m, t) :: one :: Op (o, t') :: PutAt (m, t'') :: incs rest
  | Lea m :: Dup :: Load t :: Swap :: Over :: one :: Op (o, t') :: Store t'' :: Drop :: rest ->
      LoadAt (m, t) :: Dup :: one :: Op (o, t') :: PutAt (m, t'') :: incs rest
  | i :: rest -> i :: incs rest
  | [] -> []

(*****************************************************************************)
(* places: a global's, an auto's, a parameter's address in the load or
 * the store *)
(*****************************************************************************)

(* the instruction that reads the slot at height 1, when the code above
 * it starts at height [h]: the code before it, it, the height it found
 * the stack at, and the rest; None at a label or a jump, which would
 * need the stack's height on the other paths *)
let consumer h code =
  let rec go h acc = function
    | ((Label _ | Jmp _ | Jz _ | Jnz _ | Br _ | Ret _) :: _) | [] -> None
    | i :: rest ->
        let reads, pushes = arity i in
        if h - reads <= 0 then Some (List.rev acc, i, h, rest) else go (h - reads + pushes) (i :: acc) rest
  in
  go h [] code

let rec places = function
  | Lea m :: Load t :: rest -> LoadAt (m, t) :: places rest
  | (Lea m :: Dup :: Load t :: after) as code -> (
      (* x op= y: the address kept under the value, for the store *)
      match consumer 2 after with
      | Some (before, Store t', 2, rest) -> LoadAt (m, t) :: places (before @ (StoreAt (m, t') :: rest))
      | _ -> step code)
  | (Lea m :: after) as code -> (
      match consumer 1 after with
      | Some (before, Store t, 2, rest) -> places (before @ (StoreAt (m, t) :: rest))
      | _ -> step code)
  | code -> step code

and step = function i :: rest -> i :: places rest | [] -> []

(*****************************************************************************)
(* imm: a constant operand as the instruction's immediate *)
(*****************************************************************************)

let immediate = function Tree.Add | Sub | And | Or | Xor | Ashl | Ashr | Lshr -> true | _ -> false
let commutes = function Tree.Add | And | Or | Xor -> true | _ -> false

(* log2 of a power of 2, or None *)
let log2 c = List.find_opt (fun k -> Int64.shift_left 1L k = c) (List.init 63 Fun.id)

let rec imm = function
  | Int (c, _) :: Op (o, (I _ as t)) :: rest when immediate o -> OpImm (o, t, c) :: imm rest
  (* by a power of 2, a multiplication is a shift *)
  | Int (c, _) :: Op ((Mul | Lmul), (I _ as t)) :: rest when log2 c <> None ->
      OpImm (Ashl, t, Int64.of_int (Option.get (log2 c))) :: imm rest
  (* the constant first, the deeper operand having been computed first *)
  | Int (c, _) :: Swap :: Op (o, (I _ as t)) :: rest when commutes o -> OpImm (o, t, c) :: imm rest
  | i :: rest -> i :: imm rest
  | [] -> []

(*****************************************************************************)
(* branch: a comparison and its jump, no 1 or 0 between *)
(*****************************************************************************)

let rec branch = function
  | Int (c, _) :: Op (o, (I _ as t)) :: (Jz l | Jnz l as j) :: rest when Tree_helpers.is_rel o ->
      Br (o, t, Some c, (match j with Jnz _ -> true | _ -> false), l) :: branch rest
  | Op (o, t) :: (Jz l | Jnz l as j) :: rest when Tree_helpers.is_rel o ->
      Br (o, t, None, (match j with Jnz _ -> true | _ -> false), l) :: branch rest
  | i :: rest -> i :: branch rest
  | [] -> []

(*****************************************************************************)
(* drops: a stored value thrown away is not kept; a conversion to its
 * own type is nothing *)
(*****************************************************************************)

let rec puts = function
  | Store t :: Drop :: rest -> Put t :: puts rest
  | StoreAt (m, t) :: Drop :: rest -> PutAt (m, t) :: puts rest
  (* the order of an integer's commutative operands *)
  | Swap :: (Op (o, I _) as op) :: rest when commutes o -> op :: puts rest
  | i :: rest -> i :: puts rest
  | [] -> []

(* a conversion that changes no value: to its own type, or wider from
 * a type the wider one holds (unsigned char to int) *)
let nothing = function
  | Cvt (a, b) when a = b -> true
  | Cvt (I (w1, s1), I (w2, s2)) -> w1 < w2 && ((not s1) || s2)
  | _ -> false

(* the conversions first: x op= y's stands between the store and the
 * statement's drop *)
let drops code = puts (List.filter (fun i -> not (nothing i)) code)

(*****************************************************************************)
(* regs: variables in registers (5c's regopt, freely) *)
(*****************************************************************************)

module IS = Set_

(* a variable a register may hold: an auto or a parameter (not a
 * temporary) only loaded and stored whole, by places' forms, with one
 * type; a lea of it (its address taken, or a use places left) rules
 * it out *)
let variables (code : Ir.t array) =
  let seen = Hashtbl.create 16 and out = Hashtbl.create 16 in
  let is_var (m : Asm.mem) =
    (m.base = Asm.SP || m.base = Asm.FP) && (match m.name with Some n -> n.sym <> ".safe" | None -> false) in
  Array.iter (function
    | LoadAt (m, t) | StoreAt (m, t) | PutAt (m, t) when is_var m -> (
        match Hashtbl.find_opt seen m with
        | Some t' when t' <> t -> Hashtbl.replace out m ()
        | _ -> Hashtbl.replace seen m t)
    | Lea m -> Hashtbl.replace out m ()
    | _ -> ()) code;
  (* sorted: a table's order is its hash function's, not the same by OCaml's
   * stdlib and by ix's, and the registers given follow this order *)
  List.sort compare (Hashtbl.fold (fun m t acc -> if Hashtbl.mem out m then acc else (m, t) :: acc) seen [])

(* each instruction's successors, by the labels' positions *)
let successors (code : Ir.t array) =
  let at = Hashtbl.create 16 in
  Array.iteri (fun i -> function Label l -> Hashtbl.replace at l i | _ -> ()) code;
  let n = Array.length code in
  Array.mapi (fun i ins ->
    let next = if i + 1 < n then [ i + 1 ] else [] in
    match ins with
    | Jmp l -> [ Hashtbl.find at l ]
    | Ret _ -> []
    | Jz l | Jnz l | Br (_, _, _, _, l) -> Hashtbl.find at l :: next
    | _ -> next) code

(* the variables live after each instruction: a backward dataflow, to
 * its fixpoint (the Dragon book's liveness, 5c's prop over bit sets) *)
let liveness (code : Ir.t array) succ (index : Asm.mem -> int option) =
  let n = Array.length code in
  let use i = match code.(i) with LoadAt (m, _) -> Option.to_list (index m) | _ -> [] in
  let def i = match code.(i) with StoreAt (m, _) | PutAt (m, _) -> Option.to_list (index m) | _ -> [] in
  let live_in = Array.make n IS.empty and live_out = Array.make n IS.empty in
  let changed = ref true in
  while !changed do
    changed := false;
    for i = n - 1 downto 0 do
      let out = List.fold_left (fun s j -> IS.union s live_in.(j)) IS.empty succ.(i) in
      let inn = IS.union (IS.of_list (use i)) (IS.diff out (IS.of_list (def i))) in
      live_out.(i) <- out;
      if not (IS.equal inn live_in.(i)) then (live_in.(i) <- inn; changed := true)
    done
  done;
  live_out

(* how deep in loops each instruction is: a jump back to a label makes
 * what is between them a loop *)
let depths (code : Ir.t array) succ =
  let d = Array.make (Array.length code) 0 in
  Array.iteri (fun j _ ->
    match code.(j) with
    | Jmp _ | Jz _ | Jnz _ | Br _ -> List.iter (fun p -> if p <= j then for i = p to j do d.(i) <- d.(i) + 1 done) succ.(j)
    | _ -> ()) code;
  d

let regs (code : Ir.t list) =
  let code = Array.of_list code in
  let vars = Array.of_list (variables code) in
  let index m = let rec go i = if i >= Array.length vars then None else if fst vars.(i) = m then Some i else go (i + 1) in go 0 in
  let succ = successors code in
  let live = liveness code succ index in
  let depth = depths code succ in
  (* a use saves a memory access, times 4 a loop level; a call it is
   * live across costs a store and a load *)
  let weight i = 1 lsl (2 * min depth.(i) 8) in
  let gain = Array.make (Array.length vars) 0 in
  Array.iteri (fun i ins ->
    match ins with
    | LoadAt (m, _) | StoreAt (m, _) | PutAt (m, _) -> Option.iter (fun v -> gain.(v) <- gain.(v) + weight i) (index m)
    | Call _ -> IS.iter (fun v -> gain.(v) <- gain.(v) - (2 * weight i)) live.(i)
    | _ -> ()) code;
  let nint, nfloat = Gen.vregs () in
  let chosen = Hashtbl.create 8 in
  let choose float n =
    let cands = List.filter (fun v -> gain.(v) > 0 && (match snd vars.(v) with F _ -> float | I _ -> not float)) (List.init (Array.length vars) Fun.id) in
    let cands = List.sort (fun a b -> compare gain.(b) gain.(a)) cands in
    List.iteri (fun k v -> if k < n then Hashtbl.replace chosen v k) cands
  in
  choose false nint;
  choose true nfloat;
  let reg m = Option.bind (index m) (Hashtbl.find_opt chosen) in
  let out = ref [] in
  let emit i = out := i :: !out in
  (* a parameter in a register starts with its value *)
  List.iter (fun (v, k) -> let m, t = vars.(v) in if m.base = Asm.FP then (emit (LoadAt (m, t)); emit (SetReg (k, t))))
    (List.sort compare (Hashtbl.fold (fun v k acc -> (v, k) :: acc) chosen []));
  Array.iteri (fun i ins ->
    match ins with
    | LoadAt (m, t) when reg m <> None -> emit (GetReg (Option.get (reg m), t))
    | StoreAt (m, t) when reg m <> None -> emit (KeepReg (Option.get (reg m), t))
    | PutAt (m, t) when reg m <> None -> emit (SetReg (Option.get (reg m), t))
    | Call _ ->
        (* every register is the caller's to save: the variables live
         * after the call, to their slots and back *)
        let across = IS.filter (fun v -> Hashtbl.mem chosen v) live.(i) in
        IS.iter (fun v -> let m, t = vars.(v) in emit (GetReg (Hashtbl.find chosen v, t)); emit (PutAt (m, t))) across;
        emit ins;
        IS.iter (fun v -> let m, t = vars.(v) in emit (LoadAt (m, t)); emit (SetReg (Hashtbl.find chosen v, t))) across
    | ins -> emit ins) code;
  List.rev !out

(*****************************************************************************)
(* The passes *)
(*****************************************************************************)

let passes = [ "incs", incs; "places", places; "imm", imm; "branch", branch; "drops", drops; "regs", regs ]

let run names (f : func) =
  { f with code = List.fold_left (fun code (name, pass) -> if List.mem name names then pass code else code) f.code passes }
