(* Sound: the race's, by the playground's Audio (its synthesizer, its
 * voices kept playing frame after frame, its sounds played once).
 *
 * A formula car's V12: seven gears (the automatic box, Race.gear), each
 * taking the revs from low to high over a seventh of the top speed, so
 * the pitch climbs, drops at each change, and climbs again: the sound
 * of speed. Two voices, a bright sawtooth opened up by the throttle
 * and a square an octave down, the body. In a tunnel, the walls give
 * it back: louder, lower, boomier. Under it the road: the tyres
 * squealing as the car slides, the grass under it off the road, the
 * wind at speed. Over it the race's events (Race.event): the
 * countdown's beeps, a gear's change, a crash, a checkpoint's jingle
 * (the arcade played one of a dozen short ones; here three, in turn),
 * the final lap, the goal's fanfare, game over.
 *
 *   rpm (Race.revs)  1 |    /|    /|    /|
 *                      |   / |   / |   / |  ...   seven gears
 *                      |  /  |  /  |  /  |
 *                  0.2 | /   | /   | /   |
 *                      +---------------------- speed *)

(* false: no sound made (the flag sound=off): on mini-9pi the sound of
 * the time a frame took is made after it, so a slow frame makes a
 * longer sound, and the sound slows the frames further *)
val on : bool ref

(* [engine rpm throttle tunnel]: the engine's two voices this frame *)
val engine : float -> bool -> bool -> unit

(* [road d]: the gravel, the tyres' squeal, the wind, by the car *)
val road : Driving.t -> unit

(* an event of the race, played *)
val event : Race.event -> unit

(* [play s]: [s] played, when [on] *)
val play : Audio.sound -> unit

(* the course select's: a course changed, the race chosen *)
val pick : Audio.sound
val go_beep : Audio.sound
