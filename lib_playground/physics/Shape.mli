(* Hitboxes: the shape a body has for collisions (see
 * notes_2d_physics.md section 8). A hitbox is often simpler than
 * what's drawn (a circle for a ball, a box for a crate), because the
 * tests between simple shapes are cheap, and exact.
 *
 *     Point      Circle r      Box (w, h)       Polygon [corners]
 *       .         .---.        +--------+           /\
 *                (  o  )       |   o    |          /  \___
 *                 '---'        +--------+         /   o   |
 *                                                 \_______|
 *
 * A hitbox is described around its body's center (o); [place] puts it
 * in the world, at a position and an angle, where the tests happen
 * (Collide). Once placed, a box is just a polygon of 4 corners: the
 * tests only know points, circles, and polygons.
 *
 * Polygons can be convex or not (an asteroid, a U). The general tests
 * handle both; the separating axis theorem, which is faster and gives
 * a contact, needs convex ones (see [convex] and Collide.mli). *)
(* ix: copied from libs/physics/2d/Shape.mli in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

type t =
  | Point
  | Circle of float (* radius *)
  | Box of float * float (* width, height, centered *)
  | Polygon of Vec2.t list (* the corners, around the center, in order *)

(* a hitbox placed in the world *)
type placed =
  | Point_at of Vec2.t
  | Circle_at of Vec2.t * float (* center, radius *)
  | Polygon_at of Vec2.t list (* corners, in world coordinates *)

(* [place ~angle ~scale pos t]: [t] turned by [angle] (radians,
 * counterclockwise), scaled, and moved to [pos] (in that order) *)
val place : angle:float -> scale:float -> Vec2.t -> t -> placed

(* the corners of a [w] x [h] box around (0, 0), counterclockwise from
 * the bottom left *)
val box_corners : float -> float -> Vec2.t list

(* a polygon's edges: each corner paired with the next, and the last
 * with the first *)
val edges : Vec2.t list -> (Vec2.t * Vec2.t) list

(* the area: pi r^2 for a circle, w h for a box, and for a polygon the
 * shoelace formula (half the sum of the cross products of consecutive
 * corners). Example: the box (4, 2) and the polygon [(0,0); (4,0);
 * (4,2); (0,2)] both have area 8. *)
val area : t -> float

(* [moments h]: the area of a hitbox and its polar second moment
 * around (0, 0) (the sum of r^2 over its area, where r is the distance
 * to (0, 0)), for placing it around its body's center. The moment of
 * inertia of a body of mass m made of hitboxes h1, h2, ... is m (J1 +
 * J2 + ...) / (A1 + A2 + ...), with its mass spread evenly. A polygon's
 * moment is summed over the triangles from (0, 0) to each edge (like
 * the shoelace formula); a circle's is pi r^4 / 2 at its center, plus
 * A d^2 away from it (the parallel axis theorem, Huygens-Steiner).
 * Examples: a disk of radius r gives I = m r^2 / 2, and a w x h box
 * gives m (w^2 + h^2) / 12 (5 for a 4 x 2 box of mass 3). *)
val moments : placed -> float * float

(* the axis-aligned bounding box, (min corner, max corner): the cheap
 * test before the exact ones *)
val bounds : placed -> Vec2.t * Vec2.t

(* whether a polygon is convex, that is, whether all its turns go the
 * same way. Example: a square is; an arrowhead [(0,0); (4,2); (0,4);
 * (1,2)] isn't. *)
val convex : Vec2.t list -> bool
