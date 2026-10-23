(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Play.mli *)

open World

type cmd = {
  forward : int;
  side : int;
  turn : int;
  use : bool;
  attack : bool;
  change : Info.weapon option;
}

let secrets_total (t : t) : int = Array.fold_left (fun (n : int) (s : Level.sector) -> if s.special = 9 then n + 1 else n) t.secrets t.level.sectors

let psprite () : psprite = { pstate = None; ptics = 0; sx = 1.; sy = 128. }

let create (level : Level.t) (textures : Textures.t) (monsters : bool)
    (ai : ai) : t =
  let start = match List.find_opt (fun (th : Level.thing) -> th.kind = 1) (Array.to_list level.things) with Some s -> s | None -> failwith (level.name ^ ": no player's start") in
  let s = Level.sector_at level start.tx start.ty in
  let player =
    { x = start.tx; y = start.ty; z = s.floor; angle = start.tangle; momx = 0.; momy = 0.; momz = 0.; floorz = s.floor; ceilingz = s.ceiling;
      viewheight; deltaviewheight = 0.; viewz = s.floor +. viewheight; bob = 0.; turnheld = 0; keys = [];
      health = 100; armor = 0; weapons = [ Info.Fist; Info.Pistol ];
      readyweapon = Info.Pistol; pendingweapon = None; clips = 50; shells = 0;
      weapon_sp = psprite (); flash_sp = psprite (); attackdown = false;
      refire = 0; extralight = 0; damagecount = 0; bonuscount = 0;
      attacker = None } in
  let things = Things.spawn level monsters in
  let by_sector = Array.make (Array.length level.sectors) [] in
  List.iter (fun (m : Things.mobj) -> by_sector.(m.sector.index) <- m :: by_sector.(m.sector.index)) things;
  let t =
    { level; textures; player; things; by_sector; tic = 0; thinkers = [];
      message = ""; message_tics = 0; exited = false; secrets = 0; kills = 0;
      sounds = []; ai; heard = Array.make (Array.length level.sectors) false;
      reborn = false } in
  ignore (Collision.change_sector t);
  Specials.spawn_lights t;
  Weapons.setup t;
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
  ignore (Collision.change_sector t);
  p.z <- p.floorz;
  p.viewheight <- viewheight;
  p.viewz <- p.z +. viewheight

(* the move tried, the lines crossed doing what they do *)
let try_move (t : t) (x : float) (y : float) : bool * Level.line option =
  Collision.try_move (fun (l : Level.line) -> Specials.line_special t l false) t x y

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
    let bob = p.bob /. 2. *. View.fsin (2. *. pi *. float t.tic /. 20.) in
    p.viewheight <- p.viewheight +. p.deltaviewheight;
    if p.viewheight > viewheight then begin p.viewheight <- viewheight; p.deltaviewheight <- 0. end;
    if p.viewheight < viewheight /. 2. then begin
      p.viewheight <- viewheight /. 2.;
      if p.deltaviewheight <= 0. then p.deltaviewheight <- 1. /. 65536.
    end;
    if p.deltaviewheight <> 0. then p.deltaviewheight <- p.deltaviewheight +. 0.25;
    p.viewz <- Float.min (p.ceilingz -. 4.) (p.z +. p.viewheight +. bob)
  end

(* P_DeathThink: the eye down to 6 above the floor, a unit a tic,
 * turned to the killer; use, and the level again *)
let death_think (t : t) (cmd : cmd) : unit =
  let p = t.player in
  if p.viewheight > 6. then p.viewheight <- p.viewheight -. 1.;
  if p.viewheight < 6. then p.viewheight <- 6.;
  p.deltaviewheight <- 0.;
  p.viewz <- p.z +. p.viewheight;
  (match p.attacker with
  | Some m when m.alive ->
      let a = Float.atan2 (m.my -. p.y) (m.mx -. p.x) in
      let d = View.norm (a -. p.angle) in
      if d < pi /. 32. || d > 2. *. pi -. (pi /. 32.) then p.angle <- a
      else p.angle <- p.angle +. (if d < pi then pi /. 32. else -.(pi /. 32.))
  | _ -> ());
  if cmd.use then t.reborn <- true

