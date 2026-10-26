(* Cars: the formula cars, as Virtua Racing's were, each part a solid
 * of a few flat faces, and where they stand on the grid.
 *
 *          rear wing              the nose tapering to its tip, the
 *        |=========|              tub, the engine cover sloping from
 *   (O)  |  _/^\_  |  (O)         the airbox to the gearbox, the
 *        |_| tub |_|              sidepods, the two wings with their
 *            | |                  endplates, the four wheels (octagons:
 *   (o)    __| |__    (o)         the flat shading shows every face),
 *         |=======|               the brake lights; and its shadow on
 *         front wing              the road under it
 *
 * A car is a mesh made once for each livery (Mesh), at the origin
 * facing -z, the road at y = 0; at each frame it is turned to its
 * heading and moved to its place (Render.draw_at), its faces lit as
 * they then face the sun.
 *
 * Where it stands: the game (Virtua) draws the sixteen; at stage 3
 * (plan_virtuaracing.md) they drive (the playground's Topdown for the
 * player's, the rivals on the road's lanes).
 *
 * What is ours: TinyVirtuaRacing's car, its liveries and its grid; the
 * front wheels not turned with the steering wheel yet (a mesh for each
 * angle, or the wheels a mesh of their own, at stage 3). *)

(* [model livery braking]: a car, its shadow under it *)
val model : Mesh.color -> bool -> Mesh.shape

(* the rivals' colours, the k-th's at k mod 15 *)
val liveries : Mesh.color array

(* the player's place on the grid: 9th, as the arcade put you
 * mid-field *)
val player_slot : int

(* [slot_s k] and [slot_lane k]: the grid's k-th place, two columns, 8
 * metres apart in each, behind the line: how far along (negative) and
 * across *)
val slot_s : int -> float
val slot_lane : int -> float
