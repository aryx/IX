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
  let real = real fn and uses = uses fn in
  let phi_ops (s : block) p =
    List.filter_map (fun phi ->
      match def fn phi with Phi ops -> List.assoc_opt p ops | _ -> None)
      s.phis in
  let n = Array.length fn.blocks in
  let live_in = Array.make n IS.empty and live_out = Array.make n IS.empty in
  let changed = ref true in
  while !changed do
    changed := false;
    for b = n - 1 downto 0 do
      let bl = fn.blocks.(b) in
      let out =
        List.fold_left (fun s x ->
          let sb = fn.blocks.(x) in
          IS.union s
            (IS.union (IS.diff live_in.(x) (IS.of_list sb.phis))
               (IS.of_list (List.filter real (phi_ops sb b)))))
          IS.empty (Ssa_build.successors_of bl)
      in
      let live =
        ref (IS.union out
          (IS.of_list (List.filter real (Ssa_build.term_uses bl.term)))) in
      List.iter (fun v ->
        live := IS.union (IS.remove v !live) (IS.of_list (uses v)))
        (List.rev bl.body);
      let inn = IS.union !live (IS.of_list bl.phis) in
      live_out.(b) <- out;
      if not (IS.equal inn live_in.(b)) then
        (live_in.(b) <- inn; changed := true)
    done
  done;
  live_in, live_out

let alloc (fn : func) ~nregs ~nfregs =
  let def = def fn and real = real fn and uses = uses fn in
  let n = Array.length fn.blocks in
  let live_in, live_out = liveness fn in
  (* what is live after each instruction, and across each call *)
  let after = Hashtbl.create 256 and across = Hashtbl.create 16 in
  Array.iter (fun (bl : block) ->
    let live =
      ref (IS.union live_out.(bl.id)
        (IS.of_list (List.filter real (Ssa_build.term_uses bl.term)))) in
    List.iter (fun v ->
      Hashtbl.replace after v !live;
      (match def v with
       | Call _ -> Hashtbl.replace across v (bl.id, IS.remove v !live)
       | _ -> ());
      live := IS.union (IS.remove v !live) (IS.of_list (uses v)))
      (List.rev bl.body)) fn.blocks;
  let idom = Ssa_build.dominators fn in
  let children = Array.make n [] in
  Array.iteri (fun b d ->
    if b <> 0 && d >= 0 then children.(d) <- b :: children.(d)) idom;
  (* which values get a register: the most used first, a use in a loop
   * 8 times one outside it, each while no point has more of them live
   * than there are registers (mini-ml's Alloc) *)
  let rec dominates a b =
    a = b || (b <> 0 && idom.(b) >= 0 && dominates a idom.(b)) in
  let depth = Array.make n 0 in
  Array.iter (fun (bl : block) ->
    List.iter (fun h ->
      if idom.(bl.id) >= 0 && dominates h bl.id then begin
        let body = Hashtbl.create 16 in
        Hashtbl.replace body h ();
        let rec back b =
          if not (Hashtbl.mem body b) then
            (Hashtbl.replace body b (); List.iter back fn.blocks.(b).preds) in
        back bl.id;
        Hashtbl.iter (fun b () -> depth.(b) <- depth.(b) + 1) body
      end) (Ssa_build.successors_of bl)) fn.blocks;
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
  let points =
    Array.of_list (Array.to_list live_in
      @ List.map snd (List.sort compare
          (Hashtbl.fold (fun v live acc -> (v, live) :: acc) after []))) in
  let at = Hashtbl.create 256 in
  Array.iteri (fun k live ->
    IS.iter (fun v ->
      Hashtbl.replace at v
        (k :: (match Hashtbl.find_opt at v with Some l -> l | None -> [])))
      live) points;
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
  let walk candidate ncolors =
    let color = Hashtbl.create 64 in
    let held s =
      IS.fold (fun x acc ->
        match Hashtbl.find_opt color x with
        | Some c -> IS.add c acc
        | None -> acc) s IS.empty in
    let pick v busy =
      let hinted =
        List.filter_map (Hashtbl.find_opt color) (Hashtbl.find_all related v)
      in
      match List.find_opt (fun c -> not (IS.mem c busy)) hinted with
      | Some c -> Some c
      | None ->
          let rec go c =
            if c >= ncolors then None
            else if IS.mem c busy then go (c + 1)
            else Some c in
          go 0
    in
    let rec visit b =
      let bl = fn.blocks.(b) in
      let busy = ref (held (IS.diff live_in.(b) (IS.of_list bl.phis))) in
      List.iter (fun v ->
        if candidate v then
          match pick v !busy with
          | Some c -> Hashtbl.replace color v c; busy := IS.add c !busy
          | None -> ()) bl.phis;
      List.iter (fun v ->
        let live = Hashtbl.find after v in
        if candidate v && IS.mem v live then
          match pick v (held (IS.remove v live)) with
          | Some c -> Hashtbl.replace color v c
          | None -> ()) bl.body;
      List.iter visit (List.rev children.(b))
    in
    if n > 0 then visit 0;
    color
  in
  let colors cls nregs =
    let count = Array.make (Array.length points) 0
    and chosen = Hashtbl.create 64 in
    let wanted =
      Hashtbl.fold (fun v w acc ->
        if cls v && not (Hashtbl.mem memory v) then (w, v) :: acc else acc)
        weight [] in
    List.iter (fun (_, v) ->
      let ks = match Hashtbl.find_opt at v with Some l -> l | None -> [] in
      if List.for_all (fun k -> count.(k) < nregs) ks then begin
        Hashtbl.replace chosen v ();
        List.iter (fun k -> count.(k) <- count.(k) + 1) ks
      end)
      (List.sort (fun ((w1, v1) : int * int) ((w2, v2) : int * int) ->
         if w1 <> w2 then compare w2 w1 else compare v1 v2) wanted);
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
