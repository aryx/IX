(* A contact says how two overlapping hitboxes touch, which is what
 * collision response needs (see notes_2d_physics.md sections 8 and 10):
 *
 *            normal
 *      .----->
 *     (  a  (/)  b  )       the direction to push b away from a (a
 *      '---'  depth         unit vector), how far they overlap along
 *                           it, and a point where they touch
 *
 * Example: circles of radius 30 at (0, 0) and 25 at (30, 40): their
 * centers are 50 apart, 5 less than 30 + 25, so the depth is 5, and the
 * normal is (0.6, 0.8), from the first center to the second. *)
(* ix: copied from libs/physics/2d/Contact.mli in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

type t = {
  normal : Vec2.t; (* unit, from the first hitbox to the second *)
  depth : float; (* > 0 *)
  point : Vec2.t; (* where they touch: for polygons, the middle of their overlap *)
}
