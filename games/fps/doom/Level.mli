(* Level: one map of a WAD (E1M1, MAP01), its lumps read into records:
 * the floor plan an editor drew, and what the node builder made of it.
 *
 *   what the designer drew                  what the node builder adds
 *   VERTEXES  points                        SEGS      the lines cut where
 *   LINEDEFS  lines between two, a side          a partition crossed them,
 *             or two                            each the side of one
 *   SIDEDEFS  a line's face: its three      SSECTORS  convex pieces of a
 *             textures, its sector                  sector: a run of segs
 *   SECTORS   a floor and a ceiling: their  NODES     the BSP tree: a line
 *             heights, flats, the light             that splits, a box a
 *   THINGS    the player, the monsters, ...         side, two children
 *                                           BLOCKMAP  the lines in each cell
 *                                                   of 128 by 128, for
 *                                                   the collisions
 *                                           REJECT    who can see whom (not
 *                                                   read: no monsters)
 *
 *   a sector seen from above, two subsectors, the node between:
 *
 *        v0 +-----------+ v1      the line v0-v1 is one-sided (a wall);
 *           |    \      |         the node's partition (\) cuts the
 *           | 1   \  2  |         square into two convex pieces, and
 *           |      \    |         the line v3-v0 into two segs, one
 *        v3 +-------\---+ v2      in each
 *
 * A map's unit is a pixel of a texture: a door is 128 wide, the player
 * 56 tall, his eyes at 41. Angles are radians, counter-clockwise from
 * the x axis (east); the WAD's are id's binary angles (65536 a turn),
 * turned into radians when read.
 *
 * Where it stands in mini-doom: what Render draws (the nodes, the segs,
 * the sectors' heights) and what Play moves in and changes (a door's
 * ceiling, a switch's texture); Textures names the textures and flats
 * by their numbers. *)

type vertex = { x : float; y : float }

type sector = {
  index : int; (* its number in the level *)
  mutable floor : float;
  mutable ceiling : float;
  mutable floorpic : int; (* a flat's number (Textures) *)
  ceilingpic : int;
  mutable light : int; (* 0 to 255 *)
  mutable special : int;
  tag : int;
  mutable lines : int list; (* the lines that border it *)
}

type side = {
  xoffset : float;
  yoffset : float;
  (* the textures' numbers, -1 for none ("-") *)
  mutable top : int;
  mutable bottom : int;
  mutable middle : int;
  sector : int;
}

type line = {
  v1 : vertex;
  v2 : vertex;
  flags : int;
  mutable special : int;
  tag : int;
  front : int; (* its sides' numbers: the right one, as v1 to v2 goes *)
  back : int option;
}

(* the flags of a line that Render and Play read *)
val blocking : int (* the player cannot cross it, two-sided or not *)
val two_sided : int
val upper_unpegged : int (* an upper texture hangs from the top *)
val lower_unpegged : int (* a lower or one-sided one from the ceiling *)

type seg = {
  sv1 : vertex;
  sv2 : vertex;
  angle : float; (* of v1 to v2 *)
  seg_line : int;
  seg_side : int; (* the line's side it is on: 0 its front, 1 *)
  offset : float; (* from the line's start: the texture's first column *)
  side : side;
  front_sector : sector;
  back_sector : sector option;
}

type subsector = { first : int; count : int; sub_sector : sector }

type child = Node of int | Subsector of int

type node = {
  nx : float;
  ny : float;
  ndx : float;
  ndy : float;
  (* each child's box: top, bottom, left, right *)
  boxes : float array array;
  children : child array; (* the front's, then the back's *)
}

type thing = { tx : float; ty : float; tangle : float; kind : int; tflags : int }

type blockmap = { originx : float; originy : float; columns : int; rows : int; cells : int array array }

type t = {
  name : string;
  vertexes : vertex array;
  sectors : sector array;
  sides : side array;
  lines : line array;
  segs : seg array;
  subsectors : subsector array;
  nodes : node array;
  things : thing array;
  blockmap : blockmap;
}

(* [load wad name texture flat]: the map [name] of [wad], a texture's
 * name made its number by [texture] (-1 for "-" or one unknown), a
 * flat's by [flat]; Failure if the map is not there *)
val load : Wad.t -> string -> (string -> int) -> (string -> int) -> t

(* the maps of a WAD, in its order: E1M1 ..., MAP01 ... *)
val maps : Wad.t -> string list

(* [root level]: the tree's root, the last node (a map of one subsector
 * has none) *)
val root : t -> child

(* [point_on_side x y node]: 0 if the point is on the node's front
 * (right) side, else 1 (R_PointOnSide) *)
val point_on_side : float -> float -> node -> int

(* [side_of x y ox oy dx dy]: the same of the line through (ox, oy)
 * along (dx, dy) (a seg's: R_PointOnSegSide) *)
val side_of : float -> float -> float -> float -> float -> float -> int

(* the same of a line: 0 on its front (right) side (P_PointOnLineSide) *)
val point_on_line_side : float -> float -> line -> int

(* [sector_at level x y]: the sector under the point, down the tree
 * (R_PointInSubsector) *)
val sector_at : t -> float -> float -> sector

(* [line_sector level line k]: the sector of the line's side k (0 front,
 * 1 back) *)
val line_sector : t -> line -> int -> sector option
