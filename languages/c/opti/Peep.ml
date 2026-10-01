(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Peep.mli *)

module A = Ix_asm.Asm

(* a register: an integer one or a float one *)
type reg = R of int | F of int

let reg_of = function A.Reg r -> Some (R r) | A.FReg r -> Some (F r) | _ -> None

(* the registers an operand reads: itself, or a memory operand's base *)
let reads_op = function
  | A.Reg r -> [ R r ]
  | A.FReg r -> [ F r ]
  | A.Mem { base = A.R r; _ } | A.Addr { base = A.R r; _ } -> [ R r ]
  | _ -> []

(* the instructions whose destination is only written: moves,
 * extensions, conversions, negations; the others with two operands
 * (ADD R2,R1) read it too *)
let writes_only a =
  List.exists (fun p -> String.length a >= String.length p && String.sub a 0 (String.length p) = p)
    [ "MOV"; "FMOV"; "SXT"; "UXT"; "NEG"; "MVN"; "FNEG"; "SCVTF"; "UCVTF"; "FCVT" ]

let is_move (q : Emit.prog) = (q.as_ = "MOV" || q.as_ = "MOVW" && Emit.arm () || q.as_ = "FMOVD" || q.as_ = "MOVD") && q.reg = None

(* what an instruction reads and writes *)
let reads (q : Emit.prog) =
  let from = match q.from with Some o -> reads_op o | None -> [] in
  let reg = match q.reg, q.from with Some r, Some (A.FReg _) -> [ F r ] | Some r, _ -> [ R r ] | None, _ -> [] in
  let to_ =
    match q.to_ with
    | Some (A.Mem _ as o) -> reads_op o
    | Some ((A.Reg _ | A.FReg _) as o) when q.reg = None && not (writes_only q.as_) -> reads_op o
    | _ -> []
  in
  from @ reg @ to_

(* the destination read too, as ADD R2,R1's R1 *)
let accumulates (q : Emit.prog) x =
  q.reg = None && (not (writes_only q.as_)) && (match q.to_ with Some o -> reg_of o = Some x | None -> false)

let writes (q : Emit.prog) = match q.to_ with Some ((A.Reg _ | A.FReg _) as o) -> Option.to_list (reg_of o) | _ -> []

(* where the flow comes in or goes out: a block's end *)
let ends (q : Emit.prog) =
  q.as_ = "BL" || q.as_ = "RET" || q.as_ = "RETURN" || (String.length q.as_ >= 1 && q.as_.[0] = 'B' && q.as_ <> "BIC")

let replace_op x y = function
  | A.Reg _ | A.FReg _ as o when reg_of o = Some x -> (match y with R r -> A.Reg r | F r -> A.FReg r)
  | A.Mem ({ base = A.R r; _ } as m) when x = R r -> (match y with R r' -> A.Mem { m with base = A.R r' } | F _ -> A.Mem m)
  | o -> o

(* in q, a read of x as a read of y *)
let substitute (q : Emit.prog) x y =
  q.from <- Option.map (replace_op x y) q.from;
  (match q.reg with Some r when (match q.from with Some (A.FReg _) -> F r | _ -> R r) = x -> q.reg <- Some (match y with R r | F r -> r) | _ -> ());
  match q.to_ with
  | Some (A.Mem _ as o) -> q.to_ <- Some (replace_op x y o)
  | _ -> ()

let nop (q : Emit.prog) = q.as_ <- "NOP"; q.cond <- []; q.from <- None; q.reg <- None; q.to_ <- None

(* copy propagation (5c's peep.c, copyprop): after MOV y,x, the reads
 * of x read y, until x or y is written or the block ends; when x is
 * written again first, the move is dead. A destination that is also
 * read (ADD R2,x) stops it: its x cannot be renamed alone *)
let copyprop (code : Emit.prog array) targets =
  Array.iteri (fun i (q : Emit.prog) ->
    if is_move q then
      match Option.bind q.from reg_of, Option.bind q.to_ reg_of with
      | Some y, Some x when x <> y ->
          let rec go j =
            if j >= Array.length code || Hashtbl.mem targets code.(j).ppc then false
            else
              let p = code.(j) in
              let r = reads p and w = writes p in
              if accumulates p x then false
              else begin
                if List.mem x r then substitute p x y;
                if List.mem x w then true
                else if List.mem y w || ends p then false
                else go (j + 1)
              end
          in
          if go (i + 1) then nop q
      | _ -> ()) code

(* the registers live after each instruction, a backward dataflow to
 * its fixpoint: a branch goes to its target (and on, if conditional), a
 * call reads R0 and leaves no register as it was, a return reads the
 * result's R0 and F0 *)
module RS = Set_

let all = RS.of_list (List.init 31 (fun i -> R i) @ List.init 32 (fun i -> F i))

let liveness (code : Emit.prog array) =
  let n = Array.length code in
  let at = Hashtbl.create 16 in
  Array.iteri (fun i (q : Emit.prog) -> Hashtbl.replace at q.ppc i) code;
  let succ i =
    let q = code.(i) in
    let next = if i + 1 < n then [ i + 1 ] else [] in
    let target = match q.to_ with Some (A.Target t) -> Option.to_list (Hashtbl.find_opt at t) | _ -> [] in
    if q.as_ = "B" then target
    else if q.as_ = "RET" || q.as_ = "RETURN" then []
    else if ends q && q.as_ <> "BL" then target @ next
    else next
  in
  let use i =
    let q = code.(i) in
    if q.as_ = "BL" then RS.of_list (R 0 :: reads q)
    else if q.as_ = "RET" || q.as_ = "RETURN" then RS.of_list [ R 0; F 0 ]
    else RS.of_list (reads q)
  in
  let def i = if code.(i).as_ = "BL" then all else RS.of_list (writes code.(i)) in
  let live_in = Array.make n RS.empty and live_out = Array.make n RS.empty in
  let changed = ref true in
  while !changed do
    changed := false;
    for i = n - 1 downto 0 do
      let out = List.fold_left (fun s j -> RS.union s live_in.(j)) RS.empty (succ i) in
      let inn = RS.union (use i) (RS.diff out (def i)) in
      live_out.(i) <- out;
      if not (RS.equal inn live_in.(i)) then (live_in.(i) <- inn; changed := true)
    done
  done;
  live_out

(* an instruction whose only effect is a register no one reads after:
 * a NOP; again, until none *)
let rec deadcode (code : Emit.prog array) =
  let live = liveness code in
  let dead = ref false in
  Array.iteri (fun i (q : Emit.prog) ->
    match writes q with
    | [ x ] when q.as_ <> "BL" && not (RS.mem x live.(i)) -> nop q; dead := true
    | _ -> ()) code;
  if !dead then deadcode code

(* subprop (5c's peep.c): MOV x,y where x dies, x computed in the same
 * block just before, with y neither read nor written since: that
 * instruction computes into y instead, and the move is dead *)
let subprop (code : Emit.prog array) targets live =
  Array.iteri (fun i (q : Emit.prog) ->
    if is_move q then
      match Option.bind q.from reg_of, Option.bind q.to_ reg_of with
      | Some x, Some y when x <> y && not (RS.mem x live.(i)) ->
          let rec back j =
            if j < 0 || Hashtbl.mem targets code.(j + 1).ppc then ()
            else
              let p = code.(j) in
              if ends p || List.mem y (reads p) || List.mem y (writes p) then ()
              else if writes p = [ x ] && not (accumulates p x) then begin
                p.to_ <- Some (match y with R r -> A.Reg r | F r -> A.FReg r);
                nop q
              end
              else if List.mem x (reads p) then ()
              else back (j - 1)
          in
          back (i - 1)
      | _ -> ()) code

(* the function's instructions, the last one first in Emit's list, up
 * to its TEXT *)
let run () =
  let rec take acc = function
    | (q : Emit.prog) :: rest when q.pseudo = Emit.Pnone -> take (q :: acc) rest
    | _ -> acc
  in
  let code = Array.of_list (take [] !Emit.progs) in
  let targets = Hashtbl.create 16 in
  Array.iter (fun (q : Emit.prog) -> match q.to_ with Some (A.Target t) -> Hashtbl.replace targets t () | _ -> ()) code;
  copyprop code targets;
  subprop code targets (liveness code);
  deadcode code
