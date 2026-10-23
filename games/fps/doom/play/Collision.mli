(* Collision: where the player can be (Doom's p_map.c, p_maputl.c). The
 * player is a box of 32 by 32, 56 high; a place is tried against the
 * lines near it, found by the blockmap, the level cut in cells of 128
 * by 128, each with the lines that cross it (Level):
 *
 *     +-------+-------+       the box (#) touches four cells; only
 *     |    ## | ##    |       their lines are tried, not the level's
 *     |    ## | ##    |       hundreds (P_CheckPosition's
 *     +-------+-------+       P_BlockLinesIterator)
 *     |    ## | ##    |
 *     +-------+-------+
 *
 * A line the box crosses (P_BoxOnLineSide: its corners on both sides)
 * stops it if it is one-sided or blocking; a two-sided one narrows the
 * room (P_LineOpening: the higher floor, the lower ceiling of its two
 * sectors). The place fits if the room is 56 high, under the ceiling,
 * and the floor at most a step of 24 above the feet (P_TryMove).
 *
 * Where it stands in mini-doom: Play's moves (P_XYMovement) try their
 * places here and Specials' sectors that move ask whether the player
 * still fits (change_sector). The things block too: a solid thing's box
 * (PIT_CheckThing). *)

(* P_BoxOnLineSide: 0 or 1 if the box (left, right, bottom, top) is all
 * on one side of the line, else -1 *)
val box_on_line_side : float -> float -> float -> float -> Level.line -> int

(* what P_CheckPosition finds for the box at (x, y) *)
type position = {
  ok : bool;
  pfloorz : float;
  pceilingz : float;
  pdropoffz : float; (* the lowest floor under the box *)
  blocker : Level.line option; (* the line that stopped it, or that set the room *)
  special_lines : Level.line list;
  hit : Things.target; (* a missile's: what it ran into *)
}

(* [check_position t who x y]: the player's box there, or a thing's; a
 * thing's stopped by the player too, and by the lines that block the
 * monsters (ML_BLOCKMONSTERS); a missile's by no line that is open,
 * and by what it can hit, not its shooter *)
val check_position : World.t -> Things.target -> float -> float -> position

(* [try_move cross t x y]: the player moved to (x, y) if it fits, and
 * each line with a special it crossed given to [cross]; else the line
 * in the way, if one is *)
val try_move : (Level.line -> unit) -> World.t -> float -> float -> bool * Level.line option

(* [set_position t m x y]: P_SetThingPosition: the thing there, and in
 * its sector's list *)
val set_position : World.t -> Things.mobj -> float -> float -> unit

(* [try_move_thing t m x y]: P_TryMove for a thing: moved if it fits
 * (the room, a step of 24, a monster no drop of more than 24); and the
 * position found *)
val try_move_thing : World.t -> Things.mobj -> float -> float -> bool * position

(* P_ChangeSector, P_ThingHeightClip: the player's floor and ceiling
 * again after a sector moved, the player on the floor going with it,
 * the things' too; false if one no longer fits (a corpse does) *)
val change_sector : World.t -> bool

(* P_UseLines: the line the use key acts on, if one is in reach *)
val use_target : World.t -> Level.line option

(* the lines of the blockmap's cells a segment goes through *)
val lines_along : World.t -> float -> float -> float -> float -> Level.line list

(* P_LineOpening: a two-sided line's room, its higher floor and lower
 * ceiling; None for a wall *)
val opening : World.t -> Level.line -> (float * float) option

(* [check_sight t x1 y1 z1 x2 y2 z2 h2]: P_CheckSight: from the eye at
 * (x1, y1, z1), some of the box at (x2, y2) from z2 up h2 seen through
 * the openings between (the slopes to its top and bottom narrowed at
 * each) *)
val check_sight :
  World.t -> float -> float -> float -> float -> float -> float -> float ->
  bool

(* what a shot's line meets: a line, a thing, the player, at a fraction
 * of the way *)
type intercept =
  | Line of float * Level.line
  | Thing_hit of float * Things.mobj
  | Player_hit of float

val fraction : intercept -> float

(* [intercepts t shooter x1 y1 x2 y2]: P_PathTraverse's: the lines
 * across and the shootable things the line goes through (their nearest
 * point within their radius), not the shooter; the nearest first *)
val intercepts :
  World.t -> Things.target -> float -> float -> float -> float ->
  intercept list
