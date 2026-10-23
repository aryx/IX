(* Play: the world moving, a tic (1/35 s) at a time, Doom's p_*.c for a
 * player alone in a level: the walk, the walls, the steps, the doors,
 * the lifts, the lights that flicker, the switches, the exit.
 *
 * A tic is the player's command (G_BuildTiccmd: forward, sideways, the
 * turn, use), then the player (P_PlayerThink), then everything else
 * that moves (P_RunThinkers: a door, a lift, a light; id's "thinkers",
 * a function called each tic until it removes itself):
 *
 *   the command          the momentum           the move
 *   forward 25 (walk)    += 25/32 a tic along    the box of 32 by 32
 *   50 (run)             the angle (P_Thrust),   tried at its new place
 *                        then * 0.90625 on the   (P_TryMove): every line
 *                        ground (FRICTION):      of the blockmap's cells
 *                        8 units a tic at most   it touches; a wall, or
 *                        walking                 a step over 24, or less
 *                                                than 56 to stand: no.
 *                                                Along the wall then
 *                                                (P_SlideMove's idea)
 *
 * The eye is 41 above the feet (VIEWHEIGHT), bobs with the speed, and
 * a step up is climbed at once by the feet and smoothly by the eye
 * (P_CalcHeight's deltaviewheight).
 *
 * Its parts are id's files: World (the state, the thinkers), Collision
 * (p_map.c: where the player can be), Specials (p_spec.c and the
 * others: what the lines and the sectors do), and this one, p_user.c
 * (the player), p_tick.c (the tic) and g_game.c's G_BuildTiccmd.
 *
 * Then the weapon in hand (Weapons), every thing that acts (Mobj's
 * P_MobjThinker: the monsters, their fireballs, the puffs), the items
 * picked up (Inter). Dead, the player's eye sinks to the floor, turned
 * to its killer, until use is pressed (P_DeathThink).
 *
 * What is not here: the keys' cards picked up but not drawn, the
 * dropoff and the falls' damage, the floors that hurt.
 *
 * Where it stands in mini-doom: Doom.ml gives it the keys and reads the
 * eye from its World, for Render; it changes Level's sectors and sides
 * in place, which Render draws as they are. *)

(* a tic's command: forward and sideways (Doom's units: 25 a walk, 50 a
 * run; sideways 24 and 40), the turn (in 1/65536 of a turn: 640 a
 * walk, 1280 a run, the first tics of a turn 320), and use *)
type cmd = {
  forward : int;
  side : int;
  turn : int;
  use : bool;
  attack : bool;
  change : Info.weapon option; (* the weapon asked for *)
}

(* [create level textures monsters ai]: the player at the level's
 * start (thing 1), with a pistol and 50 bullets, the things spawned
 * (the monsters if asked), the sectors' lights started *)
val create : Level.t -> Textures.t -> bool -> World.ai -> World.t

(* [place t x y angle]: the player there, on the floor, still (a test's
 * camera, as the reference's: games/fps/doom/tests) *)
val place : World.t -> float -> float -> float -> unit

(* [tic t cmd]: a 35th of a second *)
val tic : World.t -> cmd -> unit

(* the keys held *)
type keys = {
  up : bool;
  down : bool;
  left : bool;
  right : bool;
  run : bool;
  strafe_left : bool;
  strafe_right : bool;
  use_key : bool;
  fire : bool;
  number : int; (* a weapon's key, 1 to 4; 0 none *)
}

(* the command from the keys held; [turnheld] counts the tics a turn
 * has been held (a turn starts slow) *)
val command : World.player -> keys -> cmd

(* the secrets of the level, all *)
val secrets_total : World.t -> int
