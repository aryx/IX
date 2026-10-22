(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Collision.mli *)

open World

(* P_BoxOnLineSide: 0 or 1 if the box is all on one side, else -1 *)
let box_on_line_side (left : float) (right : float) (bottom : float) (top : float) (l : Level.line) : int =
  let dx = l.v2.x -. l.v1.x and dy = l.v2.y -. l.v1.y in
  let side (x : float) (y : float) : int = Level.point_on_line_side x y l in
  let p1, p2 =
    if dy = 0. then
      let a = if top > l.v1.y then 1 else 0 and b = if bottom > l.v1.y then 1 else 0 in
      if dx < 0. then (1 - a, 1 - b) else (a, b)
    else if dx = 0. then
      let a = if right < l.v1.x then 1 else 0 and b = if left < l.v1.x then 1 else 0 in
      if dy < 0. then (1 - a, 1 - b) else (a, b)
    else if (dx > 0.) = (dy > 0.) then (side left top, side right bottom)
    else (side right top, side left bottom) in
  if p1 = p2 then p1 else -1

(* what P_CheckPosition finds for the box at (x, y) *)
type position = {
  ok : bool;
  pfloorz : float;
  pceilingz : float;
  blocker : Level.line option; (* the line that stopped it, or that set the room *)
  special_lines : Level.line list;
}

(* P_CheckPosition, PIT_CheckLine, P_LineOpening: the lines of the
 * blockmap's cells under the box *)
let check_position (t : t) (x : float) (y : float) : position =
  let level = t.level in
  let s = Level.sector_at level x y in
  let floorz = ref s.floor and ceilingz = ref s.ceiling and blocker = ref None and specials = ref [] and ok = ref true in
  let left = x -. radius and right = x +. radius and bottom = y -. radius and top = y +. radius in
  let bm = level.blockmap in
  let cell (v : float) (o : float) : int = int_of_float (Float.floor ((v -. o) /. 128.)) in
  let xl = max 0 (cell left bm.originx) and xh = min (bm.columns - 1) (cell right bm.originx) in
  let yl = max 0 (cell bottom bm.originy) and yh = min (bm.rows - 1) (cell top bm.originy) in
  let seen = Hashtbl.create 16 in
  for by = yl to yh do
    for bx = xl to xh do
      Array.iter
        (fun (k : int) ->
          if !ok && not (Hashtbl.mem seen k) then begin
            Hashtbl.replace seen k ();
            let l = level.lines.(k) in
            let lleft = Float.min l.v1.x l.v2.x and lright = Float.max l.v1.x l.v2.x in
            let lbottom = Float.min l.v1.y l.v2.y and ltop = Float.max l.v1.y l.v2.y in
            if right > lleft && left < lright && top > lbottom && bottom < ltop && box_on_line_side left right bottom top l = -1 then
              match (l.back, Level.line_sector level l 0, Level.line_sector level l 1) with
              | Some _, Some f, Some b when l.flags land Level.blocking = 0 ->
                  let opentop = Float.min f.ceiling b.ceiling and openbottom = Float.max f.floor b.floor in
                  if opentop < !ceilingz then begin ceilingz := opentop; blocker := Some l end;
                  if openbottom > !floorz then begin floorz := openbottom; blocker := Some l end;
                  if l.special <> 0 then specials := l :: !specials
              | _ ->
                  ok := false;
                  blocker := Some l
          end)
        bm.cells.((by * bm.columns) + bx)
    done
  done;
  (* PIT_CheckThing: a solid thing's box and the player's overlap *)
  List.iter
    (fun (m : Things.mobj) ->
      let d = m.kind.radius +. radius in
      if m.alive && m.kind.solid && Float.abs (m.mx -. x) < d && Float.abs (m.my -. y) < d then ok := false)
    t.things;
  { ok = !ok; pfloorz = !floorz; pceilingz = !ceilingz; blocker = !blocker; special_lines = !specials }

(* P_TryMove: the player moved to (x, y) if it fits; each line with a
 * special crossed given to [cross] (P_CrossSpecialLine, which id's
 * P_TryMove calls itself: here Specials', by Play) *)
let try_move (cross : Level.line -> unit) (t : t) (x : float) (y : float) : bool * Level.line option =
  let p = t.player in
  let pos = check_position t x y in
  if not pos.ok then (false, pos.blocker)
  else if pos.pceilingz -. pos.pfloorz < height || pos.pceilingz -. p.z < height || pos.pfloorz -. p.z > maxstep then (false, pos.blocker)
  else begin
    let oldx = p.x and oldy = p.y in
    p.x <- x;
    p.y <- y;
    p.floorz <- pos.pfloorz;
    p.ceilingz <- pos.pceilingz;
    List.iter
      (fun (l : Level.line) ->
        if l.special <> 0 && Level.point_on_line_side oldx oldy l <> Level.point_on_line_side x y l then cross l)
      pos.special_lines;
    (true, None)
  end

(* the player's place again after a sector moved (P_ChangeSector,
 * P_ThingHeightClip): on the floor, he goes with it; false if he no
 * longer fits *)
let change_sector (t : t) : bool =
  let p = t.player in
  let onfloor = p.z = p.floorz in
  let pos = check_position t p.x p.y in
  p.floorz <- pos.pfloorz;
  p.ceilingz <- pos.pceilingz;
  if onfloor then p.z <- p.floorz else if p.z +. height > p.ceilingz then p.z <- p.ceilingz -. height;
  p.ceilingz -. p.floorz >= height

(* P_UseLines, PTR_UseTraverse: the lines across the 64 ahead, nearest
 * first; the first with a special is the one used, from its front; one
 * that closes the way ends it *)
let use_target (t : t) : Level.line option =
  let p = t.player in
  let x2 = p.x +. (userange *. View.fcos p.angle) and y2 = p.y +. (userange *. View.fsin p.angle) in
  let dx = x2 -. p.x and dy = y2 -. p.y in
  let hits =
    List.filter_map
      (fun (l : Level.line) ->
        let ex = l.v2.x -. l.v1.x and ey = l.v2.y -. l.v1.y in
        let den = (dx *. ey) -. (dy *. ex) in
        if den = 0. then None
        else
          let u = (((l.v1.x -. p.x) *. ey) -. ((l.v1.y -. p.y) *. ex)) /. den in
          let v = (((l.v1.x -. p.x) *. dy) -. ((l.v1.y -. p.y) *. dx)) /. den in
          if u >= 0. && u <= 1. && v >= 0. && v <= 1. then Some (u, l) else None)
      (Array.to_list t.level.lines) in
  let sorted = List.sort (fun ((a, _) : float * Level.line) ((b, _) : float * Level.line) -> compare a b) hits in
  let rec go (l : (float * Level.line) list) : Level.line option =
    match l with
    | [] -> None
    | (_, line) :: rest ->
        if line.special <> 0 then (if Level.point_on_line_side p.x p.y line = 0 then Some line else None)
        else
          match (Level.line_sector t.level line 0, Level.line_sector t.level line 1) with
          | Some f, Some b when Float.min f.ceiling b.ceiling -. Float.max f.floor b.floor > 0. -> go rest
          | _ -> None in
  go sorted
