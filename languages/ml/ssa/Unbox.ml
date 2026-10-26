(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unbox.mli *)

open Ssa

let on = ref true

let func (fn : func) : func =
  let handler = Array.exists (fun (b : block) -> match b.term with Try _ -> true | _ -> false) fn.blocks in
  if (not !on) || handler then fn
  else begin
    let def v = Hashtbl.find fn.defs v in
    let next = ref (Hashtbl.fold (fun v _ m -> max m (v + 1)) fn.defs 0) in
    let fresh ins = let v = !next in incr next; Hashtbl.replace fn.defs v ins; v in
    let double v = Hashtbl.mem fn.doubles v in
    let mark v = Hashtbl.replace fn.doubles v () in
    (* the doubles: the floats made, then the phis that one reaches *)
    Array.iter (fun (b : block) ->
      List.iter (fun v -> match def v with Prim ((Ir.Float2 _ | FloatOfInt | FloatIndex _), _) -> mark v | _ -> ()) b.body) fn.blocks;
    let changed = ref true in
    while !changed do
      changed := false;
      Array.iter (fun (b : block) ->
        List.iter (fun v ->
          match def v with
          | Phi ops when (not (double v)) && List.exists (fun (_, x) -> double x) ops -> mark v; changed := true
          | _ -> ()) b.phis) fn.blocks
    done;
    (* the instructions that become a Dprim: those that make a double,
     * and a comparison or a conversion with a double operand *)
    let converted v =
      match def v with
      | Prim ((Ir.Float2 _ | FloatOfInt | FloatIndex _), _) -> double v
      | Prim ((FloatCmp _ | IntOfFloat), xs) -> List.exists double xs
      | Prim (FloatSetIndex _, _) -> true
      | _ -> false
    in
    (* which of a Dprim's operands are floats: Float.Array's the stored
     * one alone, a conversion of an int none *)
    let floats (p : Ir.t) xs =
      match p with
      | FloatOfInt | FloatIndex _ -> List.map (fun _ -> false) xs
      | FloatSetIndex _ -> [ false; false; true ]
      | _ -> List.map (fun _ -> true) xs
    in
    (* the doubles read as words: boxed once, after their definition *)
    let boxes = Hashtbl.create 16 in
    let boxed x = if double x then (match Hashtbl.find_opt boxes x with Some b -> b | None -> let b = fresh (Box x) in Hashtbl.replace boxes x b; b) else x in
    let words xs = List.iter (fun x -> ignore (boxed x)) xs in
    Array.iter (fun (b : block) ->
      List.iter (fun v ->
        match def v with
        | Phi ops -> if not (double v) then words (List.map snd ops)
        | _ when converted v -> ()
        | ins -> words (Ssa_build.operands ins)) (b.phis @ b.body);
      match b.term with
      | Br (x, _, _) | Ret x | Raise x -> words [ x ]
      | Tail (_, xs) -> words xs
      | Jmp _ | Try _ -> ()) fn.blocks;
    (* each block rewritten: a double's box after it, a word unboxed
     * before the Dprim that reads it *)
    let ends = Array.make (Array.length fn.blocks) [] in
    Array.iter (fun (b : block) ->
      let body = ref [] in
      let push v = body := v :: !body in
      let box_after v = match Hashtbl.find_opt boxes v with Some bx -> push bx | None -> () in
      List.iter box_after b.phis;
      List.iter (fun v ->
        (match def v with
         | Prim (p, xs) when converted v ->
             let operand x = if double x then x else (let u = fresh (Unbox x) in mark u; push u; u) in
             let xs = List.map2 (fun x f -> if f then operand x else x) xs (floats p xs) in
             Hashtbl.replace fn.defs v (Dprim (p, xs))
         | ins -> Hashtbl.replace fn.defs v (Ssa_build.map_ins boxed ins));
        push v;
        box_after v) b.body;
      b.body <- List.rev !body;
      b.term <- Ssa_build.map_term boxed b.term;
      (* a double phi's word operands, unboxed at their predecessors'
       * ends *)
      List.iter (fun phi ->
        match def phi with
        | Phi ops when double phi ->
            let ops =
              List.map (fun (p, x) ->
                if double x then p, x
                else (let u = fresh (Unbox x) in mark u; ends.(p) <- ends.(p) @ [ u ]; p, u)) ops
            in
            Hashtbl.replace fn.defs phi (Phi ops)
        | _ -> ()) b.phis) fn.blocks;
    Array.iteri (fun i (b : block) -> b.body <- b.body @ ends.(i)) fn.blocks;
    fn
  end