let use_down = ref false

(* P_PlayerThink, P_MovePlayer: the turn, the thrust, the eye, a secret
 * found, a line used *)
let move_player (t : t) (cmd : cmd) : unit =
  let p = t.player in
  p.angle <- p.angle +. (float cmd.turn *. 2. *. pi /. 65536.);
  let onground = p.z <= p.floorz in
  if onground then begin
    let thrust (a : float) (move : int) : unit =
      let m = float move /. 32. in
      p.momx <- p.momx +. (m *. View.fcos a);
      p.momy <- p.momy +. (m *. View.fsin a) in
    if cmd.forward <> 0 then thrust p.angle cmd.forward;
    if cmd.side <> 0 then thrust (p.angle -. (pi /. 2.)) cmd.side
  end;
  calc_height t;
  let s = Level.sector_at t.level p.x p.y in
  (* P_PlayerInSpecialSector: a secret found *)
  if s.special = 9 && p.z = s.floor then begin s.special <- 0; t.secrets <- t.secrets + 1 end;
  if cmd.use && not !use_down then Option.iter (fun (l : Level.line) -> Specials.line_special t l true) (Collision.use_target t);
  use_down := cmd.use

let tic (t : t) (cmd : cmd) : unit =
  let p = t.player in
  t.tic <- t.tic + 1;
  if p.health <= 0 then death_think t cmd else move_player t cmd;
  Weapons.tic t cmd.attack cmd.change;
  (* P_RunThinkers: the player's body first, then the others *)
  if p.momx <> 0. || p.momy <> 0. then xy_movement t (cmd.forward <> 0 || cmd.side <> 0);
  if p.z <> p.floorz || p.momz <> 0. then z_movement t;
  Inter.touch_specials t;
  (* the things that act (P_MobjThinker); those made during it from the
   * next tic *)
  List.iter
    (fun (m : Things.mobj) ->
      if m.alive && m.actor <> None then Mobj.think t (Inter.missile_hit t) m)
    t.things;
  t.things <- List.filter (fun (m : Things.mobj) -> m.alive) t.things;
  List.iter (fun (th : thinker) -> if th.alive then Specials.think t th) t.thinkers;
  t.thinkers <- List.filter (fun (th : thinker) -> th.alive) t.thinkers;
  (* P_UpdateSpecials *)
  Textures.animate t.textures t.tic;
  if t.message_tics > 0 then t.message_tics <- t.message_tics - 1;
  if p.damagecount > 0 then p.damagecount <- p.damagecount - 1;
  if p.bonuscount > 0 then p.bonuscount <- p.bonuscount - 1

type keys = {
  up : bool;
  down : bool;
  left : bool;
  right : bool;
  run : bool;
  strafe_left : bool;
  strafe_right : bool;
  use_key : bool;
  fire : bool;
  number : int;
}

(* G_BuildTiccmd *)
let command (p : player) (k : keys) : cmd =
  if k.left || k.right then p.turnheld <- p.turnheld + 1 else p.turnheld <- 0;
  let turnspeed = if p.turnheld < 6 then 320 else if k.run then 1280 else 640 in
  let forwardmove = if k.run then 50 else 25 and sidemove = if k.run then 40 else 24 in
  { forward = (if k.up then forwardmove else 0) - if k.down then forwardmove else 0;
    side = (if k.strafe_right then sidemove else 0) - if k.strafe_left then sidemove else 0;
    turn = (if k.left then turnspeed else 0) - if k.right then turnspeed else 0;
    use = k.use_key; attack = k.fire;
    (* (1: the chainsaw when held and not in hand, else the fist) *)
    change =
      (match k.number with
      | 1 ->
          let saw = List.mem Info.Chainsaw p.weapons && p.readyweapon <> Info.Chainsaw in
          Some (if saw then Info.Chainsaw else Info.Fist)
      | 2 -> Some Info.Pistol
      | 3 -> Some Info.Shotgun
      | _ -> None) }
