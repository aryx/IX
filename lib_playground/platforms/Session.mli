(* What the platforms share (docs/plans/plan_playground.md): the
 * command line's words, a program stepped (its model, its commands'
 * answers, an event given to its subscriptions), a frame of a script
 * played, and two things the playground's platforms draw and write.
 * Nothing here reaches the system. *)

(* The command line's words, the playground's platforms':
 *   -dump-frame n file   frame n (the first is 1) written to file, and the end
 *   -frames n            n frames, then the picture stays (no clock)
 *   -fixed-time seconds  the program's clock stays there
 *   -script script       what is pressed, frame by frame (Input_script.mli)
 *   name=value           the program's flags (Playground.flags)
 * Each platform says which it takes. *)
type cli = {
  mutable frames : int; (* 0: not said *)
  mutable file : string;
  mutable fixed_time : float option;
  mutable script : Input_script.t option;
  mutable args : string list;
}

val usage : string
(* (Failure, its message the usage, for a word it does not know) *)
val parse : string array -> cli

(* a program running: its model now *)
type ('model, 'msg) t

(* its init, given the flags *)
val start : ('model, 'msg) Playground.app -> Playground.flags -> ('model, 'msg) t
(* an event, to the first subscription that asks for it *)
val event : ('model, 'msg) t -> Sub.event -> unit
(* [frame run script n time]: frame n (from 1): what the script does at
 * it, the commands' answers, then the clock's tick at [time] (the order
 * of the playground's loop, its Native_loop_2d) *)
val frame : ('model, 'msg) t -> Input_script.t option -> int -> float -> unit
val view : ('model, 'msg) t -> Playground.shape list

(* the time of frame n of a run without a clock: the fixed time when one
 * was said; else 1000 seconds, and a sixtieth of a second a frame *)
val time_of_frame : cli -> int -> float

(* What the playground's platforms write over a frame, at the bottom
 * left: the picture's size in pixels and the frames a second (0 when a
 * frame is dumped). A shape to draw after the view's, at its [scale]
 * (pixels a unit): its letters are 10 pixels whatever the scale. *)
val fps_counter : width:int -> height:int -> scale:float -> int -> Playground.shape

(* a frame as a PPM picture (P6: the size, then each pixel's red, green
 * and blue, row after row) *)
val ppm : Framebuffer.t -> string
