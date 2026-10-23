(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Enemy.mli *)

open World

let meleerange = 64.
let missilerange = 32. *. 64.

(* (a target that is shootable still) *)
let alive (t : t) (who : Things.target) : bool =
  match who with
  | Things.Nobody -> false
  | Things.The_player -> t.player.health > 0
  | Things.Thing m -> m.alive && m.flags land Info.shootable <> 0

let sees (t : t) (m : Things.mobj) (who : Things.target) : bool =
  let h = Things.height m in
  let x, y, z, th = Inter.where t who in
  Collision.check_sight t m.mx m.my (m.mz +. h -. (h /. 4.)) x y z th

let info (m : Things.mobj) : Info.mobjinfo =
  match m.actor with Some i -> i | None -> failwith "Enemy: not an actor"

let angle_to (t : t) (m : Things.mobj) (who : Things.target) : float =
  let x, y, _, _ = Inter.where t who in
  Float.atan2 (y -. m.my) (x -. m.mx)

let distance_to (t : t) (m : Things.mobj) (who : Things.target) : float =
  let x, y, _, _ = Inter.where t who in
  approx_distance (x -. m.mx) (y -. m.my)

(*****************************************************************************)
(* Hearing *)
(*****************************************************************************)

(* P_RecursiveSound: a sector, then its neighbours through the open
 * two-sided lines, a sound-blocking one (ML_SOUNDBLOCK, 64) crossed
 * once; [blocks] how many it crossed to get there *)
let noise_alert (t : t) : unit =
  let traversed = Array.make (Array.length t.level.sectors) (-1) in
  let rec flood (s : Level.sector) (blocks : int) : unit =
    if traversed.(s.index) < 0 || traversed.(s.index) > blocks + 1 then begin
      traversed.(s.index) <- blocks + 1;
      t.heard.(s.index) <- true;
      List.iter
        (fun (k : int) ->
          let l = t.level.lines.(k) in
          match
            ( Collision.opening t l,
              Level.line_sector t.level l 0,
              Level.line_sector t.level l 1 )
          with
          | Some (ob, ot), Some f, Some b when ot > ob ->
              let other = if f == s then b else f in
              if l.flags land 64 <> 0 then (if blocks = 0 then flood other 1)
              else flood other blocks
          | _ -> ())
        s.lines
    end
  in
  flood (Level.sector_at t.level t.player.x t.player.y) 0

(*****************************************************************************)
(* Moving *)
(*****************************************************************************)

