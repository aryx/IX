(* Course: a circuit of Virtua Racing's, its road, its land and what
 * stands on them, made into meshes at its start.
 *
 * A course is written on the squares of its map -- the course select's
 * maps of the Mega Drive version's manual, traced -- one square 40
 * metres, x to the right and y down the map (+z: a heading of 0 is up
 * the map): the points the middle of the road goes through, each with
 * its height. Track3d walks them into a ribbon; each corner leans into
 * itself, the bank read from how much the course turns there. Then:
 *
 *   the road     a segment every 2 m: kerbs, tarmac, the line, the
 *                grass verges, the rail, the embankment's sides
 *                (or a wall, a bridge's deck, a tunnel), with the
 *                trees and signs along it; cut in chunks of 40
 *                segments, a mesh each
 *   the land     Land's grid, its tiles a mesh each
 *   landmarks    the start (its chequers, gantries, grandstand), the
 *                amusement park: a mesh each
 *   what moves   the Ferris wheel: shapes made again at each frame
 *
 *       chunk k-1     chunk k        chunk k+1
 *   ===|=========|==============|==========|===   the road, its
 *                     ^ the car                   chunks drawn from
 *                                                 the car's, 7 ahead,
 *                                                 and any near the eye
 *
 * Where it stands: the game (Virtua) makes a course at its start, then
 * draws at each frame the chunks and tiles near the eye ([road_near],
 * [land_near]), the landmarks, what moves, and the sky ([sky]); Cars
 * stand on its road.
 *
 * What is ours: TinyVirtuaRacing's courses, written as there (its
 * functions' names, its numbers); one course for now, Big Forest
 * (plan_virtuaracing.md: the other two at stage 3, TinyOutRun's coast
 * later). *)

val road_width : float

(* the land beside the road, below it: the road on its embankment *)
val ground : float

(* the verges' outer edge, where the rail stands *)
val verge : float

(* degrees from [a] to [b], the short way round *)
val angle_diff : float -> float -> float

type span_kind = Suspension | Overpass | Tunnel | Wall
type span = { kind : span_kind; s0 : float; s1 : float }

(* a chunk of the road, or a tile of the land, and its middle (x, z) *)
type piece = { mesh : Mesh.t; mx : float; mz : float }

type t = {
  name : string;
  level : string; (* BEGINNER, MEDIUM, EXPERT *)
  ribbon : Track3d.t;
  laps : int;
  checkpoints : int; (* a lap's, the line one of them, evenly spaced *)
  start_time : int; (* seconds on the clock at the start *)
  bonus : int; (* the seconds each checkpoint adds *)
  rivals : int;
  spans : span list;
  terrain : Land.t;
  grass : Mesh.color * Mesh.color; (* the verges, light and dark *)
  chunks : piece array;
  tiles : piece array;
  landmarks : Mesh.t list;
  (* what moves, at a time in seconds *)
  animated : float -> Mesh.shape list;
}

val big_forest : unit -> t

(* [road_near c s eye]: the chunks around the car, at [s] along the
 * lap, and any near the eye (an overpass, the other side of a
 * hairpin) *)
val road_near : t -> float -> Vec3.t -> Mesh.t list

(* [land_near c eye]: the land's tiles within sight of the eye *)
val land_near : t -> Vec3.t -> Mesh.t list

(* [sky c camera]: the sky, the haze and the floor, around the eye *)
val sky : t -> Camera.t -> Mesh.shape

(* every mesh that does not move, for the palette (Palette.add_mesh) *)
val meshes : t -> Mesh.t list
