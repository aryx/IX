(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Things.mli *)

open Model

type thing = {
  classname : string;
  origin : vec;
  yaw : float;
  model : Alias.t;
  frames : int array;
  skin : int;
  mutable alive : bool;
}

(* each classname's model, skin and animation (the QuakeC's spawn
 * functions: setmodel, self.skin, th_stand) *)
let kinds : (string * (string * int * string)) list =
  [
    ("monster_army", ("progs/soldier.mdl", 0, "stand"));
    ("monster_dog", ("progs/dog.mdl", 0, "stand"));
    ("monster_enforcer", ("progs/enforcer.mdl", 0, "stand"));
    ("monster_ogre", ("progs/ogre.mdl", 0, "stand"));
    ("monster_knight", ("progs/knight.mdl", 0, "stand"));
    ("monster_zombie", ("progs/zombie.mdl", 0, "stand"));
    ("monster_wizard", ("progs/wizard.mdl", 0, "hover"));
    ("monster_demon1", ("progs/demon.mdl", 0, "stand"));
    ("monster_shambler", ("progs/shambler.mdl", 0, "stand"));
    ("monster_fish", ("progs/fish.mdl", 0, "swim"));
    ("weapon_supershotgun", ("progs/g_shot.mdl", 0, ""));
    ("weapon_nailgun", ("progs/g_nail.mdl", 0, ""));
    ("weapon_supernailgun", ("progs/g_nail2.mdl", 0, ""));
    ("weapon_grenadelauncher", ("progs/g_rock.mdl", 0, ""));
    ("weapon_rocketlauncher", ("progs/g_rock2.mdl", 0, ""));
    ("weapon_lightning", ("progs/g_light.mdl", 0, ""));
    ("item_armor1", ("progs/armor.mdl", 0, ""));
    ("item_armor2", ("progs/armor.mdl", 1, ""));
    ("item_armorInv", ("progs/armor.mdl", 2, ""));
    ("item_artifact_envirosuit", ("progs/suit.mdl", 0, ""));
    ("item_artifact_invulnerability", ("progs/invulner.mdl", 0, ""));
    ("item_artifact_super_damage", ("progs/quaddama.mdl", 0, ""));
    ("item_artifact_invisibility", ("progs/invisibl.mdl", 0, ""));
  ]

(* the keys, by the level's kind of world (worldspawn's worldtype: 0
 * medieval, 1 metal, 2 base) *)
let key_model (worldtype : int) (gold : bool) : string =
  let w = match worldtype with 1 -> "m" | 2 -> "b" | _ -> "w" in
  Printf.sprintf "progs/%s_%s_key.mdl" w (if gold then "g" else "s")

(* droptofloor: a monster's box (its origin 24 above its feet) or an
 * item's (its origin at its feet) traced 256 down, in the player's
 * hull: where it stops *)
let drop (m : Model.t) (monster : bool) (o : vec) : vec =
  let feet = if monster then 0. else 24. in
  let start = { o with z = o.z +. (if monster then 1. else 6.) +. feet } in
  let t = Trace.move m 1 start { start with z = start.z -. 256. } [] in
  if t.allsolid || t.fraction = 1. then o
  else { t.endpos with z = t.endpos.z -. feet }

let load (m : Model.t) (read : string -> string option) : thing list =
  let cache = Hashtbl.create 16 in
  let model (path : string) : Alias.t option =
    match Hashtbl.find_opt cache path with
    | Some x -> x
    | None ->
        let x = Option.map Alias.load (read path) in
        Hashtbl.add cache path x;
        x
  in
  let worldtype =
    match m.entities with
    | w :: _ -> (
        match Option.bind (value w "worldtype") int_of_string_opt with
        | Some t -> t
        | None -> 0)
    | [] -> 0
  in
  List.filter_map
    (fun (e : (string * string) list) ->
      let classname =
        match value e "classname" with Some c -> c | None -> ""
      in
      let flags =
        match Option.bind (value e "spawnflags") int_of_string_opt with
        | Some f -> f
        | None -> 0
      in
      let kind =
        if classname = "item_key1" then Some (key_model worldtype false, 0, "")
        else if classname = "item_key2" then
          Some (key_model worldtype true, 0, "")
        else List.assoc_opt classname kinds
      in
      match (kind, value e "origin") with
      (* (not in medium skill: SPAWNFLAG_NOT_MEDIUM) *)
      | Some (path, skin, anim), Some o when flags land 512 = 0 -> (
          match model path with
          | Some mdl ->
              let frames =
                if anim = "" then [ 0 ] else Alias.frames_named mdl anim
              in
              Some
                {
                  classname;
                  origin =
                    drop m
                      (String.length classname > 8
                      && String.sub classname 0 8 = "monster_")
                      (vec_of_string o);
                  yaw =
                    (match
                       Option.bind (value e "angle") float_of_string_opt
                     with
                    | Some a -> a
                    | None -> 0.);
                  model = mdl;
                  frames = Array.of_list (if frames = [] then [ 0 ] else frames);
                  skin;
                  alive = true;
                }
          | None -> None)
      | _ -> None)
    m.entities

let draw (v : View.t) (m : Model.t) (things : thing list) (time : float) : unit
    =
  List.iter
    (fun (t : thing) ->
      if t.alive then begin
        let leaf = Model.leaf_at m t.origin in
        (* in the PVS, and in front of the eye *)
        if
          leaf.lvisframe = v.visframecount
          && dot (sub t.origin v.origin) v.vpn > -64.
        then begin
          let frame =
            t.frames.(int_of_float (time *. 10.) mod Array.length t.frames)
          in
          let yaw =
            if t.model.flags land 8 <> 0 then Float.rem (time *. 100.) 360.
            else t.yaw
          in
          Alias.draw v t.model t.origin yaw frame t.skin
            (Alias.light_point m v t.origin)
        end
      end)
    things
