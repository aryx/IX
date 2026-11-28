(* A tiny orrery, a program for TinyKernel.ml built on
 * TinyLibPlayground.ml: the Solar System seen from above, from
 * 2000-01-01 on, each planet where it was that day and turning at its
 * own speed, sped up. An orrery is a clockwork model of the planets,
 * named after the Earl of Orrery, for whom John Rowley built one around
 * 1713. The keys: up and down make the time go faster or slower, space
 * pauses it, r goes back to 2000, and q quits.
 *
 * It is the playground's demo for its circles: each orbit is an
 * [Ellipse] and each planet and the Sun a [Disc]. The orbits, the Sun
 * and the stars are the playground's ground, which does not change, so
 * that a frame draws only the planets and the words.
 *
 * twin:
 * The author's playground has examples/PhysicsSolarSystem.ml, which
 * places the planets by Kepler's laws in floats, with JPL's orbital
 * elements (physics/2d/Planets.ml and Kepler.ml).
 *
 * kept:
 * - the view from above, with the distances compressed (a planet a AU
 *   from the Sun is 42 sqrt a pixels from it, where the twin has 78)
 *   and the sizes magnified (2 + 3 sqrt (R / R_earth) pixels), so that
 *   Neptune and Mercury fit on one screen;
 * - each planet's place on 2000-01-01 (its mean longitude) and its
 *   period, from Kepler's third law;
 * - the keys for the speed, the pause and the return to 2000;
 * - the date, by Howard Hinnant's civil_from_days.
 *
 * dropped:
 * - the floats: tiny-ml has none. An angle is in 4096ths of a turn, and
 *   its sine is the playground's, from a table of a quarter turn in 64
 *   steps, with a line between two steps;
 * - Kepler's first and second laws: an orbit is a circle around the
 *   Sun, and a planet goes round it at a constant speed. So a planet
 *   can be off its true place by up to twice its eccentricity, in
 *   radians: about 24 degrees for Mercury, 11 for Mars, and about 6 at
 *   most for the others. The playground's ellipses cannot be turned to an
 *   orbit's direction, and Kepler's equation would need Newton's method
 *   in fixed point;
 * - the true distances and sizes (the twin's d and s keys), the Moon,
 *   Saturn's rings, and the tilt of the orbits.
 *
 * exercises:
 * - Kepler's ellipses: the eccentric anomaly by Newton's method on
 *   integers, and each orbit drawn as a ring of dots, as the twin does;
 * - the Moon around the Earth;
 * - the time going backwards.
 *)

(* A planet: its colour, its distance from the Sun and its radius in
 * pixels, its period in days, and its angle on 2000-01-01 in 4096ths
 * of a turn. *)
type planet = {
  name : string; colour : int; distance : int; radius : int;
  period : int; start : int;
}
val planets : planet list

(* [place p d] is where planet p is on the screen d days after
 * 2000-01-01. *)
val place : planet -> int -> int * int

(* [date d] is the date d days after 2000-01-01, as 2000-01-01 is
 * written. *)
val date : int -> string

(* The days since 2000-01-01, the days that pass in a frame (a
 * thirtieth of a second), and whether the time stands still. *)
type model = { days : int; speed : int; paused : bool }

val game : model TinyLibPlayground.game

(* What the playground's loop needs, so what the orrery needs: the window
 * to draw in (Cap.draw), the clock for the frames' times, a random seed
 * for [init] (the orrery's ignores it), and the speaker (Cap.audio),
 * which the loop opens for any game's sounds, though the orrery makes
 * none (its [sound] and [music] are silent). *)
type caps = < Cap.draw; Cap.audio; Cap.random; Cap.clock >

(* the program, orrery: the game run with the system's clock *)
val main : < caps; .. > -> string array -> Exit.t
