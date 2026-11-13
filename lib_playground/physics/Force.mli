(* What pushes and pulls: the forces, given as the accelerations they
 * cause (see notes_2d_physics.md section 6).
 *
 * Newton's second law, F = m a, turned around: an integrator needs the
 * acceleration a = F / m, a function of the body's position (and
 * velocity, for drag), the same at every step. For gravity the mass
 * cancels out (Galileo: a heavy and a light ball fall together); for a
 * spring it doesn't, which is why k / m appears below.
 *
 *     uniform              gravitation              spring
 *        |  |  |               \  |  /               anchor
 *        v  v  v             ---  *  ---               |
 *     the same             towards the star,           /\/\/\ o
 *     everywhere           1 / r^2                     pulled back,
 *                                                      proportional to x
 *
 * References: Newton, Philosophiae Naturalis Principia Mathematica,
 * 1687 (the laws of motion, universal gravitation); Hooke, De Potentia
 * Restitutiva, 1678 ("ut tensio, sic vis": as the extension, so the
 * force). *)
(* ix: copied from libs/physics/2d/Force.mli in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

(* an acceleration as a function of position and velocity *)
type t = Vec2.t -> Vec2.t -> Vec2.t

(* no force: a = (0, 0), so a body keeps its velocity (the first law) *)
val none : t

(* [uniform g]: the same acceleration everywhere, e.g. gravity near the
 * ground, (0, -g) *)
val uniform : Vec2.t -> t

(* [gravitation ~gm ~center]: Newton's gravitation towards a mass M
 * fixed at [center], with gm = G M: an acceleration of gm / r^2 towards
 * it, where r is the distance. A body at distance r needs the speed
 * sqrt (gm / r) to stay on a circular orbit. Example: with gm =
 * 1,000,000 and r = 100 pixels, the pull is 100 px/s^2, the circular
 * speed is 100 px/s, and one orbit takes 2 pi r / v = 6.28 s. *)
val gravitation : gm:float -> center:Vec2.t -> t

(* [spring ~k_over_m ~anchor]: Hooke's law, a pull back towards
 * [anchor], proportional to the distance from it: -(k / m) (pos -
 * anchor). A mass on such a spring oscillates with the period
 * 2 pi / sqrt (k / m) (6.28 s when k / m = 1). *)
val spring : k_over_m:float -> anchor:Vec2.t -> t

(* [drag ~c]: linear drag, -c vel: a pull against the motion,
 * proportional to the speed (a body moving slowly through a thick
 * fluid; air at speed is closer to quadratic, -c |vel| vel). Under a
 * constant push a, a body then reaches a top speed, a / c, where the two
 * balance. Example: with c = 0.5 and a gravity of 10, the terminal
 * speed is 20. *)
val drag : c:float -> t

(* [sum forces]: forces add up (the force accumulator of every engine) *)
val sum : t list -> t
