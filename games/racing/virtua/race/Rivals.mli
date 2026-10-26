(* Rivals: the fifteen other cars, as in the arcade.
 *
 * Not Topdown cars: they drive *on* the road, a distance along it and a
 * lane across it, as TinyOutRun's traffic does, which is what makes
 * them good drivers cheaply. Each one:
 *   - wants its top speed (a little under the player's), and less before
 *     a corner: it looks 10 to 50 segments ahead for the sharpest turn,
 *     whose radius r allows sqrt (grip * r) ([corner_speed]);
 *   - brakes hard to it, accelerates from it as the player does;
 *   - keeps to its lane, and moves over to pass a slower car ahead in
 *     it (the player's too), back when the lane is clear.
 * The player bumps them as a disc bumps a disc (Topdown.push): the
 * rival slows down a little, the player is pushed aside, or spins if
 * the hit was hard.
 *
 *   the grid (Cars): two columns, 8 m apart in each, behind the line;
 *   the player in the 9th place, as the arcade put you mid-field
 *
 * What is ours: a rival's top speed has a part by Scenery.jitter (the
 * playground's by Hashtbl.hash), so a race is not the playground's to
 * the hundredth. *)

type t = {
  rs : float; (* how far along the course *)
  lane : float; (* across the road *)
  rspeed : float;
  home : float; (* the lane it keeps to *)
  top : float;
  livery : Mesh.color;
}

(* the rivals on the grid *)
val grid : Course.t -> t list

(* [corner_speed course s]: the speed for the corners ahead of s *)
val corner_speed : Course.t -> float -> float

(* [drive course player rivals]: one frame of every rival *)
val drive : Course.t -> Driving.t -> t list -> t list

(* where a rival is in the world, and its heading *)
val place : Course.t -> t -> Vec3.t * float

(* [bump course player rivals]: the player against the rivals, each a
 * disc of 2.2 m; whether one was hit *)
val bump : Course.t -> Driving.t -> t list -> Driving.t * t list * bool

(* the player's place: 1 + the rivals ahead; as said (1ST, 2ND...) *)
val position : Driving.t -> t list -> int
val ordinal : int -> string
