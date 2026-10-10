(* Stacking: all the contacts of a step, solved together (see
 * notes_2d_physics.md section 12).
 *
 * Resolve fixes one contact at a time. In a pile, each fix undoes a
 * bit of another: pushing the top box up pushes the one below down,
 * which then sinks into the floor... Solved one by one, once, a pile
 * jitters and sinks. The fix, sequential impulses (Erin Catto, Box2D
 * Lite, 2006): go over all the contact points again and again
 * ([iterations]), each time correcting each one's impulse a little, and
 * the whole pile converges -- Gauss-Seidel, the old method for linear
 * systems, applied to contacts. Two details make it work:
 *
 * - The impulses add up over the iterations (one per contact point),
 *   and it's the *sum* that must never pull (>= 0): one iteration may
 *   take back what an earlier one gave too much. Friction's sum stays
 *   within mu times the normal one.
 *
 * - Warm starting: a pile is still from one step to the next, so each
 *   contact point starts from its impulses of the previous step (found
 *   again by where it is: within [matching]), already nearly right;
 *   the iterations only fix the difference.
 *
 *     step 1:  top  0 -> 0.5 -> 0.8 -> 0.95 ...     (iterations)
 *     step 2:  top  0.95 -> 0.99 -> ...             (warm started)
 *
 * The overlaps aren't pushed apart anymore (Resolve.separate): a
 * contact deeper than [slop] asks for a small separating speed, a
 * fraction [baumgarte] of its depth per step (Baumgarte
 * stabilization, 1972), so the pile rises out of the floor smoothly
 * instead of popping. And bounciness only counts for contacts
 * approaching faster than [bounce_threshold]: a box resting on the
 * floor doesn't keep making tiny bounces.
 *
 * Example: a box of mass 1 lying on the floor (two contact points, its
 * bottom corners), g = 10, dt = 0.1: each step gravity gives it a
 * downward speed of 1, and the solver takes it back with a total
 * normal impulse of m g dt = 1, half at each corner by symmetry: 0.5
 * each, step after step. Warm started, the first iteration of a step
 * already has it.
 *
 * Joints (Joint2d) are solved in the same loop, their rows before the
 * contacts' at each iteration: a pin, a rod, a rope, a pulley. Left
 * out, compared to Box2D: sleeping (bodies still for a while skipped
 * until something touches them), and warm starting for the joints.
 *
 * Where it stands: this is the middle of a step, and the step is
 * where the whole engine is seen at once. The playground's Physics
 * (its simulate) does, for each sixtieth of a second:
 *
 *   the pushes on each body          Force       an acceleration
 *        |
 *   velocities += acceleration dt    Integrate   (its first half)
 *        |
 *   which pairs may touch            Broadphase  boxes, by sort and sweep
 *        |
 *   which do, and how                Collide     Shape's hitboxes placed,
 *        |                                       a Contact per point
 *   velocities corrected             Solver      Resolve's impulses, and
 *        |                                       Joint2d's rows, iterated
 *   positions += velocity dt         Integrate   (its second half)
 *
 * The solver is put *between* the two halves of semi-implicit Euler
 * on purpose: it works on velocities only, so the positions are
 * moved once, with velocities that already know about the floor.
 * Move first and solve after, and a resting box is in the floor at
 * every step before it is taken out.
 *
 * cs-history:
 * Game physics before this was mostly the penalty method -- a
 * spring pushing two overlapping bodies apart, stiff, and unstable
 * as soon as things pile -- or exact solvers too slow for a frame.
 * Catto's talks (2005, 2006) showed that the crudest iteration,
 * with the clamp on the sum and the warm start, was enough for
 * boxes to stack, in a thousand lines one could read. Box2D (2007)
 * grew from Box2D Lite and became the physics of a generation of
 * 2D games; Angry Birds (2009) is the one everybody played.
 *
 * terminology:
 * An *impulse* is a force times the time it lasted: a change of
 * momentum, with the time left out. *Sequential impulses* is Catto's
 * name; the mathematician's is projected Gauss-Seidel, "projected"
 * for the clamp (an impulse kept >= 0), and the problem solved is a
 * linear complementarity problem: at each contact either the bodies
 * part and the impulse is zero, or they stay and it is positive,
 * never both.
 *
 * References: Erin Catto, "Iterative Dynamics with Temporal
 * Coherence", GDC 2005, and Box2D Lite (2006, 1000 lines); J.
 * Baumgarte, "Stabilization of constraints and integrals of motion in
 * dynamical systems", 1972. *)
(* ix: the author's playground's libs/physics/2d/Solver.mli; its optional arguments are said, where it has some (docs/plans/plan_playground.md) *)

type options = {
  (* how many times to go over the contacts per step *)
  iterations : int;
  (* start from the previous step's impulses *)
  warm_starting : bool;
  (* the fraction of an overlap corrected per step, and the overlap
   * tolerated (so that resting bodies stay in touch) *)
  baumgarte : float;
  slop : float;
  (* the approach speed under which bodies don't bounce *)
  bounce_threshold : float;
  (* how near a contact point must be to one of the previous step to
   * be the same one *)
  matching : float;
}

(* 10 iterations, warm starting, baumgarte 0.2, and in the playground's
 * units (pixels): slop 0.5, bounce_threshold 50, matching 3 *)
val default : options

(* two bodies touching, by their indices in the bodies' array, a < b *)
type pair = { a : int; b : int; contacts : Contact.t list; restitution : float; friction : float }

(* the impulses of the last step's contact points, by pair *)
type memory

val nothing : memory

(* [solve options ~dt ?joints bodies pairs memory]: the bodies with
 * their velocities changed by the contacts and the joints (not their
 * positions: the caller moves them after, with the new velocities),
 * and the memory for the next step. [joints]: the bodies' angles
 * (radians, which Body.t doesn't have and the joints' anchors need),
 * and the joints. *)
val solve :
  options -> dt:float -> joints:(float array * Joint2d.t list) option -> Body.t array -> pair list -> memory -> Body.t array * memory

(* [impulses memory (a, b)]: the normal impulses of a pair's contact
 * points at the last step (for tests and debug drawing) *)
val impulses : memory -> int * int -> float list
