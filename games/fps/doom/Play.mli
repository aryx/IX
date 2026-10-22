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
 * A line's special is what it does when it is used (the space key, the
 * nearest line within 64 ahead: DR doors, S switches) or crossed (W,
 * once; WR, again): a door's sector's ceiling goes up to its lowest
 * neighbour's less 4, waits 150 tics, comes down (EV_VerticalDoor,
 * T_VerticalDoor); a lift's floor down to its lowest neighbour's,
 * waits 105, up again (EV_DoPlat, T_PlatRaise); a switch's texture turns
 * (SW1 to SW2, P_ChangeSwitchTexture), and back after a second if it
 * can be used again. A sector's special is its light: flashes,
 * strobes, a glow, a flicker (P_SpawnSpecials, p_lights.c).
 *
 * What is not here: monsters, weapons and their shots, the things'
 * moves, health and damage (a
 * nukage floor hurts nobody), the keys' cards picked up but not drawn,
 * id's random numbers (a table of 256: these lights flicker by
 * another generator), the dropoff and the falls' damage.
 *
 * Where it stands in mini-doom: Doom.ml gives it the keys and asks it
 * where the eye is, for Render; it changes Level's sectors and sides in
 * place, which Render draws as they are. *)

type player = {
  mutable x : float;
  mutable y : float;
  mutable z : float; (* the feet *)
  mutable angle : float;
  mutable momx : float;
  mutable momy : float;
  mutable momz : float;
  mutable floorz : float; (* the highest floor under the box *)
  mutable ceilingz : float;
  mutable viewheight : float;
  mutable deltaviewheight : float;
  mutable viewz : float; (* the eye *)
  mutable bob : float;
  mutable turnheld : int;
  mutable keys : int list; (* the keys' things picked up: 5 blue, 6 yellow, 13 red, ... *)
}

(* a tic's command: forward and sideways (Doom's units: 25 a walk, 50 a
 * run; sideways 24 and 40), the turn (in 1/65536 of a turn: 640 a
 * walk, 1280 a run, the first tics of a turn 320), and use *)
type cmd = { forward : int; side : int; turn : int; use : bool }

type t = {
  level : Level.t;
  textures : Textures.t;
  player : player;
  things : Things.mobj list;
  by_sector : Things.mobj list array; (* the things by their sectors' numbers *)
  mutable tic : int;
  mutable thinkers : thinker list;
  mutable message : string; (* what the player is told, for some tics *)
  mutable message_tics : int;
  mutable exited : bool;
  mutable secrets : int; (* found *)
}

and thinker

(* [create level textures monsters]: the player at the level's start
 * (thing 1), the things spawned (the monsters, standing, if asked),
 * the sectors' lights started *)
val create : Level.t -> Textures.t -> bool -> t

(* [place t x y angle]: the player there, on the floor, still (a test's
 * camera, as the reference's: games/fps/doom/tests) *)
val place : t -> float -> float -> float -> unit

(* [tic t cmd]: a 35th of a second *)
val tic : t -> cmd -> unit

(* the keys held *)
type keys = { up : bool; down : bool; left : bool; right : bool; run : bool; strafe_left : bool; strafe_right : bool; use_key : bool }

(* the command from the keys held; [turnheld] counts the tics a turn
 * has been held (a turn starts slow) *)
val command : player -> keys -> cmd

(* the secrets of the level, all *)
val secrets_total : t -> int
