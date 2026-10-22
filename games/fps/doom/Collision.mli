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
  blocker : Level.line option; (* the line that stopped it, or that set the room *)
  special_lines : Level.line list;
}

(* [check_position t x y] *)
val check_position : World.t -> float -> float -> position

(* [try_move cross t x y]: the player moved to (x, y) if it fits, and
 * each line with a special it crossed given to [cross]; else the line
 * in the way, if one is *)
val try_move : (Level.line -> unit) -> World.t -> float -> float -> bool * Level.line option

(* P_ChangeSector, P_ThingHeightClip: the player's floor and ceiling
 * again after a sector moved, the player on the floor going with it;
 * false if it no longer fits *)
val change_sector : World.t -> bool

(* P_UseLines: the line the use key acts on, if one is in reach *)
val use_target : World.t -> Level.line option
