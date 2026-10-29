(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dominators.mli *)

let idoms ~succs ~preds n =
  let order = ref [] and seen = Array.make n false in
  let rec dfs b =
    if not seen.(b) then begin
      seen.(b) <- true; List.iter dfs (succs b); order := b :: !order
    end
  in
  if n > 0 then dfs 0;
  let rpo = Array.make n 0 in
  List.iteri (fun i b -> rpo.(b) <- i) !order;
  let idom = Array.make n (-1) in
  if n > 0 then idom.(0) <- 0;
  let rec intersect a b =
    if a = b then a
    else if rpo.(a) > rpo.(b) then intersect idom.(a) b
    else intersect a idom.(b)
  in
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter (fun b ->
      if b <> 0 then
        match List.filter (fun p -> idom.(p) >= 0) (preds b) with
        | [] -> ()
        | p :: ps ->
            let d = List.fold_left intersect p ps in
            if idom.(b) <> d then (idom.(b) <- d; changed := true)) !order
  done;
  idom

let rec dominates (idom : int array) a b =
  a = b || (b <> 0 && idom.(b) >= 0 && dominates idom a idom.(b))

let children (idom : int array) =
  let c = Array.make (Array.length idom) [] in
  Array.iteri (fun b d -> if b <> 0 && d >= 0 then c.(d) <- b :: c.(d)) idom;
  c

let loop_depths ~succs ~preds (idom : int array) =
  let n = Array.length idom in
  let depth = Array.make n 0 in
  for b = 0 to n - 1 do
    List.iter (fun h ->
      if idom.(b) >= 0 && dominates idom h b then begin
        let body = Hashtbl.create 16 in
        Hashtbl.replace body h ();
        let rec back x =
          if not (Hashtbl.mem body x) then begin
            Hashtbl.replace body x (); List.iter back (preds x)
          end
        in
        back b;
        Hashtbl.iter (fun x () -> depth.(x) <- depth.(x) + 1) body
      end) (succs b)
  done;
  depth
