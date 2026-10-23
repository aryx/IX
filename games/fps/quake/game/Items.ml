(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Items.mli *)

open Model
open Edict

let rank (w : weapon) : int =
  match w with
  | Axe -> 0
  | Shotgun -> 1
  | Super_shotgun -> 2
  | Nailgun -> 3
  | Grenade_launcher -> 4
  | Rocket_launcher -> 5

(* the player's box and an item's (its origin at its feet, 32 wide, 56
 * high: items.qc's setsize '-16 -16 0' '16 16 56') overlap *)
let touches (w : world) (o : vec) (mins : vec) (maxs : vec) : bool =
  let p = w.play.body.origin in
  let pmin = add p Brushes.player_mins and pmax = add p Brushes.player_maxs in
  let a = add o mins and b = add o maxs in
  pmin.x < b.x && pmax.x > a.x && pmin.y < b.y && pmax.y > a.y && pmin.z < b.z
  && pmax.z > a.z

let take (w : world) (msg : string) (sfx : string) : unit =
  say w msg;
  sound w None sfx 1.;
  w.client.bonus_count <- 1.

let weapon (w : world) (wp : weapon) (msg : string) : bool =
  let c = w.client in
  (match wp with
  | Super_shotgun -> c.shells <- min 100 (c.shells + 5)
  | Nailgun -> c.nails <- min 200 (c.nails + 30)
  | Grenade_launcher | Rocket_launcher -> c.rockets <- min 100 (c.rockets + 5)
  | _ -> ());
  if not (List.mem wp c.weapons) then begin
    c.weapons <- wp :: c.weapons;
    if rank wp > rank c.weapon then c.weapon <- wp
  end;
  take w msg "weapons/pkup";
  true

let armor (w : world) (value : float) (kind : float) (msg : string) : bool =
  let c = w.client in
  if c.armor *. c.armortype >= value *. kind then false
  else begin
    c.armor <- value;
    c.armortype <- kind;
    take w msg "items/armor1";
    true
  end

let touch_things (w : world) (things : Things.thing list) : unit =
  if w.client.phealth > 0. then
    List.iter
      (fun (t : Things.thing) ->
        if
          t.alive
          && touches w t.origin
               { x = -16.; y = -16.; z = 0. }
               { x = 16.; y = 16.; z = 56. }
        then
          let taken =
            match t.classname with
            | "weapon_supershotgun" ->
                weapon w Super_shotgun "You got the Double-barrelled Shotgun"
            | "weapon_nailgun" -> weapon w Nailgun "You got the nailgun"
            | "weapon_grenadelauncher" ->
                weapon w Grenade_launcher "You got the Grenade Launcher"
            | "weapon_rocketlauncher" ->
                weapon w Rocket_launcher "You got the Rocket Launcher"
            | "item_armor1" -> armor w 100. 0.3 "You got armor"
            | "item_armor2" -> armor w 150. 0.6 "You got armor"
            | _ -> false
          in
          if taken then t.alive <- false)
      things

(* BackpackTouch *)
let backpack_touch (w : world) (e : t) (other : who) : unit =
  match other with
  | The_player when w.client.phealth > 0. ->
      w.client.shells <- min 100 (w.client.shells + e.ammo_shells);
      take w (Printf.sprintf "You get %d shells" e.ammo_shells) "weapons/lock4";
      remove w e
  | _ -> ()

let drop_backpack (w : world) (owner : t) : unit =
  if owner.ammo_shells > 0 then begin
    let e =
      spawn w "backpack" owner.origin
        { x = -16.; y = -16.; z = 0. }
        { x = 16.; y = 16.; z = 56. }
    in
    e.model <- w.models "progs/backpack.mdl";
    e.ammo_shells <- owner.ammo_shells;
    e.trigger <- true;
    e.movetype <- Toss;
    e.velocity <-
      {
        x = -100. +. (random w *. 200.);
        y = -100. +. (random w *. 200.);
        z = 300.;
      };
    e.touch <- backpack_touch;
    (* (gone in two minutes) *)
    e.nextthink <- time w +. 120.;
    e.think <- (fun (w : world) (e : t) -> remove w e)
  end
