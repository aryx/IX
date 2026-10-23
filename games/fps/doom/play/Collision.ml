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
  pdropoffz : float; (* the lowest floor under the box *)
  blocker : Level.line option; (* the line that stopped it, or that set the room *)
  special_lines : Level.line list;
  hit : Things.target; (* a missile's: what it ran into *)
}

(* the box of who moves: its radius, its feet, its height *)
let box (t : t) (who : Things.target) : float * float * float =
  match who with
  | Things.Thing m -> (Things.radius m, m.mz, Things.height m)
  | _ -> (radius, t.player.z, height)

(* P_CheckPosition, PIT_CheckLine, P_LineOpening: the lines of the
 * blockmap's cells under the box; then PIT_CheckThing: the solid
 * things', and the player's for a thing *)
let check_position (t : t) (who : Things.target) (x : float) (y : float) : position =
  let level = t.level in
  let s = Level.sector_at level x y in
  let radius, z, h = box t who in
  let mover = match who with Things.Thing m -> Some m | _ -> None in
  let is_missile =
    match mover with Some m -> m.flags land Info.missile <> 0 | None -> false in
  let floorz = ref s.floor and ceilingz = ref s.ceiling and dropoffz = ref s.floor in
  let blocker = ref None and specials = ref [] and ok = ref true in
  let hit = ref Things.Nobody in
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
            (* (a monster's lines too: ML_BLOCKMONSTERS, 2; not a
             * missile's) *)
            let blocks =
              (l.flags land Level.blocking <> 0 && not is_missile)
              || (mover <> None && not is_missile && l.flags land 2 <> 0) in
            if right > lleft && left < lright && top > lbottom && bottom < ltop && box_on_line_side left right bottom top l = -1 then
              match (l.back, Level.line_sector level l 0, Level.line_sector level l 1) with
              | Some _, Some f, Some b when not blocks ->
                  let opentop = Float.min f.ceiling b.ceiling and openbottom = Float.max f.floor b.floor in
                  let lowfloor = Float.min f.floor b.floor in
                  if opentop < !ceilingz then begin ceilingz := opentop; blocker := Some l end;
                  if openbottom > !floorz then begin floorz := openbottom; blocker := Some l end;
                  if lowfloor < !dropoffz then dropoffz := lowfloor;
                  if l.special <> 0 then specials := l :: !specials
              | _ ->
                  ok := false;
                  blocker := Some l
          end)
        bm.cells.((by * bm.columns) + bx)
    done
  done;
  (* PIT_CheckThing: a solid thing's box and the mover's overlap; a
   * missile's, a shootable thing hit (not its shooter, its target) *)
  let overlaps (ox : float) (oy : float) (r : float) : bool =
    let d = r +. radius in
    Float.abs (ox -. x) < d && Float.abs (oy -. y) < d in
  List.iter
    (fun (m : Things.mobj) ->
      let self = match mover with Some me -> me == m | None -> false in
      let blocks = m.flags land (Info.solid lor Info.shootable) <> 0 in
      if !ok && m.alive && (not self) && blocks
         && overlaps m.mx m.my (Things.radius m)
      then
        if is_missile then begin
          let shooter =
            match mover with
            | Some me -> (match me.target with Things.Thing s -> s == m | _ -> false)
            | None -> false in
          (* (over it or under it: missed) *)
          let across = z <= m.mz +. Things.height m && z +. h >= m.mz in
          if (not shooter) && across && m.flags land Info.shootable <> 0
          then begin
            ok := false;
            hit := Things.Thing m
          end
        end
        else if m.flags land Info.solid <> 0 then ok := false)
    t.things;
  (* (the player, for a thing; dead, not solid) *)
  (match mover with
  | Some m
    when !ok && t.player.health > 0 && overlaps t.player.x t.player.y radius ->
      let p = t.player in
      if not is_missile then ok := false
      else if m.target <> Things.The_player && z <= p.z +. height
              && z +. h >= p.z
      then begin
        ok := false;
        hit := Things.The_player
      end
  | _ -> ());
  { ok = !ok; pfloorz = !floorz; pceilingz = !ceilingz; pdropoffz = !dropoffz;
    blocker = !blocker; special_lines = !specials; hit = !hit }

(* P_TryMove: the player moved to (x, y) if it fits; each line with a
 * special crossed given to [cross] (P_CrossSpecialLine, which id's
 * P_TryMove calls itself: here Specials', by Play) *)
let try_move (cross : Level.line -> unit) (t : t) (x : float) (y : float) : bool * Level.line option =
  let p = t.player in
  let pos = check_position t Things.The_player x y in
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

(* P_UnsetThingPosition, P_SetThingPosition: a thing in its sector's
 * list, for Render *)
let set_position (t : t) (m : Things.mobj) (x : float) (y : float) : unit =
  let s = Level.sector_at t.level x y in
  if s != m.sector then begin
    let k = m.sector.index in
    t.by_sector.(k) <- List.filter (fun (o : Things.mobj) -> o != m) t.by_sector.(k);
    t.by_sector.(s.index) <- m :: t.by_sector.(s.index);
    m.sector <- s
  end;
  m.mx <- x;
  m.my <- y

(* P_TryMove for a thing: the room to stand, a step of 24 at most, and
 * (a monster) no drop of more than 24 either; else the position's,
 * whose lines with specials P_Move may open *)
let try_move_thing (t : t) (m : Things.mobj) (x : float) (y : float)
    : bool * position =
  let pos = check_position t (Things.Thing m) x y in
  let h = Things.height m in
  let fits =
    pos.ok && pos.pceilingz -. pos.pfloorz >= h && pos.pceilingz -. m.mz >= h
    && (m.flags land Info.missile <> 0 || pos.pfloorz -. m.mz <= maxstep)
    && (m.flags land (Info.dropoff lor Info.missile) <> 0
        || pos.pfloorz -. pos.pdropoffz <= maxstep) in
  if fits then begin
    set_position t m x y;
    m.floorz <- pos.pfloorz;
    m.ceilingz <- pos.pceilingz
  end;
  (fits, pos)

(* the player's place again after a sector moved (P_ChangeSector,
 * P_ThingHeightClip): on the floor, he goes with it; false if he no
 * longer fits. The things' too: one that no longer fits stops the
 * sector as the player does, but a corpse (crushed, in id's) *)
let change_sector (t : t) : bool =
  let p = t.player in
  let onfloor = p.z = p.floorz in
  let pos = check_position t Things.The_player p.x p.y in
  p.floorz <- pos.pfloorz;
  p.ceilingz <- pos.pceilingz;
  if onfloor then p.z <- p.floorz else if p.z +. height > p.ceilingz then p.z <- p.ceilingz -. height;
  let things_fit =
    List.for_all
      (fun (m : Things.mobj) ->
        let collides = m.actor <> None && m.flags land Info.noblockmap = 0 in
        if not (m.alive && collides) then true
        else begin
          let onfloor = m.mz = m.floorz in
          let pos = check_position t (Things.Thing m) m.mx m.my in
          m.floorz <- pos.pfloorz;
          m.ceilingz <- pos.pceilingz;
          if onfloor then m.mz <- m.floorz;
          m.ceilingz -. m.floorz >= Things.height m || m.flags land Info.corpse <> 0
        end)
      t.things in
  p.ceilingz -. p.floorz >= height && things_fit

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

(*****************************************************************************)
(* Along a line: what sees, what shoots *)
(*****************************************************************************)

(* the lines of the blockmap's cells a segment goes through, each once
 * (P_PathTraverse's walk of the cells, Amanatides and Woo's: from one
 * cell to the next across whichever of its sides the segment meets
 * first) *)
let lines_along (t : t) (x1 : float) (y1 : float) (x2 : float) (y2 : float)
    : Level.line list =
  let bm = t.level.blockmap in
  let cx (x : float) : float = (x -. bm.originx) /. 128.
  and cy (y : float) : float = (y -. bm.originy) /. 128. in
  let fx1 = cx x1 and fy1 = cy y1 and fx2 = cx x2 and fy2 = cy y2 in
  let bx = ref (int_of_float (Float.floor fx1))
  and by = ref (int_of_float (Float.floor fy1)) in
  let ex = int_of_float (Float.floor fx2) and ey = int_of_float (Float.floor fy2) in
  let dx = fx2 -. fx1 and dy = fy2 -. fy1 in
  let stepx = if dx > 0. then 1 else -1 and stepy = if dy > 0. then 1 else -1 in
  (* (the fraction of the segment to the next column's side, the next
   * row's, and the fraction a whole cell is) *)
  let delta (d : float) : float = if d = 0. then infinity else Float.abs (1. /. d) in
  let first (f : float) (d : float) (b : int) : float =
    if d > 0. then (float (b + 1) -. f) *. delta d
    else if d < 0. then (f -. float b) *. delta d
    else infinity in
  let tx = ref (first fx1 dx !bx) and ty = ref (first fy1 dy !by) in
  let seen = Hashtbl.create 64 and acc = ref [] in
  let visit (x : int) (y : int) : unit =
    if x >= 0 && x < bm.columns && y >= 0 && y < bm.rows then
      Array.iter
        (fun (k : int) ->
          if not (Hashtbl.mem seen k) then begin
            Hashtbl.replace seen k ();
            acc := t.level.lines.(k) :: !acc
          end)
        bm.cells.((y * bm.columns) + x) in
  visit !bx !by;
  let n = abs (ex - !bx) + abs (ey - !by) in
  for _i = 1 to n do
    if !tx < !ty then begin bx := !bx + stepx; tx := !tx +. delta dx end
    else begin by := !by + stepy; ty := !ty +. delta dy end;
    visit !bx !by
  done;
  !acc

(* where the segment from (x1, y1) by (dx, dy) crosses the line, as a
 * fraction of the segment, if it does *)
let crossing (x1 : float) (y1 : float) (dx : float) (dy : float)
    (l : Level.line) : float option =
  let ex = l.v2.x -. l.v1.x and ey = l.v2.y -. l.v1.y in
  let den = (dx *. ey) -. (dy *. ex) in
  if den = 0. then None
  else
    let u = (((l.v1.x -. x1) *. ey) -. ((l.v1.y -. y1) *. ex)) /. den in
    let v = (((l.v1.x -. x1) *. dy) -. ((l.v1.y -. y1) *. dx)) /. den in
    if u >= 0. && u <= 1. && v >= 0. && v <= 1. then Some u else None

(* P_LineOpening: the room between a two-sided line's sectors, the
 * higher floor and the lower ceiling; None for a wall *)
let opening (t : t) (l : Level.line) : (float * float) option =
  match (Level.line_sector t.level l 0, Level.line_sector t.level l 1) with
  | Some f, Some b when l.back <> None ->
      Some (Float.max f.floor b.floor, Float.min f.ceiling b.ceiling)
  | _ -> None

(* P_CheckSight: from the eye at (x1, y1, z1) to the box of (x2, y2)
 * from z2 to z2 + h2, a part of it seen through every line between:
 * id keeps the slopes of the eye to the top and the bottom of what is
 * still in view, and narrows them at each opening; seen if some is
 * left. (id walks the BSP from both ends; here the blockmap's cells
 * along the line, the same lines) *)
let check_sight (t : t) (x1 : float) (y1 : float) (z1 : float) (x2 : float)
    (y2 : float) (z2 : float) (h2 : float) : bool =
  let dx = x2 -. x1 and dy = y2 -. y1 in
  let dist = Float.sqrt ((dx *. dx) +. (dy *. dy)) in
  let top = ref ((z2 +. h2 -. z1) /. dist) and bottom = ref ((z2 -. z1) /. dist) in
  List.for_all
    (fun (l : Level.line) ->
      match crossing x1 y1 dx dy l with
      | None -> true
      | Some u -> (
          match opening t l with
          | None -> false
          | Some (openbottom, opentop) ->
              let d = u *. dist in
              if openbottom >= opentop then false
              else if d <= 0. then true
              else begin
                top := Float.min !top ((opentop -. z1) /. d);
                bottom := Float.max !bottom ((openbottom -. z1) /. d);
                !top > !bottom
              end))
    (lines_along t x1 y1 x2 y2)

(* what a shot's line meets (P_PathTraverse's intercepts): a line, a
 * thing, the player, at a fraction of the way, the nearest first *)
type intercept =
  | Line of float * Level.line
  | Thing_hit of float * Things.mobj
  | Player_hit of float

let fraction (i : intercept) : float =
  match i with Line (f, _) | Thing_hit (f, _) | Player_hit f -> f

(* [intercepts t shooter x1 y1 x2 y2]: the lines across, and the things
 * (not the shooter) whose box the line goes through: here their
 * nearest point to the line within their radius (id: the box's
 * diagonal facing the line, PIT_AddThingIntercepts) *)
let intercepts (t : t) (shooter : Things.target) (x1 : float) (y1 : float)
    (x2 : float) (y2 : float) : intercept list =
  let dx = x2 -. x1 and dy = y2 -. y1 in
  let len2 = (dx *. dx) +. (dy *. dy) in
  let near (x : float) (y : float) (r : float) : float option =
    let u = (((x -. x1) *. dx) +. ((y -. y1) *. dy)) /. len2 in
    let px = x1 +. (u *. dx) and py = y1 +. (u *. dy) in
    let d2 = ((x -. px) *. (x -. px)) +. ((y -. py) *. (y -. py)) in
    if d2 > r *. r then None
    else
      let u = u -. (Float.sqrt ((r *. r) -. d2) /. Float.sqrt len2) in
      if u >= 0. && u <= 1. then Some u else None in
  let lines =
    List.filter_map
      (fun (l : Level.line) ->
        Option.map (fun (u : float) -> Line (u, l)) (crossing x1 y1 dx dy l))
      (lines_along t x1 y1 x2 y2) in
  let things =
    List.filter_map
      (fun (m : Things.mobj) ->
        let self = match shooter with Things.Thing s -> s == m | _ -> false in
        if m.alive && (not self) && m.flags land Info.shootable <> 0 then
          Option.map
            (fun (u : float) -> Thing_hit (u, m))
            (near m.mx m.my (Things.radius m))
        else None)
      t.things in
  let player =
    if shooter = Things.The_player || t.player.health <= 0 then []
    else
      match near t.player.x t.player.y radius with
      | Some u -> [ Player_hit u ]
      | None -> [] in
  List.sort
    (fun (a : intercept) (b : intercept) -> compare (fraction a) (fraction b))
    (lines @ things @ player)
