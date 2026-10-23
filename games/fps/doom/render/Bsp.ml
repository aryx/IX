(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bsp.mli *)

(*****************************************************************************)
(* The closed columns (solidsegs) *)
(*****************************************************************************)

(* the open runs of columns first to last, the gaps between solidsegs'
 * ranges, each given to [f] (R_ClipPassWallSegment's loop) *)
let gaps (r : View.t) (first : int) (last : int) (f : int -> int -> unit) : unit =
  let rec go (x : int) (ranges : (int * int) list) : unit =
    if x <= last then
      match ranges with
      | [] -> f x last
      | (a, b) :: rest ->
          if a > x then f x (min last (a - 1));
          go (max x (b + 1)) rest in
  go first r.solidsegs

(* R_ClipSolidWallSegment: the gaps drawn, then first to last closed,
 * merged with the ranges it overlaps or touches *)
let clip_solid (r : View.t) (first : int) (last : int) (f : int -> int -> unit) : unit =
  gaps r first last f;
  let before = List.filter (fun ((_, b) : int * int) -> b < first - 1) r.solidsegs in
  let after = List.filter (fun ((a, _) : int * int) -> a > last + 1) r.solidsegs in
  let merged =
    List.fold_left
      (fun ((lo, hi) : int * int) ((a, b) : int * int) -> if b >= first - 1 && a <= last + 1 then (min lo a, max hi b) else (lo, hi))
      (first, last) r.solidsegs in
  r.solidsegs <- before @ (merged :: after)

(* R_ClipPassWallSegment: the gaps drawn, nothing closed (a window, a
 * step: what is behind is seen through) *)
let clip_pass (r : View.t) (first : int) (last : int) (f : int -> int -> unit) : unit = gaps r first last f

(*****************************************************************************)
(* The segs *)
(*****************************************************************************)

(* the two angles of a segment from the eye clipped to the view
 * (R_AddLine's and R_CheckBBox's): None if outside it, else its
 * columns *)
let columns_of (r : View.t) (angle1 : float) (angle2 : float) : (int * int) option =
  let clip = View.clipangle r in
  let span = View.norm (angle1 -. angle2) in
  if span >= View.pi then Some (0, r.width) (* (R_CheckBBox's: the eye in its span) *)
  else
    let a1 = View.norm (angle1 -. r.viewangle) and a2 = View.norm (angle2 -. r.viewangle) in
    let out = ref false in
    let a1 =
      let tspan = View.norm (a1 +. clip) in
      if tspan > 2. *. clip then (if tspan -. (2. *. clip) >= span then out := true; clip) else a1 in
    let a2 =
      let tspan = View.norm (clip -. a2) in
      if tspan > 2. *. clip then (if tspan -. (2. *. clip) >= span then out := true; -.clip) else a2 in
    if !out then None
    else
      let x1 = View.x_of_angle r (View.signed a1) and x2 = View.x_of_angle r (View.signed a2) in
      if x1 = x2 then None else Some (x1, x2)

(* R_AddLine *)
let add_line (r : View.t) (textures : Textures.t) (level : Level.t) (pl : View.planes) (seg : Level.seg) : unit =
  let angle1 = View.point_to_angle r seg.sv1.x seg.sv1.y and angle2 = View.point_to_angle r seg.sv2.x seg.sv2.y in
  (* (its back seen: more than half a turn from v1 to v2) *)
  if View.norm (angle1 -. angle2) < View.pi then
    match columns_of r angle1 angle2 with
    | None -> ()
    | Some (x1, x2) -> (
        let store = Segs.store_wall_range r textures level pl seg angle1 in
        match seg.back_sector with
        | None -> clip_solid r x1 (x2 - 1) store
        | Some back ->
            let front = seg.front_sector in
            if back.ceiling <= front.floor || back.floor >= front.ceiling then clip_solid r x1 (x2 - 1) store
            else if
              back.ceiling <> front.ceiling || back.floor <> front.floor || back.ceilingpic <> front.ceilingpic
              || back.floorpic <> front.floorpic || back.light <> front.light || seg.side.middle >= 0
            then clip_pass r x1 (x2 - 1) store
            (* (the same sector on both sides, nothing on the line: nothing
             * to draw, an editor's line) *))

(*****************************************************************************)
(* The tree *)
(*****************************************************************************)

(* R_CheckBBox: may a box (top, bottom, left, right) be seen? *)
let check_box (r : View.t) (box : float array) : bool =
  let top = box.(0) and bottom = box.(1) and left = box.(2) and right = box.(3) in
  let bx = if r.viewx <= left then 0 else if r.viewx < right then 1 else 2 in
  let by = if r.viewy >= top then 0 else if r.viewy > bottom then 1 else 2 in
  if bx = 1 && by = 1 then true
  else
    (* the box's two corners that are its edges from the eye
     * (checkcoord) *)
    let x1, y1, x2, y2 =
      match (by * 3) + bx with
      | 0 -> (right, top, left, bottom)
      | 1 -> (right, top, left, top)
      | 2 -> (right, bottom, left, top)
      | 3 -> (left, top, left, bottom)
      | 5 -> (right, bottom, right, top)
      | 6 -> (left, top, right, bottom)
      | 7 -> (left, bottom, right, bottom)
      | _ -> (left, bottom, right, top) in
    match columns_of r (View.point_to_angle r x1 y1) (View.point_to_angle r x2 y2) with
    | None -> false
    | Some (sx1, sx2) ->
        (* not all in one closed range (they are merged: one covers
         * them, or some column is open) *)
        not (List.exists (fun ((a, b) : int * int) -> a <= sx1 && b >= sx2 - 1) r.solidsegs)

(* R_Subsector *)
let subsector (r : View.t) (textures : Textures.t) (level : Level.t) (sprites : Things.sprites) (things : Things.mobj list array) (tic : int)
    (k : int) : unit =
  let sub = level.subsectors.(k) in
  let s = sub.sub_sector in
  (* R_AddSprites: a sector's things, once a frame *)
  if r.sector_seen.(s.index) <> r.frame_number then begin
    r.sector_seen.(s.index) <- r.frame_number;
    List.iter (fun (m : Things.mobj) -> if m.alive then Sprites.project_sprite r sprites tic m) things.(s.index)
  end;
  let pl : View.planes =
    { floorplane = (if s.floor < r.viewz then Some (Planes.find_plane r textures s.floor s.floorpic s.light) else None);
      ceilingplane =
        (if s.ceiling > r.viewz || s.ceilingpic = textures.sky_flat then Some (Planes.find_plane r textures s.ceiling s.ceilingpic s.light) else None) } in
  for i = sub.first to sub.first + sub.count - 1 do add_line r textures level pl level.segs.(i) done

(* R_RenderBSPNode: nearest first, the far side only if its box may be
 * seen (once every column is closed, no box may: the walk goes on
 * through the near sides only, each seg refused by its clip)
 * old: an early stop, if every column was closed (an open_columns
 *   count); the same frames, no faster, and not id's *)
let rec render_node (r : View.t) (textures : Textures.t) (level : Level.t) (sprites : Things.sprites) (things : Things.mobj list array) (tic : int)
    (c : Level.child) : unit =
  match c with
  | Level.Subsector k -> subsector r textures level sprites things tic k
  | Level.Node k ->
      let n = level.nodes.(k) in
      let side = Level.point_on_side r.viewx r.viewy n in
      render_node r textures level sprites things tic n.children.(side);
      if check_box r n.boxes.(1 - side) then render_node r textures level sprites things tic n.children.(1 - side)
