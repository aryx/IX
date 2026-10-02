(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Alloc.mli *)

open Ssa
module IS = Set_

type loc = Reg of int | Mem of int | Nil

let successors (b : block) = match b.term with Jmp s -> [ s ] | Br (_, a, c) | Try (_, a, c) -> [ a; c ] | _ -> []

let term_uses (b : block) = match b.term with Br (v, _, _) | Ret v | Raise v -> [ v ] | Tail (_, vs) -> vs | _ -> []

(* the instructions after which the collector may have run, or which a
 * handler's entry follows *)
let safepoint = function Alloc _ | Call _ | CallC _ | Op (Lower.Poly _, _) -> true | _ -> false

let alloc (fn : func) ~nregs ~base =
  let def v = Hashtbl.find fn.defs v in
  (* the values that need no storage: a Zero is the constant 0 *)
  let real v = match def v with Zero -> false | _ -> true in
  let uses v = List.filter real (operands (def v)) in
  let phi_ops (s : block) p = List.filter_map (fun phi -> match def phi with Phi ops -> List.assoc_opt p ops | _ -> None) s.phis in
  let n = Array.length fn.blocks in
  (* liveness at the blocks' edges: a phi's operand live at its
   * predecessor's end, its definition at its block's start *)
  let live_in = Array.make n IS.empty and live_out = Array.make n IS.empty in
  let changed = ref true in
  while !changed do
    changed := false;
    for b = n - 1 downto 0 do
      let bl = fn.blocks.(b) in
      let out =
        List.fold_left (fun s x ->
          let sb = fn.blocks.(x) in
          IS.union s (IS.union (IS.diff live_in.(x) (IS.of_list sb.phis)) (IS.of_list (List.filter real (phi_ops sb b))))) IS.empty (successors bl)
      in
      let live = ref (IS.union out (IS.of_list (List.filter real (term_uses bl)))) in
      List.iter (fun v -> live := IS.union (IS.remove v !live) (IS.of_list (uses v))) (List.rev bl.body);
      let inn = IS.union !live (IS.of_list bl.phis) in
      live_out.(b) <- out;
      if not (IS.equal inn live_in.(b)) then (live_in.(b) <- inn; changed := true)
    done
  done;
  (* what is live after each instruction; the values that must be in
   * memory: live across a safepoint (an allocation's fields too, read
   * after it), into a handler, or a parameter *)
  let after = Hashtbl.create 256 in
  let memory = Hashtbl.create 64 in
  Array.iter (fun (bl : block) ->
    let live = ref (IS.union live_out.(bl.id) (IS.of_list (List.filter real (term_uses bl)))) in
    List.iter (fun v ->
      Hashtbl.replace after v !live;
      (match def v with
       | Alloc (_, xs) -> IS.iter (fun x -> Hashtbl.replace memory x ()) (IS.remove v !live); List.iter (fun x -> Hashtbl.replace memory x ()) xs
       | ins when safepoint ins -> IS.iter (fun x -> Hashtbl.replace memory x ()) (IS.remove v !live)
       | _ -> ());
      live := IS.union (IS.remove v !live) (IS.of_list (uses v))) (List.rev bl.body);
    (match bl.term with Try (_, _, h) -> IS.iter (fun x -> Hashtbl.replace memory x ()) live_in.(h) | _ -> ())) fn.blocks;
  Hashtbl.iter (fun v ins -> match ins with Param _ | Caught _ -> Hashtbl.replace memory v () | _ -> ()) fn.defs;
  (* the others colored in the dominator tree's order, the lowest free
   * register not held by a value live there: optimal for SSA, whose
   * interference graph is chordal (Hack, 2006); none free, memory *)
  let idom = Ssa.dominators fn in
  let children = Array.make n [] in
  Array.iteri (fun b d -> if b <> 0 && d >= 0 then children.(d) <- b :: children.(d)) idom;
  let color = Hashtbl.create 64 in
  let candidate v = real v && (not (Hashtbl.mem memory v)) && nregs > 0 in
  let held s = IS.fold (fun x acc -> match Hashtbl.find_opt color x with Some c -> IS.add c acc | None -> acc) s IS.empty in
  let pick busy = List.find_opt (fun c -> not (IS.mem c busy)) (List.init nregs Fun.id) in
  (* busy at a definition: the registers of the values live after it
   * (defined above it in the dominator tree, so colored already); an
   * operand dying there frees its own, which the definition may take *)
  let rec walk b =
    let bl = fn.blocks.(b) in
    let busy = ref (held (IS.diff live_in.(b) (IS.of_list bl.phis))) in
    List.iter (fun v -> if candidate v then match pick !busy with Some c -> Hashtbl.replace color v c; busy := IS.add c !busy | None -> ()) bl.phis;
    List.iter (fun v ->
      let live = Hashtbl.find after v in
      if candidate v && IS.mem v live then
        match pick (held (IS.remove v live)) with Some c -> Hashtbl.replace color v c | None -> ()) bl.body;
    List.iter walk (List.rev children.(b))
  in
  if n > 0 then walk 0;
  (* memory: the parameters their prologue slots, the others one each *)
  let slots = Hashtbl.create 64 and next = ref base in
  (* a body's value no one reads after needs no place *)
  let dead v = match Hashtbl.find_opt after v with Some live -> not (IS.mem v live) && not (Hashtbl.mem memory v) | None -> false in
  let loc v =
    match def v with
    | Zero -> Nil
    | _ when dead v -> Nil
    | Param i -> Mem i
    | _ -> (
        match Hashtbl.find_opt color v with
        | Some c -> Reg c
        | None -> (match Hashtbl.find_opt slots v with Some s -> Mem s | None -> let s = !next in incr next; Hashtbl.replace slots v s; Mem s))
  in
  (* every value's place now, so that the frame's size is known; in the
   * values' order, not the table's: a slot's number would depend on the
   * stdlib's hash function (OCaml's, or mini-ml's own when it compiles
   * itself) *)
  List.iter (fun v -> ignore (loc v)) (List.sort compare (Hashtbl.fold (fun v _ vs -> v :: vs) fn.defs []));
  loc, !next
