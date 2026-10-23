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

(* a picture of the player's hand (p_pspr.h's pspdef_t): its state,
 * the tics left, where (sx, sy: the weapon bobbing, raised, lowered) *)
type psprite = {
  mutable pstate : Info.state option;
  mutable ptics : int;
  mutable sx : float;
  mutable sy : float;
}

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
  (* d_player.h's player_t, its fight *)
  mutable health : int;
  mutable armor : int;
  mutable weapons : Info.weapon list; (* owned *)
  mutable readyweapon : Info.weapon;
  mutable pendingweapon : Info.weapon option; (* to change to *)
  mutable clips : int; (* bullets *)
  mutable shells : int;
  weapon_sp : psprite; (* the weapon in hand *)
  flash_sp : psprite; (* its muzzle's flash *)
  mutable attackdown : bool;
  mutable refire : int;
  mutable extralight : int; (* a shot's flash lights the level *)
  mutable damagecount : int; (* the screen red *)
  mutable bonuscount : int; (* the screen gold: an item *)
  mutable attacker : Things.mobj option; (* the last that hurt *)
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

(* a sound made: its name (Info.sounds'), from a place of the level (a
 * monster's, a door's), or from the player itself (None) *)
type sound = { sfx : string; origin : (float * float) option }

(* id's (P_NewChaseDir: towards the player, as the crow flies, another
 * way when blocked), or the playground's (Ai.flow: a way through the
 * level, around the walls: Enemy) *)
type ai = Id | Ways

type thinker = { mutable alive : bool; what : what }
and what = Door of door | Plat of plat | Floor of floor_move | Light of light | Button of button

type t = {
  level : Level.t;
  textures : Textures.t;
  player : player;
  mutable things : Things.mobj list;
  by_sector : Things.mobj list array; (* the things by their sectors' numbers *)
  mutable tic : int;
  mutable thinkers : thinker list;
  mutable message : string; (* what the player is told, for some tics *)
  mutable message_tics : int;
  mutable exited : bool;
  mutable secrets : int; (* found *)
  mutable kills : int;
  mutable sounds : sound list; (* made this tic, the last first *)
  ai : ai; (* how the monsters find their way *)
  heard : bool array; (* the sectors the player's shots were heard in *)
  mutable reborn : bool; (* dead, use pressed: the level again *)
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

(* [start_sound t origin sfx]: S_StartSound: [sfx] heard from there (a
 * thing's place, a sector's), or from the player (None); Doom.ml plays
 * them after the tic *)
val start_sound : t -> (float * float) option -> string -> unit

(* P_AproxDistance: dx + dy less half the smaller, id's distance
 * without a square root (8% too long at most) *)
val approx_distance : float -> float -> float

(* [add t what]: a thinker started, run from the next tic on *)
val add : t -> what -> unit
