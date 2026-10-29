(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Alloc.mli *)

open Ssa
module IS = Set_

type loc = Reg of int | Mem of int | Nil | Dmem of int

let successors = Ssa_build.successors_of

let term_uses (b : block) = match b.term with Br (v, _, _) | Switch (v, _) | Ret v | Raise v -> [ v ] | Tail (_, vs) -> vs | _ -> []

(* the instructions after which the collector may have run, or which a
 * handler's entry follows *)
let safepoint = function
  | Alloc _ | Call _ | CallC _ | Op (Ir.Poly _, _) -> true
  (* a new float: the runtime's when there is no room *)
  | Prim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatIndex _ | FloatRound _
          | FloatCall _), _) | Box _ -> true
  (* an int32's block; to_int's, none *)
  | Prim ((Ir.Int32 _ | Int32OfInt), _) -> true
  | Prim (Ir.BytesGet 4, _) -> true
  (* C's exp on doubles: no allocation, but C's code uses the values'
   * registers *)
  | Dprim (Ir.FloatCall _, _) -> true
  | _ -> false

(* the instructions after which no double is in a register: a call of
 * ML's code, or of C's that computes with floats (the runtime's float
 * functions, compare's cmp: runtime.c's functions that use the
 * floating-point registers, by mini-cc -S; ml_alloc, the collector,
 * ml_modify and the C library's assembly use none, so an allocation
 * keeps them) *)
let clobbers = function
  | Call _ | CallC _ | Op (Ir.Poly _, _)
  | Prim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatIndex _ | FloatSetIndex _ | FloatRound _
          | FloatCall _), _)
  | Dprim (Ir.FloatCall _, _) -> true
  | _ -> false

let def (fn : func) v = Hashtbl.find fn.defs v

(* (off: mini-ml -own-slots) *)
let share_slots = ref true

