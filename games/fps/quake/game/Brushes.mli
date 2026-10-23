(* Brushes: the level's moving and touched things, its brush models
 * and triggers, as QuakeC made them work (id's doors.qc, plats.qc,
 * buttons.qc, triggers.qc, subs.qc, misc.qc's lights).
 *
 * Quake's game logic was not in its engine: the entities of the map
 * (their "classname" and keys) were brought to life by progs.dat,
 * QuakeC compiled, run by the engine's virtual machine. No progs.dat
 * is free to ship (LibreQuake's QuakeC needs a compiler of it), so the
 * few kinds a walk meets are written here, the names of their
 * functions those of id's QuakeC:
 *
 *   func_door      moves along "angle" (-1 up, -2 down) by its size
 *                  less "lip", at "speed", waits "wait" (-1: stays
 *                  open), opened by a field around it (doors that touch
 *                  open together), by a target, or by touching it with
 *                  the key it needs (spawnflags 8 gold, 16 silver)
 *   func_door_secret  pushed back, then aside (fd_secret_use); opened
 *                  by a shot in Quake, here by the use key
 *   func_button    pressed by touch (or a shot, here the use key):
 *                  moves in, its textures' other frames (+a...), fires
 *                  its targets
 *   func_plat      a lift: goes up when stood on, down 3 s after
 *   trigger_once, trigger_multiple, trigger_secret, trigger_teleport,
 *   trigger_changelevel   invisible boxes, touched
 *   a light with a targetname  switched on and off (its style's
 *                  string "m" or "a")
 *
 * A mover (SUB_CalcMove) goes at its speed to its destination; on the
 * way it pushes the player (SV_PushMove): if the player's box is in
 * it, or stands on it, the player is moved the same; if that fails (a
 * wall behind), the mover stops and is blocked (a door goes back).
 *
 * A target is a name: an entity's "target" fires every entity whose
 * "targetname" it is (SUB_UseTargets), each by its own use.
 *
 * Entities flagged not for this skill (spawnflags 256, 512, 1024:
 * easy, medium, hard; this is medium) or for deathmatch only are not
 * spawned, as the engine's ED_LoadFromFile. *)

(* the player as the brushes see it *)
type body = {
  mutable origin : Model.vec;
  mutable velocity : Model.vec;
  mutable yaw : float;
  mutable onground : bool;
  (* what it stands on: -1 the world, else a brush's entity *)
  mutable ground : int;
}

type t

(* the player's box around its origin: 32 by 32 by 56 *)
val player_mins : Model.vec
val player_maxs : Model.vec

(* [create m styles]: the level's brush entities spawned; styles (64)
 * set to world.qc's *)
val create : Model.t -> string array -> t

(* [run b body time dt]: the brushes moved and thought for dt seconds,
 * up to time; the player pushed *)
val run : t -> body -> float -> float -> unit

(* [touch b body time]: the player's box touches what it touches *)
val touch : t -> body -> float -> unit

(* [use b body eye forward time]: the use key: the brush model the
 * eye looks at within 96 units, used as if shot *)
val use : t -> body -> Model.vec -> Model.vec -> float -> unit

(* [taken b classname origin]: an item of the map picked up (a key) *)
val taken : t -> string -> Model.vec -> bool

(* the solid brush models, for traces: (entity, model, origin) *)
val solids : t -> (int * int * Model.vec) list

(* the brush models drawn: (entity, model, origin, frame) *)
val drawn : t -> (int * int * Model.vec * int) list

(* the message shown (a door's, a trigger's), and since when *)
val message : t -> (string * float) option

(* the level ended (a changelevel touched); the secrets found, of how
 * many *)
val exited : t -> bool
val secrets : t -> int * int

(* the sounds made since the last call (a door's move and stop, a
 * button, a lift, a secret found, a message), and where (None: the
 * player's own); a mover's chosen by its "sounds" key, as QuakeC's *)
val sounds : t -> (string * Model.vec option) list

(* every sound the movers and triggers may make (precache) *)
val sound_names : string list
