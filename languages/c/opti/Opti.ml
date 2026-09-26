(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Opti.mli *)

open Lower

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
  | Int (c, _) :: Op (o, (I _ as t)) :: (Jz l | Jnz l as j) :: rest when Tree.is_rel o ->
      Br (o, t, Some c, (match j with Jnz _ -> true | _ -> false), l) :: branch rest
  | Op (o, t) :: (Jz l | Jnz l as j) :: rest when Tree.is_rel o ->
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
(* The passes *)
(*****************************************************************************)

let passes = [ "incs", incs; "places", places; "imm", imm; "branch", branch; "drops", drops ]

let run names (f : func) =
  { f with code = List.fold_left (fun code (name, pass) -> if List.mem name names then pass code else code) f.code passes }
