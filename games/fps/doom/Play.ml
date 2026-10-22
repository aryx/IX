(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Play.mli *)

type player = {
  mutable x : float;
  mutable y : float;
  mutable z : float;
  mutable angle : float;
  mutable momx : float;
  mutable momy : float;
  mutable momz : float;
  mutable floorz : float;
  mutable ceilingz : float;
  mutable viewheight : float;
  mutable deltaviewheight : float;
  mutable viewz : float;
  mutable bob : float;
  mutable turnheld : int;
  mutable keys : int list;
}

type cmd = { forward : int; side : int; turn : int; use : bool }

(* a door: up to its top, then waiting, then down (dir 1, 0, -1) *)
type door_kind = Raise (* and close after *) | Open | Close

type door = {
  dsector : Level.sector;
  dkind : door_kind;
  mutable ddir : int;
  topheight : float;
  dspeed : float;
  mutable dcount : int;
}

(* a lift: down, waiting, up (status -1, 0, 1); done at its top *)
type plat = { psector : Level.sector; low : float; high : float; pspeed : float; mutable status : int; mutable pcount : int }

type floor_move = { fsector : Level.sector; dest : float; fspeed : float; fdir : int }

type light_kind = Flash | Strobe | Glow | Flicker

type light = {
  lsector : Level.sector;
  lkind : light_kind;
  minlight : int;
  maxlight : int;
  darktime : int;
  brighttime : int;
  mutable lcount : int;
  mutable gdir : int;
}

