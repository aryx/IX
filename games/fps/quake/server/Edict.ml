(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Edict.mli *)

open Model

type movetype = Mnone | Step | Toss | Bounce | Fly_missile

type act =
  | Nothing
  | Stand
  | Walk of float
  | Run of float
  | Face
  | Charge of float
  | Back of float
  | Pain_back of float
  | Pain_forward of float
  | Fire
  | Refire of string
  | Melee
  | Leap
  | Drop
  | Noise of string * float
  | Landed of string

type seq = { frames : int array; acts : act list array; next : string }

type who = Nobody | The_player | Ent of t

and t = {
  id : int;
  classname : string;
  mutable origin : vec;
  mutable velocity : vec;
  mutable yaw : float;
  mutable pitch : float;
  mutable ideal_yaw : float;
  mins : vec;
  maxs : vec;
  mutable solid : bool;
  mutable trigger : bool;
  mutable movetype : movetype;
  mutable onground : bool;
  mutable model : Alias.t option;
  mutable frame : int;
  skin : int;
  mutable health : float;
  mutable takedamage : bool;
  mutable nextthink : float;
  mutable think : world -> t -> unit;
  mutable touch : world -> t -> who -> unit;
  mutable owner : who;
  mutable enemy : who;
  mutable removed : bool;
  mutable mclass : mclass option;
  mutable seq : string;
  mutable step : int;
  mutable attack_finished : float;
  mutable pain_finished : float;
  mutable search_time : float;
  mutable pausetime : float;
  mutable lefty : bool;
  mutable trail : int;
  mutable ammo_shells : int;
  mutable seen_for : int;
}

and mclass = {
  mname : string;
  mmodel : string;
  head : string;
  mhealth : float;
  mmins : vec;
  mmaxs : vec;
  gib_health : float;
  seqs : (string * seq) list;
  stand : string;
  walk : string;
  run : string;
  missile : string;
  melee : string;
  deaths : string list;
  sight : string list;
  pain : world -> t -> float -> unit;
  fire : world -> t -> unit;
  bite : world -> t -> unit;
  check_attack : world -> t -> bool;
}

and client = {
  mutable phealth : float;
  mutable armor : float;
  mutable armortype : float;
  mutable shells : int;
  mutable nails : int;
  mutable rockets : int;
  mutable weapons : weapon list;
  mutable weapon : weapon;
  mutable pattack_finished : float;
  mutable weaponframe : int;
  mutable weapon_time : float;
  mutable damage_count : float;
  mutable bonus_count : float;
  mutable dead_time : float;
  mutable punch : float;
  mutable kills : int;
  mutable show_hostile : float;
}

and weapon =
  | Axe
  | Shotgun
  | Super_shotgun
  | Nailgun
  | Grenade_launcher
  | Rocket_launcher

and sound = { sfx : string; at : vec option; attenuation : float }

and burst =
  | Blood of vec * int
  | Gunshot of vec
  | Explosion of vec
  | Trail of vec * vec * int

and world = {
  level : Model.t;
  play : Play.t;
  mutable ents : t list;
  mutable next_id : int;
  client : client;
  mutable sounds : sound list;
  mutable effects : burst list;
  mutable sight_entity : t option;
  mutable sight_time : float;
  models : string -> Alias.t option;
  mutable seed : int;
  mutable message : (string * float) option;
  ways : bool;
}

(* Lehmer's generator, as Doom's lights' and the playground's, its 31
 * bits a float *)
let random (w : world) : float =
  w.seed <- w.seed * 16807 mod 2147483647;
  float w.seed /. 2147483647.

let crandom (w : world) : float = (2. *. random w) -. 1.
let no_think (_ : world) (_ : t) : unit = ()
let no_touch (_ : world) (_ : t) (_ : who) : unit = ()

let spawn (w : world) (classname : string) (origin : vec) (mins : vec)
    (maxs : vec) : t =
  let e =
    {
      id = w.next_id;
      classname;
      origin;
      velocity = zero;
      yaw = 0.;
      pitch = 0.;
      ideal_yaw = 0.;
      mins;
      maxs;
      solid = false;
      trigger = false;
      movetype = Mnone;
      onground = false;
      model = None;
      frame = 0;
      skin = 0;
      health = 0.;
      takedamage = false;
      nextthink = 0.;
      think = no_think;
      touch = no_touch;
      owner = Nobody;
      enemy = Nobody;
      removed = false;
      mclass = None;
      seq = "";
      step = 0;
      attack_finished = 0.;
      pain_finished = 0.;
      search_time = 0.;
      pausetime = 0.;
      lefty = false;
      trail = 0;
      ammo_shells = 0;
      seen_for = 0;
    }
  in
  w.next_id <- w.next_id + 1;
  w.ents <- w.ents @ [ e ];
  e

let remove (_ : world) (e : t) : unit =
  e.removed <- true;
  e.solid <- false;
  e.takedamage <- false

let sound (w : world) (at : vec option) (sfx : string) (attenuation : float) :
    unit =
  if sfx <> "" then w.sounds <- { sfx; at; attenuation } :: w.sounds

let say (w : world) (s : string) : unit = w.message <- Some (s, w.play.time)
let burst (w : world) (x : burst) : unit = w.effects <- x :: w.effects
let time (w : world) : float = w.play.time

let where (w : world) (who : who) : vec * vec * vec =
  match who with
  | Ent e -> (e.origin, e.mins, e.maxs)
  | _ -> (w.play.body.origin, Brushes.player_mins, Brushes.player_maxs)

let eye (w : world) (who : who) : vec =
  match who with
  | Ent e -> { e.origin with z = e.origin.z +. 25. }
  | _ ->
      let o = w.play.body.origin in
      { o with z = o.z +. 22. }

let alive (w : world) (who : who) : bool =
  match who with
  | Nobody -> false
  | The_player -> w.client.phealth > 0.
  | Ent e -> (not e.removed) && e.takedamage && e.health > 0.

let same (a : who) (b : who) : bool =
  match (a, b) with
  | The_player, The_player -> true
  | Ent x, Ent y -> x == y
  | _ -> false

let vectoyaw (v : vec) : float =
  if v.x = 0. && v.y = 0. then 0.
  else
    let a = Float.atan2 v.y v.x *. 180. /. Float.pi in
    if a < 0. then a +. 360. else a
