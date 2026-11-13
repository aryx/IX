(* Collision detection, the narrow phase: do two placed hitboxes
 * overlap, and if so, how (see notes_2d_physics.md section 8)? The
 * tests go from the cheapest to the most general, each in its own
 * function; then [touching] and [contact] choose the right one for any
 * two hitboxes.
 *
 * Circles overlap when the distance between their centers is less than
 * the sum of their radii. Example: the centers (0, 0) and (30, 40) are
 * 50 apart. With radii 20 and 20 (a sum of 40), the circles are apart;
 * with 30 and 25 (55), they overlap by 5, with the normal (0.6, 0.8).
 *
 * Bounding boxes overlap when their x ranges overlap *and* their y
 * ranges do. The test is too coarse to decide a collision, but cheap
 * enough to rule most of them out first.
 *
 * Point in polygon: cast a ray from the point, to the right, and count
 * the edges it crosses; an odd count means inside (the Jordan curve
 * theorem; the even-odd rule of graphics/2d/Fill). It works for any
 * polygon, convex or not:
 *
 *        _____
 *       /     \___
 *      /   p ------|------>   one crossing: inside
 *      \          /
 *       \________/
 *
 * Segments: two segments cross when each one's ends are on opposite
 * sides of the other's line (the sign of a cross product, the same side
 * test as a triangle's edge functions in graphics/3d/Triangle). Two
 * polygons touch when an edge of one crosses an edge of the other, or
 * one is inside the other (then a corner of it is in the other).
 *
 * The separating axis theorem (SAT), for convex polygons: they don't
 * overlap exactly when some line separates them, and it's enough to try
 * the directions perpendicular to their edges. Project both on each
 * such axis: if their shadows don't overlap on one, they're apart;
 * otherwise the axis where they overlap the least gives the contact's
 * normal and depth. Example: the boxes [0, 2] x [0, 2] and [1, 3] x
 * [3, 4] overlap on the x axis ([0, 2] and [1, 3]) but not on the y
 * axis ([0, 2] and [3, 4]), so they are apart.
 *
 *      +----+                 on the y axis, their shadows
 *      | A  |   +----+        [0, 2] and [3, 4] don't overlap:
 *      +----+   | B  |        a separating axis
 *               +----+
 *
 * others:
 * (GJK -- Gilbert, Johnson, Keerthi, 1988 -- does it for any convex
 * shapes, curves included; Box2D and Bullet use it. It is not here:
 * circles against polygons have their own test below.)
 *
 * Where it stands: Broadphase says which pairs to bring here, Shape
 * places the hitboxes, and what comes out is a Contact for Resolve,
 * or, for Solver, a point for each touching corner. The tests
 * themselves are older than games and are all over ix under other
 * names: the crossings counted along a row are how Fill decides
 * which pixels a polygon covers, and the point in a box is a
 * widget's hit test (Widget's [contains]) and a page's (Hit). A
 * click is a collision between a point and some rectangles.
 *
 * terminology:
 * *Narrow phase*: the exact test of one pair, after the broad
 * phase's cheap sieve. *Manifold*: the set of points where two
 * shapes touch. A box lying on the floor touches along an edge, and
 * the solver wants its two ends, not one point in the middle, or the
 * box rocks.
 *
 * References: Christer Ericson, Real-Time Collision Detection, 2005
 * (all of it); Metanet Software's N tutorials, 2004 (SAT, for game
 * programmers); Gottschalk, Lin, Manocha, "OBBTree", SIGGRAPH 1996 (the
 * separating axis theorem in graphics). *)