(* the eight directions (dirtype_t): east, north-east, ... south-east;
 * 8 none. A diagonal's step is 47000/65536 of a straight one *)
let nodir = 8
let xspeed = [| 1.; 0.7172; 0.; -0.7172; -1.; -0.7172; 0.; 0.7172 |]
let yspeed = [| 0.; 0.7172; 1.; 0.7172; 0.; -0.7172; -1.; -0.7172 |]
let opposite (d : int) : int = if d = nodir then nodir else (d + 4) mod 8

(* P_Move: a step of its speed its way; blocked by a door, the door
 * opened (a monster opens the doors anyone can, DR's special 1, not a
 * secret one: ML_SECRET, 32) *)
let move (t : t) (m : Things.mobj) : bool =
  if m.movedir = nodir then false
  else begin
    let speed = (info m).speed in
    let x = m.mx +. (speed *. xspeed.(m.movedir))
    and y = m.my +. (speed *. yspeed.(m.movedir)) in
    let ok, pos = Collision.try_move_thing t m x y in
    if ok then begin
      m.mz <- m.floorz;
      true
    end
    else begin
      m.movedir <- nodir;
      let doors =
        List.filter
          (fun (l : Level.line) -> l.special = 1 && l.flags land 32 = 0)
          pos.special_lines
      in
      List.iter (fun (l : Level.line) -> Specials.line_special t l true) doors;
      doors <> []
    end
  end

(* P_TryWalk *)
let try_walk (t : t) (m : Things.mobj) : bool =
  if move t m then begin
    m.movecount <- Info.p_random () land 15;
    true
  end
  else false

(* P_NewChaseDir *)
let new_chase_dir (t : t) (m : Things.mobj) : unit =
  let olddir = m.movedir in
  let turnaround = opposite olddir in
  let tx, ty, _, _ = Inter.where t m.target in
  let dx = tx -. m.mx and dy = ty -. m.my in
  let d1 = if dx > 10. then 0 else if dx < -10. then 4 else nodir in
  let d2 = if dy < -10. then 6 else if dy > 10. then 2 else nodir in
  let walk (d : int) : bool =
    m.movedir <- d;
    try_walk t m
  in
  (* (the diagonal: north-west, north-east, south-west, south-east) *)
  let diags = [| 3; 1; 5; 7 |] in
  let diag =
    diags.(((if dy < 0. then 1 else 0) lsl 1) + if dx > 0. then 1 else 0)
  in
  if d1 <> nodir && d2 <> nodir && diag <> turnaround && walk diag then ()
  else begin
    let d1, d2 =
      if Info.p_random () > 200 || Float.abs dy > Float.abs dx then (d2, d1)
      else (d1, d2)
    in
    let d1 = if d1 = turnaround then nodir else d1
    and d2 = if d2 = turnaround then nodir else d2 in
    if d1 <> nodir && walk d1 then ()
    else if d2 <> nodir && walk d2 then ()
    else if olddir <> nodir && walk olddir then ()
    else begin
      let order =
        if Info.p_random () land 1 = 1 then [ 0; 1; 2; 3; 4; 5; 6; 7 ]
        else [ 7; 6; 5; 4; 3; 2; 1; 0 ]
      in
      if List.exists (fun (d : int) -> d <> turnaround && walk d) order then ()
      else if turnaround <> nodir && walk turnaround then ()
      else m.movedir <- nodir
    end
  end

(*****************************************************************************)
(* Looking, chasing *)
(*****************************************************************************)

(* P_LookForPlayers: the player, seen; [allaround] or in front *)
let look_for_player (t : t) (m : Things.mobj) (allaround : bool) : bool =
  if t.player.health <= 0 || not (sees t m Things.The_player) then false
  else begin
    let a = View.norm (angle_to t m Things.The_player -. m.mangle) in
    let behind = a > pi /. 2. && a < 3. *. pi /. 2. in
    if
      (not allaround) && behind
      && distance_to t m Things.The_player > meleerange
    then false
    else begin
      m.target <- Things.The_player;
      true
    end
  end

let look (t : t) (m : Things.mobj) : unit =
  let i = info m in
  m.threshold <- 0;
  let heard = t.heard.(m.sector.index) && t.player.health > 0 in
  let woke =
    if heard && (m.flags land Info.ambush = 0 || sees t m Things.The_player)
    then begin
      m.target <- Things.The_player;
      true
    end
    else look_for_player t m false
  in
  if woke then begin
    let sound =
      match i.seesound with
      | "posit1" | "posit2" | "posit3" ->
          Printf.sprintf "posit%d" (1 + (Info.p_random () mod 3))
      | "bgsit1" | "bgsit2" ->
          Printf.sprintf "bgsit%d" (1 + (Info.p_random () mod 2))
      | s -> s
    in
    start_sound t (Some (m.mx, m.my)) sound;
    ignore (Mobj.set_state t m i.seestate)
  end

(* P_CheckMeleeRange *)
let check_melee_range (t : t) (m : Things.mobj) : bool =
  let r =
    match m.target with Things.Thing o -> Things.radius o | _ -> radius
  in
  alive t m.target
  && distance_to t m m.target < meleerange -. 20. +. r
  && sees t m m.target

(* P_CheckMissileRange: the further, the less likely *)
let check_missile_range (t : t) (m : Things.mobj) : bool =
  if not (sees t m m.target) then false
  else if m.flags land Info.justhit <> 0 then begin
    m.flags <- m.flags land lnot Info.justhit;
    true
  end
  else if m.reactiontime > 0 then false
  else begin
    let d = distance_to t m m.target -. 64. in
    let d = if (info m).meleestate = "" then d -. 128. else d in
    let d = Float.min 200. d in
    not (float (Info.p_random ()) < d)
  end

(* the way the monster turns to face its direction, an eighth of a turn a
 * chase (A_Chase's angle snapped to the eighths) *)
let turn (m : Things.mobj) : unit =
  if m.movedir < 8 then begin
    let eighth = pi /. 4. in
    let a = Float.floor (View.norm m.mangle /. eighth) *. eighth in
    let d = View.norm (a -. (float m.movedir *. eighth)) in
    let d = if d > pi then d -. (2. *. pi) else d in
    m.mangle <-
      (if d > 0.001 then a -. eighth else if d < -0.001 then a +. eighth else a)
  end

let chase (t : t) (m : Things.mobj) : unit =
  let i = info m in
  if m.reactiontime > 0 then m.reactiontime <- m.reactiontime - 1;
  if m.threshold > 0 then
    if not (alive t m.target) then m.threshold <- 0
    else m.threshold <- m.threshold - 1;
  turn m;
  if not (alive t m.target) then begin
    if not (look_for_player t m true) then
      ignore (Mobj.set_state t m i.spawnstate)
  end
  else if m.flags land Info.justattacked <> 0 then begin
    m.flags <- m.flags land lnot Info.justattacked;
    new_chase_dir t m
  end
  else if i.meleestate <> "" && check_melee_range t m then begin
    start_sound t (Some (m.mx, m.my)) i.attacksound;
    ignore (Mobj.set_state t m i.meleestate)
  end
  else if i.missilestate <> "" && m.movecount = 0 && check_missile_range t m
  then begin
    ignore (Mobj.set_state t m i.missilestate);
    m.flags <- m.flags lor Info.justattacked
  end
  else begin
    (* (the playground's way, for a monster that does not see the
     * player: Ways) *)
    let way =
      if t.ai = Ways && m.target = Things.The_player then begin
        if sees t m m.target then begin
          m.seen_for <- m.seen_for + m.stics;
          None
        end
        else begin
          m.seen_for <- 0;
          Ways.direction t m
        end
      end
      else None
    in
    match way with
    | Some d ->
        m.movedir <- d;
        if not (move t m) then new_chase_dir t m
    | None ->
        m.movecount <- m.movecount - 1;
        if m.movecount < 0 || not (move t m) then new_chase_dir t m
  end;
  if m.alive && i.activesound <> "" && Info.p_random () < 3 then
    start_sound t (Some (m.mx, m.my)) i.activesound

(*****************************************************************************)
(* Attacks *)
(*****************************************************************************)

let face_target (t : t) (m : Things.mobj) : unit =
  if m.target <> Things.Nobody then begin
    m.flags <- m.flags land lnot Info.ambush;
    m.mangle <- angle_to t m m.target
  end

(* a bullet's spread: id's P_Random2 () << 20, at most a 22nd of a turn
 * either way; the playground's aim error with ai=ways *)
let spread (t : t) (m : Things.mobj) : float =
  if t.ai = Ways then Ways.aim_error m
  else float (Info.p_random2 ()) *. 2. *. pi /. 4096.

(* the middle of a thing, where it shoots from (id's shootz: half up and
 * 8 above) *)
let shootz (m : Things.mobj) : float = m.mz +. (Things.height m /. 2.) +. 8.

let bullets (t : t) (m : Things.mobj) (n : int) (sound : string) : unit =
  if m.target <> Things.Nobody then begin
    face_target t m;
    let slope, _ =
      Inter.aim t (Things.Thing m) m.mx m.my (shootz m) m.mangle missilerange
    in
    start_sound t (Some (m.mx, m.my)) sound;
    for _i = 1 to n do
      let a = m.mangle +. spread t m in
      let damage = ((Info.p_random () mod 5) + 1) * 3 in
      Inter.line_attack t (Things.Thing m) m.mx m.my (shootz m) a missilerange
        slope damage
    done
  end

(* P_SpawnMissile: from 32 up, at the target, its speed, rising or
 * falling to it; moved half a step at once, and exploding there if it
 * cannot (P_CheckMissileSpawn) *)
let spawn_missile (t : t) (m : Things.mobj) (i : Info.mobjinfo) : unit =
  let mo = Mobj.spawn t i m.mx m.my (m.mz +. 32.) in
  start_sound t (Some (m.mx, m.my)) i.seesound;
  mo.target <- Things.Thing m;
  let a = angle_to t m m.target in
  mo.mangle <- a;
  mo.momx <- i.speed *. View.fcos a;
  mo.momy <- i.speed *. View.fsin a;
  let _, _, tz, _ = Inter.where t m.target in
  let dist = Float.max 1. (distance_to t m m.target /. i.speed) in
  mo.momz <- (tz -. m.mz) /. dist;
  mo.stics <- max 1 (mo.stics - (Info.p_random () land 3));
  let ok, _ =
    Collision.try_move_thing t mo
      (mo.mx +. (mo.momx /. 2.))
      (mo.my +. (mo.momy /. 2.))
  in
  if not ok then Mobj.explode_missile t mo

let act (t : t) (m : Things.mobj) (a : Info.action) : unit =
  match a with
  | Info.Look -> look t m
  | Info.Chase -> chase t m
  | Info.Face_target -> face_target t m
  | Info.Pos_attack -> bullets t m 1 "pistol"
  | Info.SPos_attack -> bullets t m 3 "shotgn"
  | Info.Troop_attack ->
      if m.target <> Things.Nobody then begin
        face_target t m;
        if check_melee_range t m then begin
          start_sound t (Some (m.mx, m.my)) "claw";
          Inter.damage t m.target (m.mx, m.my) (Things.Thing m)
            (((Info.p_random () mod 8) + 1) * 3)
        end
        else spawn_missile t m Info.troopshot
      end
  | Info.Sarg_attack ->
      if m.target <> Things.Nobody then begin
        face_target t m;
        if check_melee_range t m then
          Inter.damage t m.target (m.mx, m.my) (Things.Thing m)
            (((Info.p_random () mod 10) + 1) * 4)
      end
  | Info.Pain -> start_sound t (Some (m.mx, m.my)) (info m).painsound
  | Info.Scream ->
      let sound =
        match (info m).deathsound with
        | "podth1" | "podth2" | "podth3" ->
            Printf.sprintf "podth%d" (1 + (Info.p_random () mod 3))
        | "bgdth1" | "bgdth2" ->
            Printf.sprintf "bgdth%d" (1 + (Info.p_random () mod 2))
        | s -> s
      in
      start_sound t (Some (m.mx, m.my)) sound
  | Info.XScream -> start_sound t (Some (m.mx, m.my)) "slop"
  | Info.Fall -> m.flags <- m.flags land lnot Info.solid
  | Info.Explode -> Inter.radius_attack t m m.target 128
  | _ -> ()

let () = Mobj.act := act
