(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Alloc.mli *)

(* Ir for its types' I and F, Ssa for the instructions *)
open Ir
open Ssa
module IS = Set_

type loc = Reg of int | Slot of int | Home of mem | Nil

let def (fn : func) v = Hashtbl.find fn.defs v
let is_float (fn : func) v =
  match Hashtbl.find fn.types v with F _ -> true | I _ -> false

(* a value made where it is read: a constant, an address *)
let remade = function
  | Const _ | Fconst _ | Addr _ | Undef _ -> true | _ -> false

(* a value no one reads: an instruction run for its effect *)
let for_effect = function
  | Store _ | StoreAt _ | Copy _ | Arg _ | ArgBlock _ -> true
  | Call (_, _, _, rt) -> rt = None
  | _ -> false

let real (fn : func) v = not (remade (def fn v))
let uses (fn : func) v =
  List.filter (real fn) (Ssa_build.operands (def fn v))

(* liveness at the blocks' edges: a phi's operand live at its
 * predecessor's end, its definition at its block's start *)
let liveness (fn : func) =
  let real = real fn in
  let phi_ops (s : block) p =
    List.filter_map (fun phi ->
      match def fn phi with Phi ops -> List.assoc_opt p ops | _ -> None)
      s.phis in
  Liveness.ssa ~succs:(fun b -> Ssa_build.successors_of fn.blocks.(b))
    ~phis:(fun b -> fn.blocks.(b).phis)
    ~phi_uses:(fun s p -> List.filter real (phi_ops fn.blocks.(s) p))
    ~term_uses:(fun b ->
      List.filter real (Ssa_build.term_uses fn.blocks.(b).term))
    ~body:(fun b -> fn.blocks.(b).body) ~uses:(uses fn)
    (Array.length fn.blocks)

let alloc (fn : func) ~nregs ~nfregs =
  let def = def fn and real = real fn and uses = uses fn in
  let n = Array.length fn.blocks in
  let live_in, live_out = liveness fn in
  (* what is live after each instruction, and across each call *)
  let after =
    Liveness.after
      ~term_uses:(fun b ->
        List.filter real (Ssa_build.term_uses fn.blocks.(b).term))
      ~body:(fun b -> fn.blocks.(b).body) ~uses live_out n in
  let across = Hashtbl.create 16 in
  Array.iter (fun (bl : block) ->
    List.iter (fun v ->
      match def v with
      | Call _ ->
          Hashtbl.replace across v
            (bl.id, IS.remove v (Hashtbl.find after v))
      | _ -> ()) bl.body) fn.blocks;
  let idom = Ssa_build.dominators fn in
  let children = Dominators.children idom in
  (* which values get a register: the most used first, a use in a loop
   * 8 times one outside it, each while no point has more of them live
   * than there are registers (mini-ml's Alloc); the loops lib_code's
   * Dominators.loop_depths *)
  let depth =
    Dominators.loop_depths
      ~succs:(fun b -> Ssa_build.successors_of fn.blocks.(b))
      ~preds:(fun b -> fn.blocks.(b).preds) idom in
  let weight = Hashtbl.create 256 in
  let use v b =
    if real v then
      Hashtbl.replace weight v
        ((match Hashtbl.find_opt weight v with Some x -> x | None -> 0)
         + (1 lsl (3 * min depth.(b) 6))) in
  Array.iter (fun (bl : block) ->
    List.iter (fun v -> use v bl.id) bl.phis;
    List.iter (fun v ->
      use v bl.id; List.iter (fun x -> use x bl.id) (uses v)) bl.body;
    List.iter (fun x -> use x bl.id) (Ssa_build.term_uses bl.term);
    List.iter (fun s ->
      List.iter (fun phi ->
        match def phi with
        | Phi ops ->
            (match List.assoc_opt bl.id ops with
             | Some x -> use x bl.id
             | None -> ())
        | _ -> ()) fn.blocks.(s).phis)
      (Ssa_build.successors_of bl)) fn.blocks;
  (* OPTIMIZATION (saved around calls): a value live across a call is
   * in memory if the call costs more than its uses gain: a store before
   * and a load after (a parameter's load only, from its own slot), in
   * the call's loop, against a use's in its own; else it keeps its
   * register, saved at each call (Ssa_gen). Before, every such value
   * lived in memory, gc.c's C scan's loop (a call of copy on a path)
   * all of it.
   * old: memory, each value live across a call *)
  let cost = Hashtbl.create 64 and memory = Hashtbl.create 64 in
  Hashtbl.iter (fun _ (b, live) ->
    IS.iter (fun x ->
      let k =
        (match def x with Param _ -> 1 | _ -> 2)
        * (1 lsl (3 * min depth.(b) 6)) in
      Hashtbl.replace cost x
        (k + match Hashtbl.find_opt cost x with Some c -> c | None -> 0))
      live) across;
  Hashtbl.iter (fun x c ->
    if c >= (match Hashtbl.find_opt weight x with Some w -> w | None -> 0)
    then Hashtbl.replace memory x ()) cost;
  (* the points: each block's start, each instruction's end *)
  let npoints, at = Coloring.points live_in after in
  let dead v =
    match Hashtbl.find_opt after v with
    | Some live -> not (IS.mem v live)
    | None -> true in
  (* the walk in the dominator tree's order, each value the lowest
   * color (a register, or a slot) that no value live after it holds;
   * an operand dying there frees its own *)
  (* OPTIMIZATION (a phi's register): a phi and its operands each try
   * the others' color first, so that the edge's move is none: the
   * loop's q + 4 in q's register, when q dies there (Ssa_build's sink).
   * old: the lowest color free *)
  let related = Hashtbl.create 64 in
  let relate a b = Hashtbl.add related a b; Hashtbl.add related b a in
  Array.iter (fun (bl : block) ->
    List.iter (fun phi ->
      match def phi with
      | Phi ops -> List.iter (fun (_, x) -> if real x then relate phi x) ops
      | _ -> ()) bl.phis) fn.blocks;
  (* lib_code's Coloring: a body's value colored if live after it *)
  let walk candidate ncolors =
    let body_ok v = candidate v && IS.mem v (Hashtbl.find after v) in
    Coloring.walk ~children ~live_in ~phis:(fun b -> fn.blocks.(b).phis)
      ~body:(fun b -> fn.blocks.(b).body)
      ~candidate:(fun v ->
        if Hashtbl.mem after v then body_ok v else candidate v)
      ~busy:(fun v -> IS.remove v (Hashtbl.find after v))
      ~hints:(Hashtbl.find_all related) ncolors
  in
  let colors cls nregs =
    let wanted =
      Hashtbl.fold (fun v w acc ->
        if cls v && not (Hashtbl.mem memory v) then (w, v) :: acc else acc)
        weight [] in
    let chosen = Coloring.choose ~npoints ~at ~nregs wanted in
    walk (fun v -> real v && Hashtbl.mem chosen v) nregs
  in
  let color = colors (fun v -> not (is_float fn v)) nregs
  and fcolor = colors (is_float fn) nfregs in
  let in_reg v = Hashtbl.mem (if is_float fn v then fcolor else color) v in
  (* the others in slots of the frame, shared by values whose lives do
   * not meet; a parameter keeps its own *)
  let slots =
    walk (fun v ->
      real v && (not (in_reg v) || Hashtbl.mem cost v)
      && (match def v with Param _ -> false | _ -> true)) max_int in
  let loc v =
    match def v with
    | ins when remade ins -> Nil
    | ins when for_effect ins -> Nil
    | _ when (match Hashtbl.find_opt (if is_float fn v then fcolor else color) v
              with Some _ -> true | None -> false) ->
        Reg (Hashtbl.find (if is_float fn v then fcolor else color) v)
    | Param (m, _) -> if dead v then Nil else Home m
    | _ -> (match Hashtbl.find_opt slots v with Some s -> Slot s | None -> Nil)
  in
  let nslots = Hashtbl.fold (fun _ s m -> max m (s + 1)) slots 0 in
  (* at a call, the values to save in a register: where to *)
  let saves v =
    match Hashtbl.find_opt across v with
    | None -> []
    | Some (_, live) ->
        List.filter_map (fun x ->
          if not (in_reg x) then None
          else
            match def x with
            | Param (m, _) -> Some (x, Home m)
            | _ -> Some (x, Slot (Hashtbl.find slots x))) (IS.elements live)
  in
  loc, saves, nslots