(* ix: copied from libs/physics/2d/Collide.mli in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

(*****************************************************************************)
(* {1 The tests} *)
(*****************************************************************************)

(* the tests, each on its own *)

val circles : Vec2.t * float -> Vec2.t * float -> Contact.t option
val bounds_overlap : Vec2.t * Vec2.t -> Vec2.t * Vec2.t -> bool
val point_in_polygon : Vec2.t -> Vec2.t list -> bool
val segments_cross : Vec2.t * Vec2.t -> Vec2.t * Vec2.t -> bool

(* whether any two polygons, convex or not, touch: an edge crosses, or
 * one is inside the other *)
val polygons_touch : Vec2.t list -> Vec2.t list -> bool

(* two convex polygons: the separating axis theorem, with the contact.
 * Its point is the middle of the overlap region (the average of its
 * corners: the corners of each polygon inside the other, and where
 * their edges cross), where the rotation's lever arms start (Resolve).
 * A box landing on a corner is pushed at that corner, and tips; a box
 * landing flat is pushed at the middle of its bottom edge, and doesn't.
 *
 *      +--------+
 *      |  box   |
 *   ===x===*====x=====   floor: the overlap's corners (x) and
 *      +--------+           their middle (star), the contact point
 *
 * (Box2D keeps two points for an edge, by clipping one polygon's edge
 * against the other's; that gives steadier stacks, the plan's phase
 * 8.) *)
val sat : Vec2.t list -> Vec2.t list -> Contact.t option

(* whether a circle and a polygon (convex or not) touch: the center is
 * inside, or an edge is nearer than the radius *)
val circle_polygon : Vec2.t * float -> Vec2.t list -> bool

(* the same test with the contact, for a convex polygon; the normal goes
 * from the circle to the polygon *)
val circle_convex : Vec2.t * float -> Vec2.t list -> Contact.t option

(* [nearest_on_outline p corners]: the point of the polygon's outline
 * nearest to [p], which is where to push a point out of it
 * (Particles.keep_out) *)
val nearest_on_outline : Vec2.t -> Vec2.t list -> Vec2.t

(*****************************************************************************)
(* {1 Swept tests} *)
(*****************************************************************************)

(* The swept tests. A bullet at 1500 pixels per second moves 25 pixels
 * per step: a wall thinner than that can be jumped over between two
 * steps, never seen overlapping. This is tunneling (notes_2d_physics.md
 * section 12):
 *
 *          step n        step n+1
 *            o   |wall|    o          touching at neither step,
 *            *---|----|--->*          but the path crossed the wall
 *
 * The fix, in the simplest form of continuous collision detection, is
 * to test the path (the segment from the old position to the new one),
 * not the position. Example: for the square [0, 2] x [0, 2], the
 * segment from (-1, 1) to (3, 1) enters it at (0, 1), and the one from
 * (-1, 5) to (3, 5) misses it. *)

(* [segment_polygon (a, b) corners]: where segment ab first enters the
 * polygon ([a] if it starts inside), if it does *)
val segment_polygon : Vec2.t * Vec2.t -> Vec2.t list -> Vec2.t option

(* [segment_circle (a, b) (c, r)]: the segment's point nearest to the
 * circle's center, if within it *)
val segment_circle : Vec2.t * Vec2.t -> Vec2.t * float -> Vec2.t option

(*****************************************************************************)
(* {1 Hitboxes} *)
(*****************************************************************************)

(* for any two placed hitboxes *)

(* do they overlap? (the bounding boxes first, then the exact test) *)
val touching : Shape.placed -> Shape.placed -> bool

(* how they overlap, with the normal from the first to the second, for
 * points, circles and convex polygons. None when they don't overlap,
 * and for concave polygons (split them in convex pieces to get a
 * contact). *)
val contact : Shape.placed -> Shape.placed -> Contact.t option

(* [manifold a b]: the contact as up to two points, for stacking
 * (Solver.mli): a box lying on another touches it along an edge, and a
 * single point in the middle would balance it on a knife's edge. For
 * two convex polygons, the points are the corners of each inside the
 * other, each with its own depth along the normal; when there are more
 * than two (two boxes of the same width), they are the two farthest
 * apart:
 *
 *        +--------+
 *        |  box   |
 *     ===x========x===    the box's two bottom corners, inside the
 *        +--------+          floor: two points, 2 pixels deep each
 *
 * Otherwise (all the corners are outside, as for two thin bars crossed
 * like a +, or for circles), it is the one point of [contact]. Box2D
 * finds its two points by clipping one polygon's edge against the
 * other's sides (Catto, "Contact Manifolds", GDC 2007), which is
 * sturdier for deep overlaps; the corners inside give the idea in
 * fewer lines. *)
val manifold : Shape.placed -> Shape.placed -> Contact.t list
