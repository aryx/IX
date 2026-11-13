(* A body's state: where it is, how fast it goes, how heavy it is --
 * everything a step of the simulation needs to know about it, and
 * everything it changes (see notes_2d_physics.md sections 2-3).
 *
 *              vel (a velocity: how the position changes per second)
 *             ^
 *            /
 *       pos o      mass: how hard it is to change vel (F = m a)
 *
 * Units are the caller's; the playground's are pixels, seconds, and
 * an arbitrary mass unit (only ratios of masses matter).
 *
 * A rigid body also turns (notes_2d_physics.md section 11). Its spin
 * says how fast (in radians per second, counterclockwise), and its
 * moment of inertia says how hard it is to make it spin: the inertia is
 * the rotational twin of the mass, and comes from the body's shape
 * (Shape.moments). It is infinite by default, for a body that never
 * turns, whatever hits it (a point, or a platformer's hero). The caller
 * keeps the body's angle (angle += spin dt), since nothing here
 * depends on it.
 *
 *            spin (counterclockwise)
 *          .--.
 *         /    v      a point at r from the center moves at
 *        |  o-->r     vel + spin * perp r
 *         \      *    (perp: r turned a quarter turn)
 *          '----'
 *)
(* ix: copied from libs/physics/2d/Body.mli in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

type t = {
  (* position *)
  pos : Vec2.t;
  (* velocity, per second *)
  vel : Vec2.t;
  (* > 0; infinity for an immovable body *)
  mass : float;
  (* radians per second, counterclockwise *)
  spin : float;
  (* > 0; infinity for a body that never turns *)
  inertia : float;
}

(* [make ~vel ~mass ~spin ~inertia pos]: a body at [pos]. A still body
 * has the velocity (0, 0), and a body that never turns has the spin 0
 * and an infinite inertia. *)
val make : vel:Vec2.t -> mass:float -> spin:float -> inertia:float -> Vec2.t -> t

(* [point_velocity b r]: the velocity of b's point at [r] from its
 * center (vel + spin * perp r). Example: for a wheel that spins at 2
 * radians per second and does not move, its point at (0, -1), the
 * bottom, moves at (2, 0). *)
val point_velocity : t -> Vec2.t -> Vec2.t
