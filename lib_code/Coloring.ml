(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Coloring.mli *)

module IS = Set_

let points live_in (after : (int, int IS.t) Hashtbl.t) =
  let all =
    Array.to_list live_in
    @ List.map snd
        (List.sort compare (Hashtbl.fold (fun v live acc -> (v, live) :: acc) after []))
  in
  let at = Hashtbl.create 256 in
  List.iteri (fun k live ->
    IS.iter (fun v ->
      Hashtbl.replace at v
        (k :: (match Hashtbl.find_opt at v with Some l -> l | None -> []))) live) all;
  List.length all, at

let choose ~npoints ~at ~nregs (wanted : (int * int) list) =
  let count = Array.make npoints 0 and chosen = Hashtbl.create 64 in
  let order ((w1, v1) : int * int) ((w2, v2) : int * int) =
    if w1 <> w2 then compare w2 w1 else compare v1 v2 in
  List.iter (fun (_, v) ->
    let ks = match Hashtbl.find_opt at v with Some l -> l | None -> [] in
    if List.for_all (fun k -> count.(k) < nregs) ks then begin
      Hashtbl.replace chosen v ();
      List.iter (fun k -> count.(k) <- count.(k) + 1) ks
    end) (List.sort order wanted);
  chosen

let walk ~children ~live_in ~phis ~body ~candidate ~busy ~hints ncolors =
  let color = Hashtbl.create 64 in
  let held s =
    IS.fold (fun x acc ->
      match Hashtbl.find_opt color x with Some c -> IS.add c acc | None -> acc) s IS.empty
  in
  let pick v busy =
    let hinted = List.filter_map (Hashtbl.find_opt color) (hints v) in
    match List.find_opt (fun c -> not (IS.mem c busy)) hinted with
    | Some c -> Some c
    | None ->
        let rec go c = if c >= ncolors then None else if IS.mem c busy then go (c + 1) else Some c in
        go 0
  in
  let rec visit b =
    let busy_in = ref (held (IS.diff live_in.(b) (IS.of_list (phis b)))) in
    List.iter (fun v ->
      if candidate v then
        match pick v !busy_in with
        | Some c -> Hashtbl.replace color v c; busy_in := IS.add c !busy_in
        | None -> ()) (phis b);
    List.iter (fun v ->
      if candidate v then
        match pick v (held (busy v)) with
        | Some c -> Hashtbl.replace color v c
        | None -> ()) (body b);
    List.iter visit (List.rev children.(b))
  in
  if Array.length live_in > 0 then visit 0;
  color
