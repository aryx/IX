(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Licm.mli *)

open Ssa

let on = ref true

(* pure (Cse's), and that cannot fail where the loop would not have run
 * it: not a division (by zero). A constant too (Cse's): it lives
 * nowhere (Emit makes it where it is read), and i * 48's 48 in the
 * loop kept i * 48 in it *)
let movable ~set (ins : ins) =
  match ins with
  | Op ((Ir.Div | Mod), _) -> false
  | _ -> Cse.pure ~set ins

(* (not a function with a handler, as Untag and Cse) *)
let func (fn : func) : func =
  if (not !on) || Cse.handler fn then fn
  else begin
    let n = Array.length fn.blocks in
    let idom = Ssa_build.dominators fn in
    let rec dominates a b =
      a = b || (b <> 0 && idom.(b) >= 0 && dominates a idom.(b)) in
    (* a loop: a jump back to a block that dominates it, its header; its
     * blocks those that reach the jump without passing the header *)
    let loops = Hashtbl.create 8 in
    Array.iter (fun (b : block) ->
      if idom.(b.id) >= 0 then
        List.iter (fun h ->
          if h <> 0 && dominates h b.id then begin
            let inside =
              match Hashtbl.find_opt loops h with
              | Some a -> a
              | None -> Array.make n false in
            inside.(h) <- true;
            let rec back x =
              if not inside.(x) then begin
                inside.(x) <- true;
                List.iter back fn.blocks.(x).preds
              end in
            back b.id;
            Hashtbl.replace loops h inside
          end) (Ssa_build.successors_of b)) fn.blocks;
    if Hashtbl.length loops > 0 then begin
      let set = Cse.sets fn in
      (* each value's block (a parameter's, the entry's) *)
      let where = Hashtbl.create 64 in
      Array.iter (fun (b : block) ->
        List.iter (fun v -> Hashtbl.replace where v b.id) (b.phis @ b.body))
        fn.blocks;
      let block_of x =
        match Hashtbl.find_opt where x with Some b -> b | None -> 0 in
      (* moved to the end of the header's immediate dominator, which
       * every way into the loop goes through; again until none moves,
       * for what an inner loop's moved makes invariant in the outer *)
      let changed = ref true in
      while !changed do
        changed := false;
        Hashtbl.iter (fun h (inside : bool array) ->
          let pre = fn.blocks.(idom.(h)) in
          let outside x = not inside.(block_of x) in
          Array.iter (fun (b : block) ->
            if inside.(b.id) then
              b.body <- List.filter (fun v ->
                let ins = Hashtbl.find fn.defs v in
                if movable ~set ins
                   && List.for_all outside (Ssa_build.operands ins)
                then begin
                  pre.body <- pre.body @ [ v ];
                  Hashtbl.replace where v pre.id;
                  changed := true;
                  false
                end
                else true) b.body) fn.blocks) loops
      done
    end;
    fn
  end
