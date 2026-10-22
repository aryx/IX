(* Trace: a box moved through the level, where it stops (Quake's
 * world.c: SV_RecursiveHullCheck, SV_HullPointContents,
 * SV_ClipMoveToEntity).
 *
 * The player is a box of 32 by 32 by 56, and testing a box against
 * every wall is costly; qbsp made instead, besides the tree drawn,
 * trees of the same space with each wall pushed out by the box's
 * half-size (the hulls, Model's clipnodes). In hull 1 the player is a
 * point: its move is a segment, and where the segment first enters
 * solid space is where the box would touch a wall:
 *
 *      hull 0 (the walls)          hull 1 (pushed out by 16)
 *      |                           |   |
 *      |   [box]  ---> move        |   |  .  ---> the box's center,
 *      |                           |   |         a point
 *
 * The walk down the tree: a node whose plane the segment does not
 * cross sends it to one side; one it crosses splits it, the near half
 * first; the first solid leaf reached is the impact, the plane crossed
 * last its normal, the point put 1/32 of a unit back (DIST_EPSILON) so
 * that the next move does not start in the wall.
 *
 * A brush model (a door) is the same with its own hulls, the segment
 * moved by its origin. *)

type trace = {
  (* the part of the move made, 0 to 1 *)
  fraction : float;
  endpos : Model.vec;
  (* the plane hit: its normal, towards the mover *)
  normal : Model.vec;
  (* started in solid, all in solid *)
  startsolid : bool;
  allsolid : bool;
  (* what was hit: -1 the world, else the brush model's entity *)
  hit : int;
}

(* [move m hull_num start finish solids]: the move of a point of hull
 * hull_num (1: the player's) from start to finish, through the world
 * and the solid brush models given (their entity, their model, their
 * origin); the nearest impact *)
val move :
  Model.t ->
  int ->
  Model.vec ->
  Model.vec ->
  (int * int * Model.vec) list ->
  trace

(* [point_contents m p]: the contents at p in hull 0 *)
val point_contents : Model.t -> Model.vec -> Model.contents

(* [hull_check m hull_num headnode start finish]: one model's trace,
 * its points in its own space *)
val hull_check : Model.t -> int -> int -> Model.vec -> Model.vec -> trace
