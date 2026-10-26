(* Driving: the player's car on the course, a Topdown car with the
 * road's rules.
 *
 * The car is the racing kit's Topdown: a heading of its own, a speed,
 * and a velocity that only turns towards the heading by the grip's
 * fraction each frame, so it goes where it points, and in a fast turn
 * slides wide before it does. Not a car *across* a road with the road
 * turning under it (TinyOutRun's): here the road is a shape in space,
 * the car drives on it, and where it is on the road is found again at
 * each frame (Track3d.locate_near).
 *
 * What the game adds is the road's own rules: the wheel turned by the
 * keys a little at a time (a keyboard has no wheel, and a full lock at
 * once is a spin), and less of it at speed; the grass slowing the car
 * and taking its grip; the rail at the edge of the grass, which it
 * scrapes along (Topdown.bounce); and Virtua Racing's spins: too much
 * slide, or the rail hit too hard, and the car spins round, stops
 * sliding, and is set back facing the road.
 *
 * The Topdown plane is the world's (x, -z), its headings
 * counterclockwise from +x ([plane_heading]); the world's headings are
 * the course's (Track3d: 0 along +z, clockwise seen from above). *)

(* the top speed, 330 km/h at the road's scale; on the grass *)
val top_speed : float
val grass_speed : float
val kmh : float -> float

(* a world heading as the plane's *)
val plane_heading : float -> float

type t = {
  car : Topdown.t;
  s : float; (* how far along the course, laps included *)
  offset : float; (* how far to the right of the middle *)
  wheel : float; (* -1 full right, 1 full left *)
  bump : int; (* frames since the car last hit the rail *)
  spin : int; (* frames of a spin left; 0: driving *)
}

(* a spin's frames *)
val spin_frames : int

(* [at course s offset]: a car standing on the road there *)
val at : Course.t -> float -> float -> t

(* the course's length, and s within one lap of it *)
val length : Course.t -> float
val wrap : Course.t -> float -> float

(* where the car is in the world, and which way its body points (in a
 * spin, round and round) *)
val world : Course.t -> t -> Vec3.t * float

(* the angle between where the car points and where it goes: a slide *)
val slip : t -> float

(* [steer course gas wanted d]: one frame, [gas] -1 to 1, the wheel
 * wanted -1 (right) to 1 (left) *)
val steer : Course.t -> float -> float -> t -> t
