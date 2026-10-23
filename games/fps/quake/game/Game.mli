(* Game: the server's frame and what the client is given to draw and
 * play (Quake's sv_main.c and sv_phys.c's SV_Physics, host.c's frame;
 * cl_main.c's entities; QuakeC's StartFrame and PlayerPreThink).
 *
 *   each frame:
 *     the player's weapon (Weapons: the attack key, the weapon asked)
 *     every entity (Physics.run: its move by its movetype, its think
 *       when its time came: a monster's frame, a grenade's fuse); a
 *       missile's trail from where it was to where it is
 *     the triggers the player is in (a backpack), the items it is on
 *     the effects made (Edict's) become particles
 *
 * The world's state is Edict's; this is its frame and its spawning:
 * the map's monster_* by Monsters (but with nomonsters), the player's
 * start: 100 health, the axe and the shotgun, 25 shells (client.qc's
 * SetNewParms).
 *
 * Where it stands in mini-quake: Quake.ml makes one, calls [frame]
 * after Play's, [draw] after Render's world, plays the [sounds]. *)

type t = {
  world : Edict.world;
  particles : Particles.t;
  things : Things.thing list; (* the items standing *)
}

(* [create level play models things monsters ways]: the world, its
 * monsters spawned if asked; [ways] the playground's AI (ai=ways) *)
val create :
  Model.t ->
  Play.t ->
  (string -> Alias.t option) ->
  Things.thing list ->
  bool ->
  bool ->
  t

(* [give_all g]: impulse 9: every weapon, ammunition *)
val give_all : t -> unit

(* [frame g dt attack impulse]: the game's dt seconds (after Play's) *)
val frame : t -> float -> bool -> int -> unit

(* [draw g v]: the entities' models, the particles, the weapon in hand,
 * into v after the world *)
val draw : t -> View.t -> unit

(* the sounds made since the last call, in order *)
val sounds : t -> Edict.sound list

(* the player dead, and for how long *)
val dead_for : t -> float option

(* the status line: health, armor, ammunition, kills *)
val status : t -> string
