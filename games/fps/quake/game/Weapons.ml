(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Weapons.mli *)

open Model
open Edict

let ammo (w : world) : int option =
  let c = w.client in
  match c.weapon with
  | Axe -> None
  | Shotgun | Super_shotgun -> Some c.shells
  | Nailgun -> Some c.nails
  | Grenade_launcher | Rocket_launcher -> Some c.rockets

let has_ammo (c : client) (wp : weapon) : bool =
  match wp with
  | Axe -> true
  | Shotgun -> c.shells >= 1
  | Super_shotgun -> c.shells >= 2
  | Nailgun -> c.nails >= 1
  | Grenade_launcher | Rocket_launcher -> c.rockets >= 1

(* W_BestWeapon: the best one held that has its ammunition (the
 * launchers not: one does not switch to a rocket by surprise) *)
let best (c : client) : weapon =
  List.fold_left
    (fun (b : weapon) (wp : weapon) ->
      if List.mem wp c.weapons && has_ammo c wp && Items.rank wp > Items.rank b
      then wp
      else b)
    Axe
    [ Shotgun; Super_shotgun; Nailgun ]

(* the player's place, its eye, its forward *)
let origin (w : world) : vec = w.play.body.origin

let forward (w : world) : vec =
  let f, _, _ = View.angle_vectors w.play.pitch w.play.body.yaw in
  f

(* PF_aim: the look, or towards a monster within 0.93 of it that a
 * line reaches, its height only *)
let aim (w : world) (src : vec) : vec =
  let f = forward w in
  let t = Physics.traceline w src (add src (scale 2048. f)) true The_player in
  match t.what with
  | Ent e when e.takedamage -> f
  | _ -> (
      let best = ref None and bestdot = ref 0.93 in
      List.iter
        (fun (e : t) ->
          if e.takedamage && not e.removed then begin
            let middle = add e.origin (scale 0.5 (add e.mins e.maxs)) in
            let dir = normalize (sub middle src) in
            let d = dot dir f in
            if d > !bestdot then begin
              let t = Physics.traceline w src middle true The_player in
              if same t.what (Ent e) then begin
                bestdot := d;
                best := Some dir
              end
            end
          end)
        w.ents;
      match !best with Some dir -> normalize { f with z = dir.z } | None -> f)

(* the weapon in hand's frames started (player_shot1 ...) *)
let animate (w : world) : unit =
  w.client.weaponframe <- 1;
  w.client.weapon_time <- time w +. 0.1

(* W_FireAxe *)
let fire_axe (w : world) : unit =
  let src = { (origin w) with z = (origin w).z +. 16. } in
  let f = forward w in
  sound w None "weapons/ax1" 1.;
  let t = Physics.traceline w src (add src (scale 64. f)) true The_player in
  if t.fraction < 1. then begin
    let at = sub t.endpos (scale 4. f) in
    match t.what with
    | Nobody ->
        sound w (Some at) "player/axhit2" 1.;
        effect w (Gunshot at)
    | hit ->
        effect w (Blood (at, 20));
        Combat.damage w hit src The_player 20.
  end

(* spike_touch: 9, blood, or a ricochet's tink *)
let spike_touch (w : world) (e : t) (other : who) : unit =
  (match other with
  | Nobody ->
      effect w (Gunshot e.origin);
      let r = random w in
      sound w (Some e.origin)
        (if r < 0.25 then "weapons/tink1"
         else if r < 0.5 then "weapons/ric1"
         else if r < 0.75 then "weapons/ric2"
         else "weapons/ric3")
        1.
  | _ ->
      effect w (Blood (e.origin, 9));
      Combat.damage w other e.origin e.owner 9.);
  remove w e

(* T_MissileTouch: the rocket's hit, then its blast past it *)
let rocket_touch (w : world) (e : t) (other : who) : unit =
  if not e.removed then begin
    if alive w other then
      Combat.damage w other e.origin e.owner (100. +. (random w *. 20.));
    remove w e;
    Combat.radius_damage w e.origin e.owner 120. other;
    sound w (Some e.origin) "weapons/r_exp3" 1.;
    effect w (Explosion e.origin)
  end

(* GrenadeTouch: on a monster, at once; else a bounce's sound *)
let grenade_touch (w : world) (e : t) (other : who) : unit =
  match other with
  | Ent x when x.takedamage -> Combat.explode w e
  | The_player -> Combat.explode w e
  | _ ->
      if length e.velocity > 20. then
        sound w (Some e.origin) "weapons/bounce" 1.

let fire (w : world) : unit =
  let c = w.client in
  let src = { (origin w) with z = (origin w).z +. 16. } in
  c.show_hostile <- time w +. 1.;
  match c.weapon with
  | Axe ->
      fire_axe w;
      c.pattack_finished <- time w +. 0.5;
      animate w
  | Shotgun ->
      sound w None "weapons/guncock" 1.;
      c.shells <- c.shells - 1;
      c.punch <- -2.;
      Combat.fire_bullets w The_player src (aim w src) 6 (0.04, 0.04);
      c.pattack_finished <- time w +. 0.5;
      animate w
  | Super_shotgun ->
      sound w None "weapons/shotgn2" 1.;
      c.shells <- c.shells - 2;
      c.punch <- -4.;
      Combat.fire_bullets w The_player src (aim w src) 14 (0.14, 0.08);
      c.pattack_finished <- time w +. 0.7;
      animate w
  | Nailgun ->
      sound w None "weapons/rocket1i" 1.;
      c.nails <- c.nails - 1;
      c.punch <- -2.;
      (* (the barrels in turn: 4 to the right, then to the left) *)
      let _, right, _ = View.angle_vectors w.play.pitch w.play.body.yaw in
      let side = if c.weaponframe land 1 = 0 then 4. else -4. in
      let e =
        Combat.launch w The_player "spike" "progs/spike.mdl"
          (add src (scale side right))
          (aim w src) 1000. spike_touch
      in
      ignore e;
      c.pattack_finished <- time w +. 0.2;
      c.weaponframe <- (c.weaponframe mod 8) + 1;
      c.weapon_time <- time w +. 0.1
  | Grenade_launcher ->
      sound w None "weapons/grenade" 1.;
      c.rockets <- c.rockets - 1;
      c.punch <- -2.;
      let f, right, up = View.angle_vectors w.play.pitch w.play.body.yaw in
      let e =
        Combat.launch w The_player "grenade" "progs/grenade.mdl" src f 600.
          grenade_touch
      in
      e.movetype <- Bounce;
      e.velocity <-
        add (scale 600. f)
          (add (scale 200. up)
             (add
                (scale (crandom w *. 10.) right)
                (scale (crandom w *. 10.) up)));
      e.trail <- 2;
      e.nextthink <- time w +. 2.5;
      e.think <- Combat.explode;
      c.pattack_finished <- time w +. 0.6;
      animate w
  | Rocket_launcher ->
      sound w None "weapons/sgun1" 1.;
      c.rockets <- c.rockets - 1;
      c.punch <- -2.;
      let dir = aim w src in
      let e =
        Combat.launch w The_player "missile" "progs/missile.mdl"
          (add src (scale 8. dir))
          dir 1000. rocket_touch
      in
      e.trail <- 1;
      c.pattack_finished <- time w +. 0.8;
      animate w

let of_impulse (k : int) : weapon option =
  match k with
  | 1 -> Some Axe
  | 2 -> Some Shotgun
  | 3 -> Some Super_shotgun
  | 4 -> Some Nailgun
  | 6 -> Some Grenade_launcher
  | 7 -> Some Rocket_launcher
  | _ -> None

let frame (w : world) (attack : bool) (impulse : int) : unit =
  let c = w.client in
  if c.phealth > 0. then begin
    (* (the weapon in hand's frames, a tenth of a second each, back to
     * 0 after 6, the nailgun's while it fires) *)
    if c.weaponframe > 0 && time w >= c.weapon_time then
      if c.weapon = Nailgun || c.weaponframe >= 6 then c.weaponframe <- 0
      else begin
        c.weaponframe <- c.weaponframe + 1;
        c.weapon_time <- time w +. 0.1
      end;
    (* W_ChangeWeapon: held, and with ammunition *)
    (match of_impulse impulse with
    | Some wp when List.mem wp c.weapons && wp <> c.weapon ->
        if has_ammo c wp then begin
          c.weapon <- wp;
          c.weaponframe <- 0
        end
        else Edict.say w "not enough ammo."
    | _ -> ());
    if attack && time w >= c.pattack_finished then
      if has_ammo c c.weapon then fire w
      else begin
        c.weapon <- best c;
        c.weaponframe <- 0
      end;
    (* (the kick back to level, 10 degrees a second) *)
    if c.punch < 0. then c.punch <- Float.min 0. (c.punch +. 0.5)
  end

let view_model (w : world) : string * int =
  let c = w.client in
  ( (match c.weapon with
    | Axe -> "progs/v_axe.mdl"
    | Shotgun -> "progs/v_shot.mdl"
    | Super_shotgun -> "progs/v_shot2.mdl"
    | Nailgun -> "progs/v_nail.mdl"
    | Grenade_launcher -> "progs/v_rock.mdl"
    | Rocket_launcher -> "progs/v_rock2.mdl"),
    c.weaponframe )

let models =
  [
    "progs/v_axe.mdl";
    "progs/v_shot.mdl";
    "progs/v_shot2.mdl";
    "progs/v_nail.mdl";
    "progs/v_rock.mdl";
    "progs/v_rock2.mdl";
    "progs/spike.mdl";
    "progs/grenade.mdl";
    "progs/missile.mdl";
  ]

let sounds =
  [
    "weapons/ax1";
    "player/axhit2";
    "weapons/guncock";
    "weapons/shotgn2";
    "weapons/rocket1i";
    "weapons/tink1";
    "weapons/ric1";
    "weapons/ric2";
    "weapons/ric3";
    "weapons/grenade";
    "weapons/bounce";
    "weapons/sgun1";
    "weapons/r_exp3";
    "weapons/pkup";
    "weapons/lock4";
    "items/armor1";
    "player/pain1";
    "player/pain2";
    "player/pain3";
    "player/pain4";
    "player/pain5";
    "player/pain6";
    "player/death1";
    "player/death2";
    "player/death3";
    "player/death4";
    "player/death5";
  ]
