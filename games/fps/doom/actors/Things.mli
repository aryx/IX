(* Things: what stands in a level besides its walls -- a barrel, a lamp,
 * a key, a body, a monster -- and the pictures it is drawn with (Doom's
 * info.c, r_things.c's R_InitSprites, p_mobj.c's P_SpawnMapThing).
 *
 * A thing of the map (THINGS) is a type number, the editor's
 * (doomednum: 2035 a barrel, 3001 an imp), a place, an angle, and the
 * skills and modes it is in. Its type says, in id's info.c, its first
 * state (its sprite, a frame, how many tics) and what it is (its
 * radius, its height, solid, hanging from the ceiling, a monster).
 * Here only what a thing standing needs: its sprite, the frames it
 * cycles through (a torch's flame, a lamp), bright or not, and its
 * size. A thing that acts -- a monster, a barrel, a fireball -- has
 * besides its info's states (Info), its health, its momentum, its
 * target: id's mobj_t.
 *
 * A sprite is four letters (BAR1, POSS), its pictures lumps between
 * S_START and S_END named by a frame letter and a rotation:
 *
 *   BAR1A0     frame A, the same from every side (0)
 *   POSSA1     frame A seen from the front (1) ... from behind (5)
 *   POSSA2A8   frame A from the front left (2), and mirrored, from the
 *              front right (8): one picture for two rotations
 *
 * The rotation seen is the angle from the eye to the thing less the
 * thing's own, in eighths of a turn (R_ProjectSprite).
 *
 * Where it stands in mini-doom: Play spawns the things of the level
 * (the skill's, the monsters' if asked) and takes the keys the player
 * walks on; Render draws them; Mkwad asks [sprite_names] which
 * pictures of Freedoom's a level needs. *)

type info = {
  doomednum : int;
  sprite : string;
  frames : (char * bool) array; (* the frames' letters, in turn, and bright or not *)
  tics : int; (* each frame's *)
  radius : float;
  height : float;
  solid : bool;
  hanging : bool; (* at the ceiling, less its height *)
  monster : bool;
}

val info : int -> info option

(* every sprite a thing of these types is drawn with *)
val sprite_names : int list -> string list

(* a thing of the level: one standing (its [kind]'s frames, in turn), or
 * one that acts (an [actor], its frames its states', Mobj runs them:
 * id's mobj_t); and what the shots make (a puff, blood, a fireball), or
 * a monster drops, which no map has *)
type mobj = {
  mutable mx : float;
  mutable my : float;
  mutable mz : float;
  mutable mangle : float;
  kind : info;
  mutable sector : Level.sector;
  phase : int; (* where in its frames it starts *)
  mutable alive : bool; (* false: no more, and not drawn *)
  (* what an actor has besides *)
  actor : Info.mobjinfo option;
  mutable state : Info.state option;
  mutable stics : int; (* the tics left in the state *)
  mutable health : int;
  mutable flags : int; (* Info's solid, shootable, ... *)
  mutable momx : float;
  mutable momy : float;
  mutable momz : float;
  mutable floorz : float;
  mutable ceilingz : float;
  mutable target : target;
  mutable movedir : int; (* 0 east, 1 north-east, ... 7; 8 none *)
  mutable movecount : int; (* steps before a new direction *)
  mutable reactiontime : int; (* tics before attacking *)
  mutable threshold : int; (* tics of chasing the one that hurt it *)
  mutable seen_for : int; (* tics it has seen its target (Ai.aim_error) *)
}

(* what a monster is after (id's target, a mobj: here the player is not
 * one) *)
and target = Nobody | The_player | Thing of mobj

(* its box: an actor's info's, else its kind's *)
val radius : mobj -> float
val height : mobj -> float

(* [spawn level monsters]: the things of the medium skills (Hurt me
 * plenty), single player, with the monsters or not *)
val spawn : Level.t -> bool -> mobj list

(* [make info actor x y z sector]: a thing made during the play (a puff,
 * a fireball, a clip dropped) *)
val make :
  info -> Info.mobjinfo option -> float -> float -> float -> Level.sector ->
  mobj

(* a sprite's frame: its picture for each of the 8 rotations, and
 * whether it is mirrored *)
type frame = { lumps : string array; flip : bool array; rotates : bool }

type sprites

(* the sprites of a WAD *)
val load : Wad.t -> sprites

(* [find sprites "PISGA"]: a sprite's frame, by its name and letter *)
val find : sprites -> string -> frame option

(* [frame sprites mobj tic]: the frame a thing shows at that tic, and
 * whether it is bright; None if the WAD has not its pictures *)
val frame : sprites -> mobj -> int -> (frame * bool) option
