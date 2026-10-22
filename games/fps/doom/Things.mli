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
 * cycles through (a torch's flame, a monster breathing), bright or not,
 * and its size. A monster stands; none moves, attacks or dies.
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

type mobj = {
  mx : float;
  my : float;
  mutable mz : float;
  mangle : float;
  kind : info;
  sector : Level.sector;
  phase : int; (* where in its frames it starts *)
  mutable alive : bool;
}

(* [spawn level monsters]: the things of the medium skills (Hurt me
 * plenty), single player, with the monsters or not *)
val spawn : Level.t -> bool -> mobj list

(* a sprite's frame: its picture for each of the 8 rotations, and
 * whether it is mirrored *)
type frame = { lumps : string array; flip : bool array; rotates : bool }

type sprites

(* the sprites of a WAD *)
val load : Wad.t -> sprites

(* [frame sprites mobj tic]: the frame a thing shows at that tic, and
 * whether it is bright; None if the WAD has not its pictures *)
val frame : sprites -> mobj -> int -> (frame * bool) option
