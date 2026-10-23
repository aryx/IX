(* Edict: a thing that acts in the level, and the world they act in
 * (Quake's edict_t and QuakeC's defs.qc: the fields every entity has,
 * and the globals).
 *
 * In Quake, the engine knew an entity by a few fields -- its origin,
 * its box, how it moves (movetype), what it collides as (solid), its
 * model and frame -- and QuakeC gave it the rest, and functions:
 * [think], called at [nextthink], and [touch], called when it runs
 * into something. A monster is a chain of thinks, one a frame of its
 * animation, a tenth of a second apart (QuakeC's
 * [void() army_run1 = [$run1, army_run2] {ai_run(11);}]: the frame,
 * the next think, and what it does); a grenade is a think in 2.5
 * seconds, its explosion, and a touch, its bounce.
 *
 *   the world: the level, the player (Play), the entities, the time
 *     |
 *     |-- an entity: origin, velocity, box, movetype, solid, model
 *     |     think at nextthink   (Monster_ai's frames, a grenade's fuse)
 *     |     touch on contact     (a rocket's explosion)
 *     |-- the player's fight: health, armor, ammo, weapons
 *     |-- what the client shows: sounds made, particles, the flash
 *
 * Here a monster's frames are data ([mclass], [seq], [act]: Monsters
 * writes them out as grunt.qc does), run by Monster_ai; the other entities'
 * think and touch are OCaml functions, as QuakeC's were.
 *
 * Where it stands in mini-quake: Game makes the world, spawns the
 * entities, runs them each frame; Physics moves them, Combat hurts
 * them, Monster_ai and Monsters think for the monsters, Weapons and Items for
 * the player; Quake.ml plays the sounds and Render draws the rest. *)

