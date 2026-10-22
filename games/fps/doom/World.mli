(* World: the state of the play, all that moves in a level (Doom's
 * d_player.h, p_spec.h, p_local.h and p_tick.c's thinkers): the
 * player, the level whose sectors and sides it changes in place, the
 * things, and the thinkers.
 *
 * A thinker is id's way of a thing that goes on by itself: a door
 * opening, a lift, a light that flickers, a switch that turns back. It
 * is put in the list when it starts (a line used, a sector's special
 * at the start) and run each tic (P_RunThinkers) until it says it is
 * done; a sector has at most one moving it (id's specialdata: busy).
 *
 *   t.thinkers:  Door (sector 12, up)  Light (sector 3, Flicker)  ...
 *                     |                       |
 *                each tic: Specials.think, until alive is false
 *
 * Where it stands in mini-doom: Play makes one (create) and runs it a
 * tic at a time; Collision says where its player can be, Specials what
 * its lines and thinkers do; Doom.ml reads the player's eye and the
 * level from it for Render. *)

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

(* a door: up to its top, then waiting, then down (dir 1, 0, -1) *)
type door_kind = Raise (* and close after *) | Open | Close

type door = {
  dsector : Level.sector;
  dkind : door_kind;
  mutable ddir : int;
  topheight : float;
  dspeed : float;
  mutable dcount : int;
}

(* a lift: down, waiting, up (status -1, 0, 1); done at its top *)
type plat = { psector : Level.sector; low : float; high : float; pspeed : float; mutable status : int; mutable pcount : int }

type floor_move = { fsector : Level.sector; dest : float; fspeed : float; fdir : int }

type light_kind = Flash | Strobe | Glow | Flicker

type light = {
  lsector : Level.sector;
  lkind : light_kind;
  minlight : int;
  maxlight : int;
  darktime : int;
  brighttime : int;
  mutable lcount : int;
  mutable gdir : int;
}

(* a switch that turns back: which of its side's textures, to what *)
type button = { bside : Level.side; where : int (* 0 top, 1 middle, 2 bottom *); texture : int; mutable btimer : int }

type thinker = { mutable alive : bool; what : what }
and what = Door of door | Plat of plat | Floor of floor_move | Light of light | Button of button

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

(* p_local.h and d_player.h's numbers: the player's box (a radius of 16,
 * 56 high), its eye (41 above its feet), the highest step (24), the
 * friction a tic, the momentum's least and most, the use key's reach,
 * the bob's most *)
val radius : float
val height : float
val viewheight : float
val maxstep : float
val friction : float
val stopspeed : float
val maxmove : float
val userange : float
val maxbob : float
val pi : float

(* the lights' random numbers, 0 to 255: Lehmer's generator, as the
 * playground's (id's is a table of 256, M_Random) *)
val random : unit -> int

(* [say t msg]: told to the player, for 4 seconds *)
val say : t -> string -> unit

(* the sectors across the two-sided lines of a sector *)
val neighbours : t -> Level.sector -> Level.sector list

(* P_FindLowestCeilingSurrounding, P_FindLowestFloorSurrounding (the
 * sector's own included), P_FindMinSurroundingLight (from a most) *)
val lowest_ceiling : t -> Level.sector -> float
val lowest_floor : t -> Level.sector -> float
val min_light : t -> Level.sector -> int -> int

(* the sectors of a tag (a line's special acts on them) *)
val tagged : t -> int -> Level.sector list

(* the thinker that moves a sector already, if one does *)
val busy : t -> Level.sector -> thinker option

(* [add t what]: a thinker started, run from the next tic on *)
val add : t -> what -> unit
