(* Info: what each thing that acts is, as tables (Doom's info.c,
 * d_items.c, sounds.c): the states its pictures go through, its
 * numbers (health, speed, the sounds it makes), the player's weapons.
 *
 * A state is a picture shown for some tics, an action done when it
 * starts, and the state after it: a monster's whole life is a few
 * loops of states, the actions doing the thinking (A_Look, A_Chase:
 * Enemy) and the attacking.
 *
 *   POSS_STND (A, 10 tics, Look) <-> POSS_STND2 (B, 10, Look)
 *        | Look sees the player: the seestate
 *        v
 *   POSS_RUN1 .. RUN8 (A A B B C C D D, 4 tics each, Chase) -- a loop
 *        | Chase: in range, and lucky       | shot (pain chance)
 *        v                                  v
 *   POSS_ATK1 (E, FaceTarget)           POSS_PAIN (G) --> RUN1
 *   POSS_ATK2 (F, PosAttack) -> ATK3 -> RUN1
 *        | its health at 0
 *        v
 *   POSS_DIE1 .. DIE5 (H .. L; Scream, Fall), the last for ever (-1)
 *
 * id's table has 967 states and 137 kinds of things; here those of the
 * monsters of Doom's first episode's first levels (the zombieman, the
 * shotgun guy, the imp and its fireball, the demon), the barrel, the
 * puffs and the blood, and the player's fist, pistol, shotgun and
 * chainsaw. A state is named as id's enum is, less its S_
 * (POSS_STND); "" is S_NULL, the thing removed.
 *
 * Where it stands in mini-doom: Things spawns a thing with its info,
 * Mobj runs its states, Enemy, Weapons and Inter do their actions;
 * Mkwad asks [sounds] and [sprites] what to put in the WAD. *)

(* the actions of the states (id's A_ functions), done by Mobj's [act]:
 * Enemy's for the monsters, Weapons' for the player's psprites *)
type action =
  | Nothing
  (* the monsters' (p_enemy.c) *)
  | Look
  | Chase
  | Face_target
  | Pos_attack
  | SPos_attack
  | Troop_attack
  | Sarg_attack
  | Pain
  | Scream
  | XScream
  | Fall
  | Explode
  (* the weapons' (p_pspr.c) *)
  | Weapon_ready
  | Lower
  | Raise
  | Punch
  | Fire_pistol
  | Fire_shotgun
  | Saw
  | Refire
  | Light0
  | Light1
  | Light2

type state = {
  sname : string;
  sprite : string; (* its four letters, POSS *)
  frame : int; (* the letter: 0 is A *)
  bright : bool; (* drawn at full light (id's FF_FULLBRIGHT) *)
  tics : int; (* -1: for ever *)
  action : action;
  next : string;
}

(* [state name]: POSS_STND's; "" has none *)
val state : string -> state option

(* the flags of a thing (p_mobj.h's MF_): what it is, and what happens
 * to it *)
val solid : int
val shootable : int
val noblockmap : int (* not collided with *)
val ambush : int (* deaf: waits to see (the map's flag) *)
val justhit : int (* hurt: answers at once *)
val justattacked : int (* attacked: moves before attacking again *)
val nogravity : int
val dropoff : int
val missile : int
val noblood : int
val corpse : int
val countkill : int

type mobjinfo = {
  doomednum : int; (* -1: never in a map *)
  spawnstate : string;
  spawnhealth : int;
  seestate : string;
  seesound : string; (* a sound's name, less DS: "posit1"; "" none *)
  reactiontime : int;
  attacksound : string;
  painstate : string;
  painchance : int; (* of 256 *)
  painsound : string;
  meleestate : string;
  missilestate : string;
  deathstate : string;
  xdeathstate : string; (* gibbed *)
  deathsound : string;
  speed : float; (* a step a move (a monster), units a tic (a missile) *)
  radius : float;
  height : float;
  mass : int;
  damage : int; (* a missile's *)
  activesound : string;
  flags : int;
}

(* the kind of a map's thing, if it acts *)
val of_doomednum : int -> mobjinfo option

(* the things that are not in a map: the imp's fireball, a puff, blood *)
val troopshot : mobjinfo
val puff : mobjinfo
val blood : mobjinfo

(* d_items.c's weaponinfo: what a weapon shoots (None: nothing to run
 * out of) and its states *)
type weapon = Fist | Pistol | Shotgun | Chainsaw

type ammo = Clip | Shell

type weaponinfo = {
  ammo : ammo option;
  upstate : string;
  downstate : string;
  readystate : string;
  atkstate : string;
  flashstate : string;
}

val weaponinfo : weapon -> weaponinfo

(* every sound a state, a thing or a weapon makes (DS less), for Mkwad *)
val sounds : string list

(* every sprite the states draw, for Mkwad *)
val sprites : string list

(* p_random: id's numbers, 0 to 255, a table of 256 gone through in
 * turn (m_random.c's rndtable): the same game for the same moves, as a
 * demo is replayed *)
val p_random : unit -> int

(* P_Random () - P_Random (): -255 to 255, mostly near 0 *)
val p_random2 : unit -> int
