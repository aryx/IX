(* Race: one race on a course, a frame at a time: the countdown, the
 * player's car by the keys, the rivals, the clock and its checkpoints,
 * the laps, the goal.
 *
 * The clock is the arcade's: it counts down from the course's start
 * time, each checkpoint (a lap's few, the line one of them) adds its
 * bonus, and at 0 the race is over wherever the car is. The laps are
 * counted from the line; the grid is behind it, so the first
 * checkpoint passed is a lap's first.
 *
 *   time:  -181 ... -1      0          ...      the goal, or 0 left
 *          the countdown    GO! the clock runs  the car steers itself
 *          (the cars held)                      to a stop ([finished])
 *
 * What is ours: the playground's sounds are events here ([event]),
 * played by the game (stage 4); its scenes (title, select, goal) are
 * the game's too. *)

type keys = { up : bool; down : bool; left : bool; right : bool }

(* what the race says of a frame, for the sound *)
type event =
  | Beep (* a second of the countdown *)
  | Go
  | Shift (* a gear up *)
  | Crash (* the rail hit, a spin, a rival bumped *)
  | Checkpoint of int (* passed, the n-th from the start *)
  | Final_lap
  | Goal
  | Game_over (* the clock at 0 *)

type t = {
  drive : Driving.t;
  rivals : Rivals.t list;
  time : int; (* frames since the start; negative: the countdown *)
  clock : int; (* frames left on the clock *)
  passed : int; (* checkpoints passed *)
  message : string * int; (* in the middle of the screen, and until when *)
  lap_times : int list; (* in frames, the last one first *)
  finished : bool; (* past the goal, or out of time *)
  over : bool; (* out of time *)
}

(* the countdown's frames *)
val countdown : int

(* [start course]: the cars on the grid, the countdown to come *)
val start : Course.t -> t

(* [step course keys r]: one frame (a 60th of a second) *)
val step : Course.t -> keys -> t -> t * event list

(* the lap the car is on (from 0), and the checkpoints passed *)
val lap : Course.t -> Driving.t -> int
val checkpoint : Course.t -> Driving.t -> int

(* the automatic box's seven gears: the one the car is in, and where
 * the revs are in it (0 to 1: the tachometer, the engine's pitch) *)
val gears : int
val gear : Driving.t -> int
val revs : Driving.t -> float
