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
      List.iter (fun v ->
        match def v with
        | Prim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatIndex _ | FloatRound _
                | FloatCall _), _) -> mark v
        | _ -> ()) b.body) fn.blocks;
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
      | Prim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatIndex _ | FloatRound _
              | FloatCall _), _) -> double v
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
    (* OPTIMIZATION (unbox once): a word read as a double, unboxed once,
     * after its definition, for all its reads: a loop's constant (a
     * float literal, a parameter, a field read before it) loaded once,
     * not at each turn (mini-virtuaracing's draw, its eye's vectors). A
     * literal (a static block, made where it is read: Lower) unboxed at
     * the function's entry, once for all its reads.
     * old: an Unbox before each Dprim that reads it *)
    let unboxes = Hashtbl.create 16 and literals = Hashtbl.create 16 and entry = ref [] in
    let unboxed x =
      if double x then x
      else
        match def x with
        | Blk sym -> (
            match Hashtbl.find_opt literals sym with
            | Some u -> u
            | None ->
                let u = fresh (Unbox (fresh (Blk sym))) in
                mark u; Hashtbl.replace literals sym u; entry := u :: !entry; u)
        | _ -> (
            match Hashtbl.find_opt unboxes x with
            | Some u -> u
            | None -> let u = fresh (Unbox x) in mark u; Hashtbl.replace unboxes x u; u)
    in
    (* where each double is read as a word: a block, and whether in its
     * body (else by its end); a phi a double reaches is one, so none *)
    let reads = Hashtbl.create 16 in
    let read_at (b : block) in_body xs =
      words xs;
      List.iter (fun x ->
        if double x then
          let l = match Hashtbl.find_opt reads x with Some l -> l | None -> [] in
          Hashtbl.replace reads x ((b.id, in_body) :: l)) xs
    in
    Array.iter (fun (b : block) ->
      List.iter (fun v ->
        match def v with
        | Phi ops -> if not (double v) then words (List.map snd ops)
        | Prim (p, xs) when converted v ->
            List.iter2 (fun x f -> if f then ignore (unboxed x)) xs (floats p xs)
        | ins -> read_at b true (Ssa_build.operands ins)) (b.phis @ b.body);
      match b.term with
      | Br (x, _, _) | Switch (x, _) | Ret x | Raise x -> read_at b false [ x ]
      | Tail (_, xs) -> read_at b false xs
      | Jmp _ | Try _ -> ()) fn.blocks;
    (* OPTIMIZATION (box where read): a double read as a word in one
     * block only, which cannot run again but through the double's own,
     * boxed there: a loop's float that leaves it by its return is boxed
     * once, not at each turn (lib_audio's Filter.chain, 4 of its 5
     * boxes a call).
     * old: always after the definition (box_after) *)
    let home = Hashtbl.create 64 in
    Array.iter (fun (b : block) ->
      List.iter (fun v -> Hashtbl.replace home v b.id) (b.phis @ b.body)) fn.blocks;
    let succs (b : block) =
      match b.term with
      | Jmp s -> [ s ]
      | Br (_, s, t) | Try (_, s, t) -> [ s; t ]
      | Switch _ -> Ssa_build.successors_of b
      | _ -> []
    in
    (* b reached from itself without going through d *)
    let again b d =
      let seen = Hashtbl.create 16 in
      let rec go s =
        s = b
        || (s <> d && not (Hashtbl.mem seen s)
            && (Hashtbl.replace seen s (); List.exists go (succs fn.blocks.(s))))
      in
      List.exists go (succs fn.blocks.(b))
    in
    let sunk = Hashtbl.create 16 in
    let starts = Array.make (Array.length fn.blocks) [] in
    let ends = Array.make (Array.length fn.blocks) [] in
    (* the values in their order, not the table's (the hash function of
     * the stdlib that built mini-ml: a block's boxes in another order,
     * the fixed point's programs not the same, bugs/ix.md) *)
    List.iter (fun ((x, sites) : int * (int * bool) list) ->
      let blocks = List.sort_uniq compare (List.map fst sites) in
      match blocks, Hashtbl.find_opt home x, Hashtbl.find_opt boxes x with
      | [ b ], Some d, Some bx when b <> d && b <> 0 && not (again b d) ->
          Hashtbl.replace sunk x ();
          if List.exists snd sites then starts.(b) <- bx :: starts.(b)
          else ends.(b) <- bx :: ends.(b)
      | _ -> ())
      (List.sort compare (Hashtbl.fold (fun x sites acc -> (x, sites) :: acc) reads []));
    (* each block rewritten: a double's box after it, a word unboxed
     * before the Dprim that reads it *)
    Array.iter (fun (b : block) ->
      let body = ref [] in
      let push v = body := v :: !body in
      let box_after v =
        (match Hashtbl.find_opt boxes v with
         | Some bx when not (Hashtbl.mem sunk v) -> push bx
         | _ -> ());
        match Hashtbl.find_opt unboxes v with Some u -> push u | None -> ()
      in
      List.iter box_after b.phis;
      List.iter push starts.(b.id);
      (* (nothing between the parameters: Emit loads them all at the
       * entry, and Alloc may give a later one a register an earlier one
       * leaves; what follows them goes after the last) *)
      let later = ref [] in
      List.iter (fun v ->
        (match def v with
         | Param _ -> ()
         | _ -> List.iter box_after (List.rev !later); later := []);
        (match def v with
         | Prim (p, xs) when converted v ->
             let xs = List.map2 (fun x f -> if f then unboxed x else x) xs (floats p xs) in
             Hashtbl.replace fn.defs v (Dprim (p, xs))
         | ins -> Hashtbl.replace fn.defs v (Ssa_build.map_ins boxed ins));
        push v;
        match def v with Param _ -> later := v :: !later | _ -> box_after v) b.body;
      List.iter box_after (List.rev !later);
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
    (* the literals' blocks and unboxes first in the entry *)
    let lits = List.concat_map (fun u -> match def u with Unbox b -> [ b; u ] | _ -> [ u ]) (List.rev !entry) in
    if Array.length fn.blocks > 0 then fn.blocks.(0).body <- lits @ fn.blocks.(0).body;
    fn
  end
