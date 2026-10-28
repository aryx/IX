(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cse.mli *)

open Ssa

let on = ref true

(* an instruction whose value its operands alone give: not a read of
 * memory that a store changes (Field, Index, a string's byte, a
 * Float.Array's double: FloatIndex, a Dprim too), not an allocation,
 * not a call (compare's, C's exp: FloatCall). A constant too, so that
 * i * 4 and i * 4 are one: each 4 is a value of its own, and one costs
 * nothing more (Emit makes it where it is read).
 * old: Dprim _ every one: Licm moved rebirth's Float.Array stores out
 * of their loops *)
let pure ~set (ins : ins) =
  match ins with
  | Op (Ir.Poly _, _) -> false
  | Dprim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatCmp _ | IntOfFloat
           | FloatRound _), _) -> true
  | Const _ | Op _ | Tag _ | Unbox _ -> true
  | GetG g -> not (set g)
  | _ -> false

let handler (fn : func) =
  Array.exists (fun (b : block) ->
    match b.term with Try _ -> true | _ -> false) fn.blocks

(* (a global the function sets, its Init: read again after) *)
let sets (fn : func) =
  let gs = Hashtbl.create 8 in
  Hashtbl.iter (fun _ ins ->
    match ins with SetG (g, _) -> Hashtbl.replace gs g () | _ -> ()) fn.defs;
  Hashtbl.mem gs

(* (not a function with a handler, as Untag: its values in memory at
 * each raise, the handler entered from wherever its body raised) *)
let func (fn : func) : func =
  if (not !on) || handler fn then fn
  else begin
    let n = Array.length fn.blocks in
    let idom = Ssa_build.dominators fn in
    let children = Array.make n [] in
    Array.iteri (fun b d ->
      if b <> 0 && d >= 0 then children.(d) <- b :: children.(d)) idom;
    let set = sets fn in
    let same = Hashtbl.create 16 in
    let rep v = match Hashtbl.find_opt same v with Some r -> r | None -> v in
    let def v = Hashtbl.find fn.defs v in
    (* the pure instructions of the blocks that dominate this one, by
     * their text, their operands already the first of each, and what
     * the value is: one text may be a word, an untagged integer
     * (Untag's Add of a tagged and an untagged) or a double *)
    let seen = Hashtbl.create 64 in
    let rec walk b =
      let blk = fn.blocks.(b) in
      let added = ref [] in
      blk.body <- List.filter (fun v ->
        let ins = Ssa_build.map_ins rep (def v) in
        Hashtbl.replace fn.defs v ins;
        if not (pure ~set ins) then true
        else
          let key = ins, Hashtbl.mem fn.raws v, Hashtbl.mem fn.doubles v in
          match Hashtbl.find_opt seen key with
          | Some r -> Hashtbl.replace same v r; false
          | None -> Hashtbl.add seen key v; added := key :: !added; true)
        blk.body;
      List.iter walk children.(b);
      List.iter (Hashtbl.remove seen) !added
    in
    if n > 0 then walk 0;
    (* (a phi's operand may come from a block walked after it: a loop's) *)
    if Hashtbl.length same > 0 then begin
      Array.iter (fun (blk : block) ->
        List.iter (fun v ->
          Hashtbl.replace fn.defs v (Ssa_build.map_ins rep (def v))) blk.phis;
        blk.term <- Ssa_build.map_term rep blk.term) fn.blocks;
      Hashtbl.iter (fun v _ -> Hashtbl.remove fn.defs v) same
    end;
    fn
  end