(* a switch that turns back: which of its side's textures, to what *)
type button = { bside : Level.side; where : int (* 0 top, 1 middle, 2 bottom *); texture : int; mutable btimer : int }

type thinker = { mutable alive : bool; what : what }
and what = Door of door | Plat of plat | Floor of floor_move | Light of light | Button of button

type t = {
  level : Level.t;
  textures : Textures.t;
  player : player;
  things : Things.mobj list;
  by_sector : Things.mobj list array; (* the things by their sectors' numbers *)
  mutable tic : int;
  mutable thinkers : thinker list;
  mutable message : string;
  mutable message_tics : int;
  mutable exited : bool;
  mutable secrets : int;
}

(* p_local.h and d_player.h's numbers *)
let radius = 16.
let height = 56.
let viewheight = 41.
let maxstep = 24.
let friction = 0.90625
let stopspeed = 1. /. 16.
let maxmove = 30.
let userange = 64.
let maxbob = 16.
let pi = 4. *. atan 1.

(* the lights' generator: Lehmer's, as the playground's; not id's table *)
let seed = ref 1
let random () : int = seed := (!seed * 16807) mod 2147483647; !seed land 255

let say (t : t) (msg : string) : unit = t.message <- msg; t.message_tics <- 4 * 35

(*****************************************************************************)
(* The sectors around *)
(*****************************************************************************)

let neighbours (t : t) (s : Level.sector) : Level.sector list =
  List.filter_map
    (fun (k : int) ->
      let l = t.level.lines.(k) in
      match (Level.line_sector t.level l 0, Level.line_sector t.level l 1) with
      | Some a, Some b -> if a == s then Some b else if b == s then Some a else None
      | _ -> None)
    s.lines

(* P_FindLowestCeilingSurrounding, P_FindLowestFloorSurrounding,
 * P_FindMinSurroundingLight *)
let lowest_ceiling (t : t) (s : Level.sector) : float = List.fold_left (fun (m : float) (n : Level.sector) -> Float.min m n.ceiling) 32767. (neighbours t s)
let lowest_floor (t : t) (s : Level.sector) : float = List.fold_left (fun (m : float) (n : Level.sector) -> Float.min m n.floor) s.floor (neighbours t s)
let min_light (t : t) (s : Level.sector) (max : int) : int = List.fold_left (fun (m : int) (n : Level.sector) -> min m n.light) max (neighbours t s)

let tagged (t : t) (tag : int) : Level.sector list = List.filter (fun (s : Level.sector) -> s.tag = tag) (Array.to_list t.level.sectors)

(* a sector already moving (id's specialdata) *)
let busy (t : t) (s : Level.sector) : thinker option =
  List.find_opt
    (fun (th : thinker) ->
      th.alive && match th.what with Door d -> d.dsector == s | Plat p -> p.psector == s | Floor f -> f.fsector == s | _ -> false)
    t.thinkers

let add (t : t) (w : what) : unit = t.thinkers <- t.thinkers @ [ { alive = true; what = w } ]

(*****************************************************************************)
(* Where the player can be *)
(*****************************************************************************)

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

(* the line crossed: what it does when walked over *)
let rec cross_special (t : t) (l : Level.line) : unit = line_special t l false

(* P_TryMove *)
and try_move (t : t) (x : float) (y : float) : bool * Level.line option =
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
        if l.special <> 0 && Level.point_on_line_side oldx oldy l <> Level.point_on_line_side x y l then cross_special t l)
      pos.special_lines;
    (true, None)
  end

(*****************************************************************************)
(* The specials *)
(*****************************************************************************)

(* a key's thing numbers: a card and a skull of each colour *)
and has_key (t : t) (colour : string) : bool =
  let cards = match colour with "blue" -> [ 5; 40 ] | "yellow" -> [ 6; 39 ] | _ -> [ 13; 38 ] in
  List.exists (fun (k : int) -> List.mem k t.player.keys) cards

(* EV_DoDoor, EV_VerticalDoor: [manual] the line's back sector, else
 * the line's tagged sectors *)
and do_door (t : t) (l : Level.line) (kind : door_kind) (speed : float) (manual : bool) : unit =
  let start (s : Level.sector) : unit =
    match busy t s with
    | Some { what = Door d; _ } when manual ->
        (* (used again: it turns back) *)
        if kind = Raise then d.ddir <- (if d.ddir = -1 then 1 else -1)
    | Some _ -> ()
    | None ->
        let dir = if kind = Close then -1 else 1 in
        add t (Door { dsector = s; dkind = kind; ddir = dir; topheight = lowest_ceiling t s -. 4.; dspeed = speed; dcount = 0 }) in
  if manual then Option.iter start (Level.line_sector t.level l 1) else List.iter start (tagged t l.tag)

and do_plat (t : t) (l : Level.line) (speed : float) : unit =
  List.iter
    (fun (s : Level.sector) ->
      if busy t s = None then
        add t (Plat { psector = s; low = Float.min (lowest_floor t s) s.floor; high = s.floor; pspeed = speed; status = -1; pcount = 0 }))
    (tagged t l.tag)

and do_floor_lowest (t : t) (l : Level.line) : unit =
  List.iter
    (fun (s : Level.sector) -> if busy t s = None then add t (Floor { fsector = s; dest = lowest_floor t s; fspeed = 1.; fdir = -1 }))
    (tagged t l.tag)

(* P_ChangeSwitchTexture: the front side's SW1 made SW2; back after a
 * second when the switch can be used again *)
and switch (t : t) (l : Level.line) (again : bool) : unit =
  let side = t.level.sides.(l.front) in
  let turn (where : int) (get : Level.side -> int) (set : int -> unit) : unit =
    match Textures.switch_of t.textures (get side) with
    | Some other ->
        if again then add t (Button { bside = side; where; texture = get side; btimer = 35 });
        set other
    | None -> () in
  turn 0 (fun (s : Level.side) -> s.top) (fun (k : int) -> side.top <- k);
  turn 1 (fun (s : Level.side) -> s.middle) (fun (k : int) -> side.middle <- k);
  turn 2 (fun (s : Level.side) -> s.bottom) (fun (k : int) -> side.bottom <- k)

(* P_UseSpecialLine and P_CrossSpecialLine together: a line's special,
 * [used] or crossed; a W1 or S1 one is then no more. The doors' speed
 * is 2 a tic (VDOORSPEED), the blazing ones' 8; the lifts' 4 *)
and line_special (t : t) (l : Level.line) (used : bool) : unit =
  let once () : unit = l.special <- 0 in
  let locked (colour : string) (f : unit -> unit) : unit =
    if has_key t colour then f () else say t (Printf.sprintf "You need a %s key to open this door" colour) in
  match (used, l.special) with
  (* DR, D1: the door the line is on *)
  | true, 1 -> do_door t l Raise 2. true
  | true, 26 -> locked "blue" (fun () -> do_door t l Raise 2. true)
  | true, 27 -> locked "yellow" (fun () -> do_door t l Raise 2. true)
  | true, 28 -> locked "red" (fun () -> do_door t l Raise 2. true)
  | true, 117 -> do_door t l Raise 8. true
  | true, 31 -> do_door t l Open 2. true; once ()
  | true, 32 -> locked "blue" (fun () -> do_door t l Open 2. true; once ())
  | true, 33 -> locked "red" (fun () -> do_door t l Open 2. true; once ())
  | true, 34 -> locked "yellow" (fun () -> do_door t l Open 2. true; once ())
  | true, 118 -> do_door t l Open 8. true; once ()
  (* switches: S1 once, SR again *)
  | true, 103 -> do_door t l Open 2. false; switch t l false; once ()
  | true, 63 -> do_door t l Raise 2. false; switch t l true
  | true, 62 -> do_plat t l 4.; switch t l true
  | true, 21 -> do_plat t l 4.; switch t l false; once ()
  | true, 123 -> do_plat t l 8.; switch t l true
  | true, 23 -> do_floor_lowest t l; switch t l false; once ()
  | true, (11 | 51) -> switch t l false; t.exited <- true
  (* walked over: W1 once, WR again *)
  | false, 2 -> do_door t l Open 2. false; once ()
  | false, 3 -> do_door t l Close 2. false; once ()
  | false, 4 -> do_door t l Raise 2. false; once ()
  | false, 86 -> do_door t l Open 2. false
  | false, 90 -> do_door t l Raise 2. false
  | false, 10 -> do_plat t l 4.; once ()
  | false, 88 -> do_plat t l 4.
  | false, 120 -> do_plat t l 8.
  | false, 38 -> do_floor_lowest t l; once ()
  | false, (52 | 124) -> t.exited <- true
  | _ -> ()

(* P_UseLines, PTR_UseTraverse: the lines across the 64 ahead, nearest
 * first; the first with a special is used, from its front; one that
 * closes the way ends it *)
let use_lines (t : t) : unit =
  let p = t.player in
  let x2 = p.x +. (userange *. cos p.angle) and y2 = p.y +. (userange *. sin p.angle) in
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
  let rec go (l : (float * Level.line) list) : unit =
    match l with
    | [] -> ()
    | (_, line) :: rest ->
        if line.special <> 0 then (if Level.point_on_line_side p.x p.y line = 0 then line_special t line true)
        else
          match (Level.line_sector t.level line 0, Level.line_sector t.level line 1) with
          | Some f, Some b when Float.min f.ceiling b.ceiling -. Float.max f.floor b.floor > 0. -> go rest
          | _ -> () in
  go sorted

(*****************************************************************************)
(* The thinkers *)
(*****************************************************************************)

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

type moved = Ok | Crushed | Pastdest

(* T_MovePlane: a sector's floor (or ceiling) [speed] toward [dest];
 * back where it was if the player is in the way *)
let move_plane (t : t) (s : Level.sector) (speed : float) (dest : float) (floor : bool) (dir : int) : moved =
  let get () : float = if floor then s.floor else s.ceiling in
  let set (v : float) : unit = if floor then s.floor <- v else s.ceiling <- v in
  let last = get () in
  let past = if dir < 0 then last -. speed < dest else last +. speed > dest in
  set (if past then dest else if dir < 0 then last -. speed else last +. speed);
  (* (a floor going down, a ceiling going up never crush) *)
  if (floor && dir > 0) || ((not floor) && dir < 0) then begin
    if not (change_sector t) then begin
      set last;
      ignore (change_sector t);
      Crushed
    end
    else if past then Pastdest
    else Ok
  end
  else begin
    ignore (change_sector t);
    if past then Pastdest else Ok
  end

let think (t : t) (th : thinker) : unit =
  match th.what with
  | Door d -> (
      match d.ddir with
      | 0 ->
          d.dcount <- d.dcount - 1;
          if d.dcount <= 0 then d.ddir <- -1
      | 1 -> (
          match move_plane t d.dsector d.dspeed d.topheight false 1 with
          | Pastdest -> if d.dkind = Raise then begin d.ddir <- 0; d.dcount <- 150 end else th.alive <- false
          | _ -> ())
      | _ -> (
          match move_plane t d.dsector d.dspeed d.dsector.floor false (-1) with
          | Pastdest -> th.alive <- false
          (* (the player under it: back up) *)
          | Crushed -> d.ddir <- 1
          | Ok -> ()))
  | Plat p -> (
      match p.status with
      | 1 -> (
          match move_plane t p.psector p.pspeed p.high true 1 with
          | Crushed -> p.pcount <- 105; p.status <- -1
          | Pastdest -> th.alive <- false
          | Ok -> ())
      | -1 -> ( match move_plane t p.psector p.pspeed p.low true (-1) with Pastdest -> p.pcount <- 105; p.status <- 0 | _ -> ())
      | _ ->
          p.pcount <- p.pcount - 1;
          if p.pcount <= 0 then p.status <- (if p.psector.floor = p.low then 1 else -1))
  | Floor f -> ( match move_plane t f.fsector f.fspeed f.dest true f.fdir with Pastdest -> th.alive <- false | _ -> ())
  | Light l -> (
      let s = l.lsector in
      match l.lkind with
      | Flash ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then
            if s.light = l.maxlight then begin s.light <- l.minlight; l.lcount <- (random () land l.darktime) + 1 end
            else begin s.light <- l.maxlight; l.lcount <- (random () land l.brighttime) + 1 end
      | Strobe ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then
            if s.light = l.minlight then begin s.light <- l.maxlight; l.lcount <- l.brighttime end
            else begin s.light <- l.minlight; l.lcount <- l.darktime end
      | Glow ->
          if l.gdir < 0 then begin
            s.light <- s.light - 8;
            if s.light <= l.minlight then begin s.light <- s.light + 8; l.gdir <- 1 end
          end
          else begin
            s.light <- s.light + 8;
            if s.light >= l.maxlight then begin s.light <- s.light - 8; l.gdir <- -1 end
          end
      | Flicker ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then begin
            let amount = (random () land 3) * 16 in
            s.light <- (if s.light - amount < l.minlight then l.minlight else l.maxlight - amount);
            l.lcount <- 4
          end)
  | Button b ->
      b.btimer <- b.btimer - 1;
      if b.btimer <= 0 then begin
        (match b.where with 0 -> b.bside.top <- b.texture | 1 -> b.bside.middle <- b.texture | _ -> b.bside.bottom <- b.texture);
        th.alive <- false
      end

(* P_SpawnSpecials: the sectors' lights *)
let spawn_lights (t : t) : unit =
  Array.iter
    (fun (s : Level.sector) ->
      let light (kind : light_kind) (minl : int) (maxl : int) (dark : int) (bright : int) (count : int) : unit =
        add t (Light { lsector = s; lkind = kind; minlight = minl; maxlight = maxl; darktime = dark; brighttime = bright; lcount = count; gdir = -1 }) in
      let lowest = min_light t s s.light in
      (* (P_SpawnStrobeFlash: no darker neighbour, then black) *)
      let strobe (dark : int) (sync : bool) : unit =
        light Strobe (if lowest = s.light then 0 else lowest) s.light dark 5 (if sync then 1 else (random () land 7) + 1) in
      match s.special with
      | 1 -> light Flash lowest s.light 7 64 ((random () land 64) + 1)
      | 2 | 4 -> strobe 15 false
      | 3 -> strobe 35 false
      | 8 -> light Glow lowest s.light 0 0 0
      | 12 -> strobe 35 true
      | 13 -> strobe 15 true
      | 17 -> light Flicker (lowest + 16) s.light 0 0 4
      | _ -> ())
    t.level.sectors

let secrets_total (t : t) : int = Array.fold_left (fun (n : int) (s : Level.sector) -> if s.special = 9 then n + 1 else n) t.secrets t.level.sectors

let create (level : Level.t) (textures : Textures.t) (monsters : bool) : t =
  let start = match List.find_opt (fun (th : Level.thing) -> th.kind = 1) (Array.to_list level.things) with Some s -> s | None -> failwith (level.name ^ ": no player's start") in
  let s = Level.sector_at level start.tx start.ty in
  let player =
    { x = start.tx; y = start.ty; z = s.floor; angle = start.tangle; momx = 0.; momy = 0.; momz = 0.; floorz = s.floor; ceilingz = s.ceiling;
      viewheight; deltaviewheight = 0.; viewz = s.floor +. viewheight; bob = 0.; turnheld = 0; keys = [] } in
  let things = Things.spawn level monsters in
  let by_sector = Array.make (Array.length level.sectors) [] in
  List.iter (fun (m : Things.mobj) -> by_sector.(m.sector.index) <- m :: by_sector.(m.sector.index)) things;
  let t = { level; textures; player; things; by_sector; tic = 0; thinkers = []; message = ""; message_tics = 0; exited = false; secrets = 0 } in
  ignore (change_sector t);
  spawn_lights t;
  t

(*****************************************************************************)
(* The player *)
(*****************************************************************************)

let place (t : t) (x : float) (y : float) (angle : float) : unit =
  let p = t.player in
  p.x <- x;
  p.y <- y;
  p.angle <- angle;
  p.momx <- 0.;
  p.momy <- 0.;
  ignore (change_sector t);
  p.z <- p.floorz;
  p.viewheight <- viewheight;
  p.viewz <- p.z +. viewheight

(* the things picked up (P_TouchSpecialThing): only the keys, here;
 * an item's box touches the player's (P_CheckPosition's things) *)
let pick_up (t : t) : unit =
  let p = t.player in
  List.iter
    (fun (m : Things.mobj) ->
      let k = m.kind.doomednum in
      if m.alive && List.mem k [ 5; 6; 13; 38; 39; 40 ] && Float.abs (m.mx -. p.x) < radius +. m.kind.radius
         && Float.abs (m.my -. p.y) < radius +. m.kind.radius
      then begin
        m.alive <- false;
        p.keys <- k :: p.keys;
        let colour = match k with 5 | 40 -> "blue" | 6 | 39 -> "yellow" | _ -> "red" in
        say t (Printf.sprintf "Picked up a %s %s." colour (if k >= 38 then "skull key" else "keycard"))
      end)
    t.things

(* P_XYMovement: the momentum moved, half at a time when large; along
 * the wall when it stops it (P_SlideMove's purpose, by the projection
 * of the momentum on the wall, then each axis alone) *)
let xy_movement (t : t) (moving : bool) : unit =
  let p = t.player in
  let clamp (v : float) : float = Float.max (-.maxmove) (Float.min maxmove v) in
  p.momx <- clamp p.momx;
  p.momy <- clamp p.momy;
  let steps = if Float.abs p.momx > maxmove /. 2. || Float.abs p.momy > maxmove /. 2. then 2 else 1 in
  let n = float steps in
  for _n = 1 to steps do
    let mx = p.momx /. n and my = p.momy /. n in
    match try_move t (p.x +. mx) (p.y +. my) with
    | true, _ -> ()
    | false, blocker ->
        let slid =
          match blocker with
          | Some l ->
              let ex = l.v2.x -. l.v1.x and ey = l.v2.y -. l.v1.y in
              let len2 = (ex *. ex) +. (ey *. ey) in
              let k = ((mx *. ex) +. (my *. ey)) /. len2 in
              fst (try_move t (p.x +. (k *. ex)) (p.y +. (k *. ey)))
          | None -> false in
        if not slid then
          if not (fst (try_move t (p.x +. mx) p.y)) then
            if not (fst (try_move t p.x (p.y +. my))) then begin p.momx <- 0.; p.momy <- 0. end
  done;
  (* (no friction in the air) *)
  if p.z <= p.floorz then
    if Float.abs p.momx < stopspeed && Float.abs p.momy < stopspeed && not moving then begin p.momx <- 0.; p.momy <- 0. end
    else begin
      p.momx <- p.momx *. friction;
      p.momy <- p.momy *. friction
    end

(* P_ZMovement: a step up climbed by the feet at once, by the eye
 * smoothly; a fall by gravity, 1 a tic a tic *)
let z_movement (t : t) : unit =
  let p = t.player in
  if p.z < p.floorz then begin
    p.viewheight <- p.viewheight -. (p.floorz -. p.z);
    p.deltaviewheight <- (viewheight -. p.viewheight) /. 8.
  end;
  p.z <- p.z +. p.momz;
  if p.z <= p.floorz then begin
    if p.momz < 0. then begin
      if p.momz < -8. then p.deltaviewheight <- p.momz /. 8.;
      p.momz <- 0.
    end;
    p.z <- p.floorz
  end
  else p.momz <- (if p.momz = 0. then -2. else p.momz -. 1.);
  if p.z +. height > p.ceilingz then begin
    if p.momz > 0. then p.momz <- 0.;
    p.z <- p.ceilingz -. height
  end

(* P_CalcHeight: the eye *)
let calc_height (t : t) : unit =
  let p = t.player in
  p.bob <- Float.min maxbob (((p.momx *. p.momx) +. (p.momy *. p.momy)) /. 4.);
  if p.z > p.floorz then p.viewz <- Float.min (p.ceilingz -. 4.) (p.z +. viewheight)
  else begin
    let bob = p.bob /. 2. *. sin (2. *. pi *. float t.tic /. 20.) in
    p.viewheight <- p.viewheight +. p.deltaviewheight;
    if p.viewheight > viewheight then begin p.viewheight <- viewheight; p.deltaviewheight <- 0. end;
    if p.viewheight < viewheight /. 2. then begin
      p.viewheight <- viewheight /. 2.;
      if p.deltaviewheight <= 0. then p.deltaviewheight <- 1. /. 65536.
    end;
    if p.deltaviewheight <> 0. then p.deltaviewheight <- p.deltaviewheight +. 0.25;
    p.viewz <- Float.min (p.ceilingz -. 4.) (p.z +. p.viewheight +. bob)
  end

let use_down = ref false

let tic (t : t) (cmd : cmd) : unit =
  let p = t.player in
  t.tic <- t.tic + 1;
  (* P_PlayerThink, P_MovePlayer *)
  p.angle <- p.angle +. (float cmd.turn *. 2. *. pi /. 65536.);
  let onground = p.z <= p.floorz in
  if onground then begin
    let thrust (a : float) (move : int) : unit =
      let m = float move /. 32. in
      p.momx <- p.momx +. (m *. cos a);
      p.momy <- p.momy +. (m *. sin a) in
    if cmd.forward <> 0 then thrust p.angle cmd.forward;
    if cmd.side <> 0 then thrust (p.angle -. (pi /. 2.)) cmd.side
  end;
  calc_height t;
  let s = Level.sector_at t.level p.x p.y in
  (* P_PlayerInSpecialSector: a secret found *)
  if s.special = 9 && p.z = s.floor then begin s.special <- 0; t.secrets <- t.secrets + 1 end;
  if cmd.use && not !use_down then use_lines t;
  use_down := cmd.use;
  (* P_RunThinkers: the player's body first, then the others *)
  if p.momx <> 0. || p.momy <> 0. then xy_movement t (cmd.forward <> 0 || cmd.side <> 0);
  if p.z <> p.floorz || p.momz <> 0. then z_movement t;
  pick_up t;
  List.iter (fun (th : thinker) -> if th.alive then think t th) t.thinkers;
  t.thinkers <- List.filter (fun (th : thinker) -> th.alive) t.thinkers;
  (* P_UpdateSpecials *)
  Textures.animate t.textures t.tic;
  if t.message_tics > 0 then t.message_tics <- t.message_tics - 1

type keys = { up : bool; down : bool; left : bool; right : bool; run : bool; strafe_left : bool; strafe_right : bool; use_key : bool }

(* G_BuildTiccmd *)
let command (p : player) (k : keys) : cmd =
  if k.left || k.right then p.turnheld <- p.turnheld + 1 else p.turnheld <- 0;
  let turnspeed = if p.turnheld < 6 then 320 else if k.run then 1280 else 640 in
  let forwardmove = if k.run then 50 else 25 and sidemove = if k.run then 40 else 24 in
  { forward = (if k.up then forwardmove else 0) - if k.down then forwardmove else 0;
    side = (if k.strafe_right then sidemove else 0) - if k.strafe_left then sidemove else 0;
    turn = (if k.left then turnspeed else 0) - if k.right then turnspeed else 0;
    use = k.use_key }