(* how it moves (sv_phys.c's movetypes) *)
type movetype =
  | Mnone (* still *)
  | Step (* a monster: walks by Physics.move_step, falls *)
  | Toss (* thrown: falls, stops at the floor (a backpack, a gib) *)
  | Bounce (* a grenade: falls, bounces *)
  | Fly_missile (* straight, no gravity (a rocket, a nail) *)

(* what a monster's frame does (ai.qc's and fight.qc's functions, and
 * the monster's own) *)
type act =
  | Nothing
  | Stand (* ai_stand: looks for the player *)
  | Walk of float (* ai_walk *)
  | Run of float (* ai_run: chases, attacks *)
  | Face (* ai_face *)
  | Charge of float (* ai_charge: faces and steps *)
  | Back of float (* ai_back *)
  | Pain_back of float (* ai_pain *)
  | Pain_forward of float (* ai_painforward *)
  | Fire (* the class's attack *)
  | Refire of string (* SUB_CheckRefire: again from that sequence *)
  | Melee (* the class's bite *)
  | Leap (* the dog's jump *)
  | Drop (* solid no more, the backpack dropped *)
  | Noise of string * float (* a sound, at that chance *)
  | Landed of string (* on the ground again (a leap's end): that sequence *)

(* an animation: its frames of the model, what each does, the sequence
 * after ("": its last frame kept, a death's) *)
type seq = { frames : int array; acts : act list array; next : string }

type who = Nobody | The_player | Ent of t

and t = {
  id : int;
  classname : string;
  mutable origin : Model.vec;
  mutable velocity : Model.vec;
  mutable yaw : float; (* degrees *)
  mutable pitch : float;
  mutable ideal_yaw : float;
  mins : Model.vec;
  maxs : Model.vec;
  mutable solid : bool; (* a box others collide with *)
  mutable trigger : bool; (* touched by the player on overlap (SOLID_TRIGGER) *)
  mutable movetype : movetype;
  mutable onground : bool;
  mutable model : Alias.t option;
  mutable frame : int;
  skin : int;
  mutable health : float;
  mutable takedamage : bool;
  mutable nextthink : float; (* 0: none *)
  mutable think : world -> t -> unit;
  mutable touch : world -> t -> who -> unit;
  mutable owner : who; (* a missile's shooter *)
  mutable enemy : who;
  mutable removed : bool;
  (* a monster's *)
  mutable mclass : mclass option;
  mutable seq : string;
  mutable step : int;
  mutable attack_finished : float;
  mutable pain_finished : float;
  mutable search_time : float;
  mutable pausetime : float;
  mutable lefty : bool;
  mutable trail : int;
      (* particles behind: 0 none, 1 a rocket's, 2 a grenade's *)
  mutable ammo_shells : int; (* what its backpack gives *)
  mutable seen_for : int; (* thinks it has seen its enemy (Ai.aim_error) *)
}

(* what a kind of monster is (its spawn function and th_ fields) *)
and mclass = {
  mname : string;
  mmodel : string; (* progs/soldier.mdl *)
  head : string; (* its gibbed head's model *)
  mhealth : float;
  mmins : Model.vec;
  mmaxs : Model.vec;
  gib_health : float; (* below it, gibbed *)
  seqs : (string * seq) list;
  stand : string;
  walk : string;
  run : string;
  missile : string; (* "" none *)
  melee : string;
  deaths : string list; (* one of them *)
  sight : string list; (* its sounds, one of them *)
  pain : world -> t -> float -> unit; (* th_pain, the damage *)
  fire : world -> t -> unit;
  bite : world -> t -> unit;
  check_attack : world -> t -> bool;
}

(* the player's fight (client.qc, items.qc's fields of the player) *)
and client = {
  mutable phealth : float;
  mutable armor : float;
  mutable armortype : float; (* the part it takes: 0.3, 0.6 *)
  mutable shells : int;
  mutable nails : int;
  mutable rockets : int;
  mutable weapons : weapon list;
  mutable weapon : weapon;
  mutable pattack_finished : float;
  mutable weaponframe : int; (* the view model's frame *)
  mutable weapon_time : float; (* its next *)
  mutable damage_count : float; (* the screen red *)
  mutable bonus_count : float; (* the screen gold *)
  mutable dead_time : float; (* when it died, 0 alive *)
  mutable punch : float; (* the view kicked up, degrees (punchangle) *)
  mutable kills : int;
  mutable show_hostile : float;
      (* it shot: the monsters near wake, even behind *)
}

and weapon =
  | Axe
  | Shotgun
  | Super_shotgun
  | Nailgun
  | Grenade_launcher
  | Rocket_launcher

(* a sound made: its name (sound/x.wav's x), from where (None: the
 * player's own), its attenuation (1 normal, 2 idle, 0 everywhere) *)
and sound = { sfx : string; at : Model.vec option; attenuation : float }

(* a burst of particles (r_part.c's effects) *)
and effect =
  | Blood of Model.vec * int (* where, how many *)
  | Gunshot of Model.vec
  | Explosion of Model.vec
  | Trail of
      Model.vec * Model.vec * int (* from, to, a rocket's 1 or a grenade's 2 *)

and world = {
  level : Model.t;
  play : Play.t;
  mutable ents : t list;
  mutable next_id : int;
  client : client;
  mutable sounds : sound list; (* the last first *)
  mutable effects : effect list;
  mutable sight_entity : t option; (* a monster that saw the player, and when *)
  mutable sight_time : float;
  models : string -> Alias.t option; (* progs/x.mdl, read once *)
  mutable seed : int;
  mutable message : (string * float) option;
  ways : bool;
      (* ai=ways: the playground's AI (Ways) *)
      (* centerprint's, since when *)
}

(* QuakeC's random (): 0 to 1, the same game for the same keys *)
val random : world -> float

(* crandom (): -1 to 1 *)
val crandom : world -> float

(* [spawn w classname origin mins maxs]: a new entity, still, not
 * solid, thinking nothing *)
val spawn : world -> string -> Model.vec -> Model.vec -> Model.vec -> t

(* [remove w e]: gone at the end of the frame *)
val remove : world -> t -> unit

(* [sound w e sfx attenuation]: e's sound (None: the player's) *)
val sound : world -> Model.vec option -> string -> float -> unit

(* [say w s]: centerprint *)
val say : world -> string -> unit

(* [effect w x] *)
val effect : world -> effect -> unit

(* the time (Play's) *)
val time : world -> float

(* where a who is: its origin and box *)
val where : world -> who -> Model.vec * Model.vec * Model.vec

(* its eye (view_ofs: 22 the player, 25 a monster) *)
val eye : world -> who -> Model.vec

(* alive and hurtable *)
val alive : world -> who -> bool

(* the same entity (or both the player) *)
val same : who -> who -> bool

(* the think that does nothing (SUB_Null), the touch that does nothing *)
val no_think : world -> t -> unit
val no_touch : world -> t -> who -> unit

(* vectoyaw: degrees, 0 to 360 *)
val vectoyaw : Model.vec -> float
