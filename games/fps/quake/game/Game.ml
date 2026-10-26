(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Game.mli *)

open Model
open Edict

type t = { world : world; particles : Particles.t; things : Things.thing list }

let create (level : Model.t) (play : Play.t) (models : string -> Alias.t option)
    (things : Things.thing list) (monsters : bool) (ways : bool) : t =
  let client =
    {
      phealth = 100.;
      armor = 0.;
      armortype = 0.;
      shells = 25;
      nails = 0;
      rockets = 0;
      weapons = [ Axe; Shotgun ];
      weapon = Shotgun;
      pattack_finished = 0.;
      weaponframe = 0;
      weapon_time = 0.;
      damage_count = 0.;
      bonus_count = 0.;
      dead_time = 0.;
      punch = 0.;
      kills = 0;
      show_hostile = 0.;
    }
  in
  let w =
    {
      level;
      play;
      ents = [];
      next_id = 1;
      client;
      sounds = [];
      effects = [];
      sight_entity = None;
      sight_time = 0.;
      models;
      seed = 1;
      message = None;
      ways;
    }
  in
  if monsters then
    List.iter
      (fun (e : (string * string) list) ->
        match (value e "classname", value e "origin") with
        | Some c, Some o ->
            let flags =
              match Option.bind (value e "spawnflags") int_of_string_opt with
              | Some f -> f
              | None -> 0
            in
            let yaw =
              match Option.bind (value e "angle") float_of_string_opt with
              | Some a -> a
              | None -> 0.
            in
            (* (not in medium skill: 512) *)
            if flags land 512 = 0 then
              ignore (Monsters.spawn w c (vec_of_string o) yaw)
        | _ -> ())
      level.entities;
  (* the monsters' boxes in the player's way *)
  play.boxes <-
    (fun () ->
      List.filter_map
        (fun (e : Edict.t) ->
          if e.solid && not e.removed then
            Some (add e.origin e.mins, add e.origin e.maxs)
          else None)
        w.ents);
  { world = w; particles = Particles.create (); things }

let give_all (g : t) : unit =
  let c = g.world.client in
  c.weapons <-
    [ Axe; Shotgun; Super_shotgun; Nailgun; Grenade_launcher; Rocket_launcher ];
  c.shells <- 100;
  c.nails <- 200;
  c.rockets <- 100

(* the player's box overlapping an entity's *)
let in_box (w : world) (e : Edict.t) : bool =
  let p = w.play.body.origin in
  let a = add p Brushes.player_mins and b = add p Brushes.player_maxs in
  let ea = add e.origin e.mins and eb = add e.origin e.maxs in
  a.x < eb.x && b.x > ea.x && a.y < eb.y && b.y > ea.y && a.z < eb.z
  && b.z > ea.z

let frame (g : t) (dt : float) (attack : bool) (impulse : int) : unit =
  let w = g.world in
  let c = w.client in
  Weapons.frame w attack impulse;
  List.iter
    (fun (e : Edict.t) ->
      let before = e.origin in
      Physics.run w e dt;
      if e.trail > 0 && not e.removed then
        burst w (Trail (before, e.origin, e.trail));
      if e.trigger && (not e.removed) && c.phealth > 0. && in_box w e then
        e.touch w e The_player)
    w.ents;
  Items.touch_things w g.things;
  (* (the level's movers' and triggers' sounds, as the game's) *)
  List.iter
    (fun ((sfx, at) : string * vec option) -> sound w at sfx 1.)
    (Brushes.sounds w.play.brushes);
  w.ents <- List.filter (fun (e : Edict.t) -> not e.removed) w.ents;
  c.damage_count <- Float.max 0. (c.damage_count -. (1.5 *. dt));
  c.bonus_count <- Float.max 0. (c.bonus_count -. (2. *. dt));
  let now = time w in
  List.iter
    (fun (x : burst) ->
      match x with
      | Blood (o, n) -> Particles.blood g.particles now o n
      | Gunshot o -> Particles.gunshot g.particles now o
      | Explosion o -> Particles.explosion g.particles now o
      | Trail (a, b, k) -> Particles.trail g.particles now a b k)
    (List.rev w.effects);
  w.effects <- [];
  Particles.run g.particles now dt

let draw (g : t) (v : View.t) : unit =
  let w = g.world in
  let now = time w in
  List.iter
    (fun (e : Edict.t) ->
      match e.model with
      | Some mdl when not e.removed ->
          let leaf = Model.leaf_at w.level e.origin in
          if
            leaf.lvisframe = v.visframecount
            && dot (sub e.origin v.origin) v.vpn > -64.
          then begin
            let yaw =
              if mdl.flags land 8 <> 0 then Float.rem (now *. 100.) 360.
              else e.yaw
            in
            (* (a missile glows: full light) *)
            let light =
              if e.movetype = Fly_missile then 255
              else Alias.light_point w.level v e.origin
            in
            Alias.draw_pitched v mdl e.origin e.pitch yaw e.frame e.skin light
          end
      | _ -> ())
    w.ents;
  Particles.draw v g.particles;
  (* R_DrawViewModel: at the eye, the view's angles, the player's light *)
  if w.client.phealth > 0. then begin
    let name, frame = Weapons.view_model w in
    match w.models name with
    | Some mdl ->
        let light = max 24 (Alias.light_point w.level v w.play.body.origin) in
        Alias.draw_pitched v mdl v.origin
          (w.play.pitch +. w.client.punch)
          w.play.body.yaw frame 0 light
    | None -> ()
  end

let sounds (g : t) : sound list =
  let s = List.rev g.world.sounds in
  g.world.sounds <- [];
  s

let dead_for (g : t) : float option =
  let c = g.world.client in
  if c.phealth > 0. then None else Some (time g.world -. c.dead_time)

let status (g : t) : string =
  let c = g.world.client in
  Printf.sprintf "HEALTH %d  ARMOR %d  %s  KILLS %d"
    (int_of_float (Float.max 0. c.phealth))
    (int_of_float c.armor)
    (match Weapons.ammo g.world with
    | Some n -> Printf.sprintf "AMMO %d" n
    | None -> "AXE")
    c.kills
