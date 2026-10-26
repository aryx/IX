(* Topdown: a car on a plane seen from above, its heading, its speed
 * and its slide: the racing kit's model of a car (the playground's
 * gamekits/racing/Topdown), here mini-virtuaracing's player's. The
 * world is a plane, the car a point on it with a heading; what the game
 * draws (here a formula car on a road in space) is another matter.
 *
 * The car slides ([drive]): its speed follows the gas, but its velocity
 * only turns towards where it points by a fraction each frame, the
 * "grip"; a fast turn keeps going the old way a moment, it drifts:
 *
 *         heading  ^                 velocity after one frame:
 *                  |   / velocity    grip of the way from the old
 *                  |  /              velocity to heading * speed
 *                  | /
 *                  car
 *
 * Not physics either (a rigid body with tyres and friction forces):
 * the arcade's few rules. Two cars, or a car and a wall, bump as the
 * arcade's did ([bounce], [push]): a wall sends it back where it came
 * from, two discs push apart and swap their speeds along the line.
 *
 *          wall                 e.g. a wall from x = 100: from (95, 0)
 *           |                   to (105, 0) at vx = 300: back at
 *      --->*|     then  <-*|    (95, 0), vx = -150
 *           |
 *
 * What is ours: only the car and its two bumps (the kit's waypoint
 * track, its distance and its computer driver are not this game's:
 * its rivals drive on the road, Rivals). *)

type t = {
  x : float;
  y : float;
  vx : float; (* the velocity, world units per second *)
  vy : float;
  heading : float; (* degrees, counterclockwise from +x *)
  speed : float; (* along the heading, what the gas controls *)
}

type params = {
  accel : float; (* the speed full gas adds per second *)
  friction : float; (* the fraction of its speed lost per second *)
  grip : float; (* the fraction of the way the velocity turns to the heading, per frame *)
  steering : float; (* degrees per frame, the wheel full over *)
  steering_speed : float; (* the speed from which the wheel turns fully *)
}

(* [drive params top gas steer car]: one frame (a 60th of a second),
 * [gas] -1 to 1, [steer] -1 (right) to 1 (left), the speed within
 * [-top / 3, top] *)
val drive : params -> float -> float -> float -> t -> t

(* [bounce wall before after]: [after], or, if it went into the wall
 * ([wall x y]), back along each axis that crossed it, that speed
 * reversed and halved *)
val bounce : (float -> float -> bool) -> t -> t -> t

(* [push radius a b]: two discs of [radius] that overlap pushed apart,
 * their velocities along the line between them swapped *)
val push : float -> t -> t -> t * t
