(* Mobj: a thing that acts, its life a tic at a time (Doom's p_mobj.c):
 * its states gone through, its momentum, its fall; made, removed.
 *
 * P_MobjThinker each tic, for each thing that acts:
 *
 *   momentum?  P_XYMovement: moved by it, a missile exploding where it
 *              is stopped (a wall, a thing: Inter's damage)
 *   off the floor?  P_ZMovement: falls; a missile flies straight
 *   the state's tics run out?  P_SetMobjState: the next state, and its
 *              action done (Enemy's Look, Chase, ...), and the next if
 *              it lasts 0 tics
 *
 * A state's action is a function of id's (info.c's states point at
 * p_enemy.c's A_ functions); here [act] is filled by Enemy, which comes
 * after, as Doom's linker joins them.
 *
 * Where it stands in mini-doom: Play runs [think] for every thing that
 * acts; Inter changes a thing's state when it is hurt or dies; Enemy
 * spawns missiles, Inter the puffs and the blood. *)

(* the actions of the states, Enemy's *)
val act : (World.t -> Things.mobj -> Info.action -> unit) ref

(* [set_state t m name]: P_SetMobjState: false if the thing is no more
 * ("": S_NULL) *)
val set_state : World.t -> Things.mobj -> string -> bool

(* [spawn t info x y z]: P_SpawnMobj, in the level's things *)
val spawn : World.t -> Info.mobjinfo -> float -> float -> float -> Things.mobj

(* [spawn_item t doomednum x y]: an item dropped (a clip, a shotgun) *)
val spawn_item : World.t -> int -> float -> float -> unit

(* P_RemoveMobj *)
val remove : World.t -> Things.mobj -> unit

(* P_SpawnPuff, P_SpawnBlood: where a bullet hit a wall or a thing *)
val spawn_puff : World.t -> float -> float -> float -> unit
val spawn_blood : World.t -> float -> float -> float -> int -> unit

(* P_ExplodeMissile: stopped, its death states, its sound *)
val explode_missile : World.t -> Things.mobj -> unit

(* [think t hit m]: P_MobjThinker; [hit] what a missile does to what it
 * runs into (Inter's damage) *)
val think : World.t -> (Things.mobj -> Things.target -> unit) -> Things.mobj -> unit
