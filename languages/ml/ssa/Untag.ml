(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Untag.mli *)

open Ssa

let on = ref true

(* the bits of c's bound: the least b with c in [-2^b, 2^b), counted by
 * shifts (mini-ml on arm has ints of 31 bits: no 1 lsl 40) *)
let bound c =
  let rec count n b = if n = 0 then b else count (n lsr 1) (b + 1) in
  count (if c >= 0 then c else lnot c) 0

let func ~bits (fn : func) : func =
  let handler = Array.exists (fun (b : block) -> match b.term with Try _ -> true | _ -> false) fn.blocks in
  if (not !on) || handler then fn
  else begin
    let def v = Hashtbl.find fn.defs v in
    (* (a value in [-2^limit, 2^limit) is an int: no wrap) *)
    let limit = bits - 1 in
    let next = ref (Hashtbl.fold (fun v _ m -> max m (v + 1)) fn.defs 0) in
    let fresh ins = let v = !next in incr next; Hashtbl.replace fn.defs v ins; v in
    let body = List.concat_map (fun (b : block) -> b.body) (Array.to_list fn.blocks) in
    (* the set, optimistic first, then each value kept while its rule
     * holds with the others' and something reads it untagged *)
    let raws = fn.raws in
    let raw x = Hashtbl.mem raws x in
    let const x = match def x with Const c -> Some c | _ -> None in
    let operand x = if raw x then Some (Hashtbl.find raws x) else Option.map bound (const x) in
    let rule v =
      match def v with
      | Prim (Ir.ByteGet _, [ _; _ ]) -> Some 8
      | Op (Ir.Asr, [ x; y ]) -> (
          match const y with
          | Some k when k >= 1 -> Some (max 0 ((if raw x then Hashtbl.find raws x else limit) - k))
          | _ -> None)
      | Op (Ir.And, [ x; y ]) -> (
          match const x, const y with
          | None, Some c when c >= 0 && raw x -> Some (bound c)
          | Some c, None when c >= 0 && raw y -> Some (bound c)
          | _ -> None)
      | Op ((Ir.Add | Sub), [ x; y ]) when raw x || raw y -> (
          match operand x, operand y with Some a, Some b -> Some (max a b + 1) | _ -> None)
      | Op (Ir.Lsl, [ x; y ]) when raw x -> (
          match const y with Some k when k >= 0 -> Some (Hashtbl.find raws x + k) | _ -> None)
      | _ -> None
    in
    (* the operands an instruction reads untagged, its result untagged or
     * not: an untagged value's own; a byte's index and the byte stored;
     * the untagged one of a tagged sum or difference (the second of a
     * difference) *)
    let reads_raw v x =
      match def v with
      | Prim ((Ir.ByteGet _ | ByteSet _), _ :: i :: rest) -> x = i || rest = [ x ]
      | Op ((Ir.Asr | And | Add | Sub | Lsl), _) when raw v -> true
      | Op (Ir.Add, [ a; b ]) -> (x = b && raw b) || (x = a && raw a && not (raw b))
      | Op (Ir.Sub, [ _; b ]) -> x = b
      | _ -> false
    in
    let users = Hashtbl.create 64 in
    List.iter (fun v -> List.iter (fun x -> Hashtbl.replace users x (v :: (match Hashtbl.find_opt users x with Some l -> l | None -> []))) (Ssa_build.operands (def v))) body;
    (* optimistic: every value whose rule holds as values become so *)
    let changed = ref true in
    while !changed do
      changed := false;
      List.iter (fun v ->
        if not (raw v) then
          match rule v with Some b when b <= limit -> Hashtbl.replace raws v b; changed := true | _ -> ()) body
    done;
    (* then down to the values whose rule still holds, and read untagged
     * by something (a byte read stays: its tag is no dearer later) *)
    changed := true;
    while !changed do
      changed := false;
      List.iter (fun v ->
        if raw v then begin
          let keep =
            match rule v with
            | Some b when b <= limit ->
                Hashtbl.replace raws v b;
                (match def v with Prim (Ir.ByteGet _, _) -> true | _ -> false)
                || List.exists (fun u -> reads_raw u v) (match Hashtbl.find_opt users v with Some l -> l | None -> [])
            | _ -> false
          in
          if not keep then (Hashtbl.remove raws v; changed := true)
        end) body
    done;
    if Hashtbl.length raws = 0 then fn
    else begin
      (* each untagged value read as a word: tagged once, after it *)
      let tags = Hashtbl.create 16 in
      let tagged x = if raw x then (match Hashtbl.find_opt tags x with Some t -> t | None -> let t = fresh (Tag x) in Hashtbl.replace tags x t; t) else x in
      let rewrite v =
        match def v with
        | Prim ((Ir.ByteGet _ | ByteSet _) as p, s :: rest) -> Prim (p, tagged s :: rest)
        | Op (o, xs) when raw v -> Op (o, xs)
        | Op (Ir.Add, [ a; b ]) when raw b -> Op (Ir.Add, [ tagged a; b ])
        | Op (Ir.Add, [ a; b ]) when raw a -> Op (Ir.Add, [ a; b ])
        | Op (Ir.Sub, [ a; b ]) -> Op (Ir.Sub, [ tagged a; b ])
        | ins -> Ssa_build.map_ins tagged ins
      in
      (* (the phis, the terms and the instructions read what they read
       * tagged first, then the tags put after their values) *)
      Array.iter (fun (b : block) ->
        List.iter (fun v -> Hashtbl.replace fn.defs v (Ssa_build.map_ins tagged (def v))) b.phis;
        List.iter (fun v -> Hashtbl.replace fn.defs v (rewrite v)) b.body;
        b.term <- Ssa_build.map_term tagged b.term) fn.blocks;
      Array.iter (fun (b : block) ->
        b.body <- List.concat_map (fun v -> match Hashtbl.find_opt tags v with Some t -> [ v; t ] | None -> [ v ]) b.body) fn.blocks;
      fn
    end
  end
