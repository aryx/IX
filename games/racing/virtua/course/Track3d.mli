(* A circuit in space: a closed line through the middle of a road,
   which has a width, a height and a lean at every point, turned into a
   ribbon of quads.

   Where gamekits/racing/Road.mli describes a course as a *list of
   segments* read as the car advances -- the way the arcade's pseudo-3D
   racers did, and what TinyOutRun and TinyVirtuaRacing
   drive on -- this one describes it as a *shape in space*, which is
   what a polygon racer with hills and banked corners needs:

     Road.t              a table: curve 2, hill 20, straight, ...
                         the road never really turns; the drawing does

     Track3d.t           a closed line through points in space, each
                         with its width and its bank; the road turns,
                         climbs and leans, and you can stand anywhere
                         and look at it

   A course is written as a handful of control points, and the line
   through them is a Catmull-Rom spline (Edwin Catmull and Raphael Rom,
   1974), which has the property that matters here: it passes *through*
   its control points, so a course is drawn by saying where the road
   goes, not by guessing at weights. The spline is then resampled at
   even distances, so that a segment is the same length everywhere and
   "how far along" is a distance in world units, not a parameter.

   Everything a game asks is in terms of that distance [s] along the
   middle, and an [offset] across it (positive to the right of the way
   it is driven):

                    offset < 0     |     offset > 0
                                   |
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~+~~~~~~~~~~~~~~~~~~~~~~~~~   the middle
             s = 0           s = 100          s = 200            [at]
        <--- width ---><--- width --->

   so that the road's surface is [across], the whole of a kart's
   position is (s, offset), an item box stands at (s, offset), the
   traffic's lane is a constant offset, "am I on the road" is
   |offset| < width, and the lap is s / [length]. [locate] is the way
   back: a point in the world to (s, offset).

   The lean ([bank], degrees) tilts the ribbon around its own middle,
   so the outside of a banked corner is *higher* than the inside, and a
   kart drawn at its offset stands on the slope. It is what lets a toy
   have Suzuka's 130R or Wario Stadium's walls without any physics:
   nothing here pushes a car into the corner, it only puts the road
   where the eye expects it (an exercise: let the bank pull the car,
   which is the whole of a banked corner in a real game).

   In the playground, part of the racing kit (gamekits/racing/, beside
   Road.mli). Here, mini-virtuaracing's: the courses (Course) are
   written as its controls, and the road's faces are its strips and
   walls, meshes (Mesh) the game's renderer draws (Render).

   References: Jake Gordon, "How to build a racing game" (2012), for the
   segments and their kerbs; Catmull and Rom, "A class of local
   interpolating splines" (1974); and, for what the numbers are for,
   the tracks of Mario Kart 64 (Nintendo, 1996), which are exactly this
   -- a closed ribbon that climbs, drops and leans. *)

(* ix: the author's playground's gamekits/racing/3d/Track3d.mli
 * (docs/plans/plan_virtuaracing.md); a strip and a wall a Mesh.shape,
 * no optional argument (mini-ml has none), no [of_road] (the coast, not
 * here yet) *)

(*****************************************************************************)
(* {1 Writing a course} *)
(*****************************************************************************)

(* A control point: where the middle of the road passes, how wide it is
 * there ([width] is *half* the road, since everything across the
 * ribbon is measured from the middle), and how much it leans, in
 * degrees (positive: the right-hand side lifted, for a left-hand
 * corner). Between two control points all three are eased from one to
 * the other, so a course need only say where each thing changes. *)
type control = { x : float; y : float; z : float; width : float; bank : float }

(* [control ~y ~width ~bank x z]: a control point at (x, z) *)
val control : y:float -> width:float -> bank:float -> float -> float -> control

type t

(* [build step controls]: the closed circuit through [controls], cut
 * into segments of [step] -- the quads a game draws, and
 * the grain of every answer below. At least four control points are
 * needed for a spline; fewer raises [Invalid_argument]. *)
val build : float -> control list -> t

(* the course's length, in world units: [segments] times [step] *)
val length : t -> float

val segments : t -> int
val step : t -> float

(*****************************************************************************)
(* {1 Places on it} *)
(*****************************************************************************)

(* the middle of the road at some distance along: where it is, which
 * way it goes (degrees, 0 towards -z and 90 towards +x, Camera3d's
 * headings), and the width and lean there *)
type place = {
  px : float;
  py : float;
  pz : float;
  heading : float;
  width : float;
  bank : float;
}

(* [at t s]: the place at the distance [s] along the middle, the two
 * nearest samples mixed. On a circuit the distance wraps round the lap
 * (so [at t (length t +. 1.)] is [at t 1.]); on a stage it stops at
 * each end. *)
val at : t -> float -> place

(* [across t s offset]: the point on the road's surface [offset] to the
 * right of the middle at [s] (negative: to the left), lifted and
 * tilted by the lean there. This is the ribbon: every quad, every kart
 * and every item box goes through it. *)
val across : t -> float -> float -> float * float * float

(* [locate t x z]: the other way -- (how far along, how far to the
 * right) for a point in the world, the ground under it forgotten (a
 * circuit that climbs over itself would need more). Every segment is
 * tried. *)
val locate : t -> float -> float -> float * float

(* [locate_near t near x z]: the same, near [near] along.
 * A circuit comes back near itself, so the answer is not unique: pass
 * [near], the distance the thing was at last frame, and the search
 * stays within a few segments of it, which is both right and quick. *)
val locate_near : t -> float -> float -> float -> float * float

(* [forward t s] : the direction of travel at [s], as (x, z): what
 * Camera3d.forward gives for [at t s]'s heading *)
val forward : t -> float -> float * float

(*****************************************************************************)
(* {1 Drawing it} *)
(*****************************************************************************)

(* [strip t color i a b]: the quad of segment [i] (0 to [segments] - 1)
 * from [a] to [b] across, its face up. The road, its kerbs, its verges
 * and the line down its middle are all strips at different offsets --
 * the game chooses the colors and where each one stops, since that is
 * all a course looks like:
 *
 *     grass | kerb |        road        | kerb | grass
 *        -6w  -1.15w  -w     0      w   1.15w    6w
 *)
val strip : t -> Mesh.color -> int -> float -> float -> Mesh.shape

(* [wall t color i offset height]: the quad standing along segment
 * [i] at [offset], [height] tall: a rail, a barrier, the side of a
 * tunnel. Drawn on both sides, since which side a game sees it from
 * depends on where the car is. *)
val wall : t -> Mesh.color -> int -> float -> float -> Mesh.shape