(* the values that need no storage: a Zero is the constant 0, and a
 * constant is made where it is read (Emit's src)
 * old: match def fn v with Zero -> false | _ -> true *)
let real (fn : func) v = match def fn v with Zero | Const _ | Blk _ | Symb _ -> false | _ -> true

let uses (fn : func) v = List.filter (real fn) (Ssa_build.operands (def fn v))

(* liveness at the blocks' edges: a phi's operand live at its
 * predecessor's end, its definition at its block's start *)
let liveness (fn : func) : int IS.t array * int IS.t array =
  let real = real fn in
  let phi_ops (s : block) p = List.filter_map (fun phi -> match def fn phi with Phi ops -> List.assoc_opt p ops | _ -> None) s.phis in
  Liveness.ssa ~succs:(fun b -> successors fn.blocks.(b)) ~phis:(fun b -> fn.blocks.(b).phis)
    ~phi_uses:(fun s p -> List.filter real (phi_ops fn.blocks.(s) p))
    ~term_uses:(fun b -> List.filter real (term_uses fn.blocks.(b))) ~body:(fun b -> fn.blocks.(b).body)
    ~uses:(uses fn) (Array.length fn.blocks)

let alloc (fn : func) ~nregs ~nfregs ~base =
  let def = def fn and real = real fn and uses = uses fn in
  let double v = Hashtbl.mem fn.doubles v and word v = not (Hashtbl.mem fn.doubles v) in
  let n = Array.length fn.blocks in
  let live_in, live_out = liveness fn in
  (* what is live after each instruction; the values that must be in
   * memory: live across a safepoint (an allocation's fields too, read
   * after it), into a handler, or a parameter *)
  let after =
    Liveness.after ~term_uses:(fun b -> List.filter real (term_uses fn.blocks.(b)))
      ~body:(fun b -> fn.blocks.(b).body) ~uses live_out n in
  let memory = Hashtbl.create 64 and dmemory = Hashtbl.create 16 in
  let words_in t s = IS.iter (fun x -> if word x then Hashtbl.replace t x ()) s
  and doubles_in t s = IS.iter (fun x -> if double x then Hashtbl.replace t x ()) s in
  Array.iter (fun (bl : block) ->
    List.iter (fun v ->
      let live = Hashtbl.find after v in
      (match def v with
       | Alloc (_, xs) -> words_in memory (IS.remove v live); List.iter (fun x -> Hashtbl.replace memory x ()) xs
       | ins when safepoint ins -> words_in memory (IS.remove v live)
       | _ -> ());
      if clobbers (def v) then doubles_in dmemory (IS.remove v live)) bl.body;
    (match bl.term with Try (_, _, h) -> IS.iter (fun x -> Hashtbl.replace memory x ()) live_in.(h) | _ -> ())) fn.blocks;
  (* OPTIMIZATION: a parameter not live across a safepoint may have a
   * register too, loaded from its slot at the entry (Emit), and not at
   * each use: an accessor's, a loop's bound...
   * old: Param _ | Caught _ -> memory *)
  Hashtbl.iter (fun v ins ->
    match ins with Caught _ -> Hashtbl.replace memory v () | _ -> ()) fn.defs;
  (* the others colored in the dominator tree's order, the lowest free
   * register not held by a value live there: optimal for SSA, whose
   * interference graph is chordal (Hack, 2006); none free, memory *)
  let idom = Ssa_build.dominators fn in
  let children = Dominators.children idom in
  (* OPTIMIZATION (the values chosen): which values get a register, the
   * most used first, a use in a loop counting 8 times one outside it;
   * each taken while no point has more of them live than there are
   * registers, so that the coloring below never fails (an SSA program's
   * interference: its colors are its most values live at once). Before,
   * the first in the dominator tree's order took them, an outer loop's
   * values those of the inner one, which lived in slots (arm's five:
   * tests/bench/pixels.ml).
   * old: let candidate v = real v && (not (Hashtbl.mem memory v)) && nregs > 0 in *)
  (* a loop: an edge back to a block that dominates its source; its
   * blocks those that reach the source without passing the head
   * (lib_code's Dominators.loop_depths) *)
  let depth =
    Dominators.loop_depths ~succs:(fun b -> successors fn.blocks.(b)) ~preds:(fun b -> fn.blocks.(b).preds) idom in
  let weight = Hashtbl.create 256 in
  let use v b = if real v then Hashtbl.replace weight v ((match Hashtbl.find_opt weight v with Some x -> x | None -> 0) + (1 lsl (3 * min depth.(b) 6))) in
  Array.iter (fun (bl : block) ->
    List.iter (fun v -> use v bl.id) bl.phis;
    List.iter (fun v -> use v bl.id; List.iter (fun x -> use x bl.id) (uses v)) bl.body;
    List.iter (fun x -> use x bl.id) (term_uses bl);
    List.iter (fun s ->
      List.iter (fun phi -> match def phi with Phi ops -> (match List.assoc_opt bl.id ops with Some x -> use x bl.id | None -> ()) | _ -> ()) fn.blocks.(s).phis)
      (successors bl)) fn.blocks;
  (* the points: each block's start, each instruction's end *)
  let npoints, at = Coloring.points live_in after in
  (* each class of values, the words and the doubles, its own registers
   * (a double's are the floating-point ones); busy at a definition:
   * the registers of the values live after it (defined above it in the
   * dominator tree, so colored already); an operand dying there frees
   * its own, which the definition may take (lib_code's Coloring) *)
  let colors cls nregs memory =
    let wanted = Hashtbl.fold (fun v w acc -> if cls v && not (Hashtbl.mem memory v) then (w, v) :: acc else acc) weight [] in
    let chosen = Coloring.choose ~npoints ~at ~nregs wanted in
    let candidate v = real v && Hashtbl.mem chosen v && nregs > 0 in
    let body_ok v = candidate v && IS.mem v (Hashtbl.find after v) in
    Coloring.walk ~children ~live_in ~phis:(fun b -> fn.blocks.(b).phis) ~body:(fun b -> fn.blocks.(b).body)
      ~candidate:(fun v -> if Hashtbl.mem after v then body_ok v else candidate v)
      ~busy:(fun v -> IS.remove v (Hashtbl.find after v)) ~hints:(fun _ -> []) nregs
  in
  let color = colors word nregs memory and dcolor = colors double nfregs dmemory in
  (* a body's value no one reads after needs no place; nor one in no
   * block, a phi Ssa_build's simplify took out, a value Unbox replaced
   * (each was a slot of the frame, zeroed at each call: Float.min's 13
   * of 15).
   * old: | None -> false *)
  let placed = Hashtbl.create 256 in
  Array.iter (fun (bl : block) -> List.iter (fun v -> Hashtbl.replace placed v ()) (bl.phis @ bl.body)) fn.blocks;
  let dead v =
    match Hashtbl.find_opt after v with
    | Some live -> not (IS.mem v live) && not (Hashtbl.mem memory v)
    | None -> not (Hashtbl.mem placed v) && (match def v with Param _ | Caught _ -> false | _ -> true)
  in
  (* OPTIMIZATION (shared slots): a word in memory takes the lowest slot
   * that no value live with it holds, nor its own operands, in the
   * registers' walk: two whose lives do not meet share one. A slot then
   * keeps a dead value until the next is written, a root the collector
   * updates as the others, which at worst keeps a block one collection
   * more. Every slot is zeroed at the entry, the collector scanning it:
   * Float.min, with three copies of sign_bit inlined (each value live
   * across a call its slot), zeroed 13 at each call where it returns
   * at its first test.
   * old: a slot each, the next one *)
  let shared = Hashtbl.create 64 in
  let in_slot v =
    word v && real v && (match def v with Param _ -> false | _ -> true) && not (Hashtbl.mem color v) && not (dead v)
    && not (Hashtbl.mem fn.raws v)
  in
  let walk () =
    Coloring.walk ~children ~live_in ~phis:(fun b -> fn.blocks.(b).phis) ~body:(fun b -> fn.blocks.(b).body)
      ~candidate:in_slot ~busy:(fun v -> IS.union (IS.remove v (Hashtbl.find after v)) (IS.of_list (uses v)))
      ~hints:(fun _ -> []) max_int
  in
  if n > 0 && !share_slots then Hashtbl.iter (fun v c -> Hashtbl.replace shared v c) (walk ());
  (* memory: the parameters their prologue slots, the others theirs
   * (shared), from base, then one each for a value the walk did not
   * reach; a double one of its own (Dmem), from 0 *)
  let nshared = Hashtbl.fold (fun _ c m -> max m (c + 1)) shared 0 in
  let slots = Hashtbl.create 64 and next = ref (base + nshared) and dnext = ref 0 in
  let loc v =
    match def v with
    | Zero | Const _ | Blk _ | Symb _ -> Nil
    | _ when dead v -> Nil
    | _ when double v -> (
        match Hashtbl.find_opt dcolor v with
        | Some c -> Reg c
        | None -> (match Hashtbl.find_opt slots v with Some s -> Dmem s | None -> let s = !dnext in incr dnext; Hashtbl.replace slots v s; Dmem s))
    | Param i ->
        (match Hashtbl.find_opt color v with Some c -> Reg c | None -> Mem i)
    (* an untagged integer (Untag) without a register: a slot the
     * collector does not scan, a double's *)
    | _ when Hashtbl.mem fn.raws v -> (
        match Hashtbl.find_opt color v with
        | Some c -> Reg c
        | None -> (match Hashtbl.find_opt slots v with Some s -> Dmem s | None -> let s = !dnext in incr dnext; Hashtbl.replace slots v s; Dmem s))
    | _ -> (
        match Hashtbl.find_opt color v with
        | Some c -> Reg c
        | None -> (
            match Hashtbl.find_opt shared v with
            | Some c -> Mem (base + c)
            | None -> (match Hashtbl.find_opt slots v with Some s -> Mem s | None -> let s = !next in incr next; Hashtbl.replace slots v s; Mem s)))
  in
  (* every value's place now, so that the frame's size is known; in the
   * values' order, not the table's: a slot's number would depend on the
   * stdlib's hash function (OCaml's, or mini-ml's own when it compiles
   * itself) *)
  List.iter (fun v -> ignore (loc v)) (List.sort compare (Hashtbl.fold (fun v _ vs -> v :: vs) fn.defs []));
  loc, !next, !dnext
