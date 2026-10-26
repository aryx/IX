(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Combat.mli *)

open Model
open Edict

(* ThrowGib: a piece, tossed by the damage, gone in 10 seconds *)
let throw_gib (w : world) (o : vec) (model : string) (amount : float) : unit =
  let g = spawn w "gib" o zero zero in
  g.model <- w.models model;
  g.movetype <- Bounce;
  let k = Float.min 4. (-.amount /. 50.) in
  g.velocity <-
    {
      x = 100. *. crandom w *. (1. +. k);
      y = 100. *. crandom w *. (1. +. k);
      z = 200. +. (100. *. random w);
    };
  g.yaw <- random w *. 360.;
  g.nextthink <- time w +. 10. +. (random w *. 10.);
  g.think <- (fun (w : world) (g : t) -> remove w g)

(* the monster dead: gibbed, or its death frames *)
let killed (w : world) (e : t) (c : mclass) : unit =
  e.takedamage <- false;
  w.client.kills <- w.client.kills + 1;
  if e.health < c.gib_health then begin
    sound w (Some e.origin) "player/udeath" 1.;
    List.iter
      (fun (m : string) -> throw_gib w e.origin m e.health)
      [ "progs/gib1.mdl"; "progs/gib2.mdl"; "progs/gib3.mdl" ];
    (* (ThrowHead: the entity itself becomes its head) *)
    e.model <- w.models c.head;
    e.frame <- 0;
    e.solid <- false;
    e.nextthink <- 0.;
    e.movetype <- Bounce;
    e.onground <- false;
    e.velocity <- { x = 100. *. crandom w; y = 100. *. crandom w; z = 250. };
    (* (the backpack the death frames would have dropped) *)
    Items.drop_backpack w e
  end
  else begin
    let k = int_of_float (random w *. float (List.length c.deaths)) in
    let d = List.nth c.deaths (min k (List.length c.deaths - 1)) in
    Monster_ai.start w e d
  end

(* PlayerPain, PlayerDie *)
let player_hurt (w : world) (amount : float) : unit =
  let c = w.client in
  if c.phealth <= 0. then begin
    c.dead_time <- time w;
    sound w None
      (if c.phealth < -40. then "player/udeath"
       else Printf.sprintf "player/death%d" (1 + int_of_float (random w *. 5.)))
      1.
  end
  else if amount > 0. then
    sound w None
      (Printf.sprintf "player/pain%d" (1 + int_of_float (random w *. 6.)))
      1.

let damage (w : world) (target : who) (from : vec) (attacker : who)
    (amount : float) : unit =
  if alive w target then
    match target with
    | Nobody -> ()
    | The_player ->
        let c = w.client in
        let save = Float.min c.armor (Float.ceil (c.armortype *. amount)) in
        c.armor <- c.armor -. save;
        if c.armor <= 0. then c.armortype <- 0.;
        let take = Float.ceil (amount -. save) in
        c.phealth <- c.phealth -. take;
        c.damage_count <- Float.min 1. (c.damage_count +. (take /. 50.));
        let b = w.play.body in
        let dir = normalize (sub b.origin from) in
        b.velocity <- add b.velocity (scale (amount *. 8.) dir);
        player_hurt w take
    | Ent e -> (
        match e.mclass with
        | None -> ()
        | Some c ->
            e.health <- e.health -. amount;
            if e.health <= 0. then killed w e c
            else begin
              (* (it turns on what hurt it: a monster too, not of its
               * own kind, but soldiers on each other) *)
              let own =
                match attacker with
                | Ent a ->
                    a.classname = e.classname && e.classname <> "monster_army"
                | _ -> false
              in
              if
                alive w attacker
                && (not (same attacker target))
                && (not (same attacker e.enemy))
                && not own
              then begin
                e.enemy <- attacker;
                Monster_ai.found_target w e
              end;
              c.pain w e amount
            end)

(* CanDamage: a line to its middle, or a corner of its box at 15 *)
let can_damage (w : world) (o : vec) (target : who) : bool =
  let p, _, _ = where w target in
  List.exists
    (fun ((dx, dy) : float * float) ->
      let t =
        Physics.traceline w o
          { p with x = p.x +. dx; y = p.y +. dy }
          false Nobody
      in
      t.fraction = 1.)
    [ (0., 0.); (15., 15.); (-15., -15.); (-15., 15.); (15., -15.) ]

let radius_damage (w : world) (o : vec) (attacker : who) (amount : float)
    (ignore : who) : unit =
  let hurt (target : who) : unit =
    if alive w target && not (same target ignore) then begin
      let p, mins, maxs = where w target in
      let middle = add p (scale 0.5 (add mins maxs)) in
      let points = amount -. (0.5 *. length (sub o middle)) in
      let points = if same target attacker then points *. 0.5 else points in
      if points > 0. && can_damage w o target then
        damage w target o attacker points
    end
  in
  List.iter (fun (e : t) -> hurt (Ent e)) w.ents;
  hurt The_player

let explode (w : world) (e : t) : unit =
  if not e.removed then begin
    remove w e;
    radius_damage w e.origin e.owner 120. Nobody;
    sound w (Some e.origin) "weapons/r_exp3" 1.;
    burst w (Explosion e.origin)
  end

(*****************************************************************************)
(* Shots (weapons.qc's, which the monsters' share) *)
(*****************************************************************************)

(* a direction's right and up (makevectors of its angles) *)
let axes (dir : vec) : vec * vec =
  let right = normalize (cross dir { x = 0.; y = 0.; z = 1. }) in
  let right =
    if length right < 0.5 then { x = 0.; y = -1.; z = 0. } else right
  in
  (right, cross right dir)

(* FireBullets, TraceAttack: [n] pellets of 4 along dir, spread by
 * (sx, sy); blood where a thing is hit, a puff on a wall *)
let fire_bullets (w : world) (shooter : who) (src : vec) (dir : vec) (n : int)
    ((sx, sy) : float * float) : unit =
  let right, up = axes dir in
  for _i = 1 to n do
    let d =
      add dir (add (scale (crandom w *. sx) right) (scale (crandom w *. sy) up))
    in
    let t = Physics.traceline w src (add src (scale 2048. d)) true shooter in
    if t.fraction < 1. && not t.sky then begin
      let at = sub t.endpos (scale 4. d) in
      match t.what with
      | Nobody -> burst w (Gunshot at)
      | hit ->
          burst w (Blood (at, 8));
          damage w hit src shooter 4.
    end
  done

(* a missile: [model] from src along dir at speed, its touch *)
let launch (w : world) (owner : who) (classname : string) (model : string)
    (src : vec) (dir : vec) (speed : float) (touch : world -> t -> who -> unit)
    : t =
  let e = spawn w classname src zero zero in
  e.model <- w.models model;
  e.owner <- owner;
  e.movetype <- Fly_missile;
  e.velocity <- scale speed dir;
  e.yaw <- vectoyaw dir;
  e.pitch <-
    -.(Float.atan2 dir.z (sqrt ((dir.x *. dir.x) +. (dir.y *. dir.y)))
      *. 180. /. Float.pi);
  e.touch <- touch;
  (* (gone in 6 seconds if it touches nothing) *)
  e.nextthink <- time w +. 6.;
  e.think <- (fun (w : world) (e : t) -> remove w e);
  e
