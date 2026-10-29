(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Liveness.mli *)

module IS = Set_

let ssa ~succs ~phis ~phi_uses ~term_uses ~body ~uses n =
  let live_in = Array.make n IS.empty and live_out = Array.make n IS.empty in
  let changed = ref true in
  while !changed do
    changed := false;
    for b = n - 1 downto 0 do
      let out =
        List.fold_left (fun s x ->
          IS.union s
            (IS.union (IS.diff live_in.(x) (IS.of_list (phis x)))
               (IS.of_list (phi_uses x b)))) IS.empty (succs b)
      in
      let live = ref (IS.union out (IS.of_list (term_uses b))) in
      List.iter (fun v -> live := IS.union (IS.remove v !live) (IS.of_list (uses v)))
        (List.rev (body b));
      let inn = IS.union !live (IS.of_list (phis b)) in
      live_out.(b) <- out;
      if not (IS.equal inn live_in.(b)) then (live_in.(b) <- inn; changed := true)
    done
  done;
  live_in, live_out

let after ~term_uses ~body ~uses live_out n =
  let at = Hashtbl.create 256 in
  for b = 0 to n - 1 do
    let live = ref (IS.union live_out.(b) (IS.of_list (term_uses b))) in
    List.iter (fun v ->
      Hashtbl.replace at v !live;
      live := IS.union (IS.remove v !live) (IS.of_list (uses v))) (List.rev (body b))
  done;
  at
