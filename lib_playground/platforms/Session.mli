(* What the platforms share (docs/plans/done/plan_playground.md):
 * - the words of the command line;
 * - a program stepped (its model, its commands' answers, an event given
 *   to its subscriptions);
 * - a frame of a script played;
 * - two things that the playground's platforms draw and write.
 * What reaches the system takes a capability: reading the command
 * line, writing its usage, and writing a WAV file. *)

(* The words of the command line, those of the playground's platforms:
 *   -dump-frame n file   writes frame n (the first is 1) to file, then ends
 *   -frames n            plays n frames, then the picture stays (no clock)
 *   -fixed-time seconds  the program's clock stays at that time
 *   -script script       what is pressed, frame by frame (Input_script.mli)
 *   -dump-audio file     writes the sound of the frames played, a WAV file
 *                        (with -dump-frame or -frames: the playground's word)
 *   name=value           the program's flags (Playground.flags)
 * Each platform says which ones it takes. *)
type cli = {
  mutable frames : int; (* 0 when not given *)
  mutable file : string;
  mutable fixed_time : float option;
  mutable script : Input_script.t option;
  mutable audio : string; (* "" when not given *)
  mutable args : string list;
}

(* the usage of the program of that name *)
val usage : string -> string

(* parses the words of the command line. With -help, it writes the
 * usage and the options on the standard output; a word it does not
 * know is reported with the usage on the standard error. In both
 * cases it then raises Exit.ExitCode, 0 or 2 (Arg_.parse_argv), for
 * the program's main to end with (Exit.catch). *)
val parse : < Cap.argv ; Cap.stdout ; Cap.stderr ; .. > -> cli

(* -dump-audio, for a run without a clock. [hear cli], called after
 * each frame, pulls the frame's sixtieth of a second of sound (from
 * Audio_source; nothing when the program has none). The sound is
 * pulled whether a file is asked for or not, because a studio draws
 * what it played. [dump_audio caps cli], called at the end, writes the
 * file when one was asked for. *)
val hear : cli -> unit
val dump_audio : < Cap.open_out ; .. > -> cli -> unit

(* a running program, with its model now *)
type ('model, 'msg) t

(* starts a program by running its init, given the flags *)
val start : ('model, 'msg) Playground.app -> Playground.flags -> ('model, 'msg) t
(* gives an event to the first subscription that asks for it *)
val event : ('model, 'msg) t -> Sub.event -> unit
(* [frame run script n time] plays frame n (counted from 1): what the
 * script does at it, the commands' answers, then the clock's tick at
 * [time] (in the order of the playground's loop, Native_loop_2d) *)
val frame : ('model, 'msg) t -> Input_script.t option -> int -> float -> unit
val view : ('model, 'msg) t -> Playground.shape list

(* the time of frame n of a run without a clock: the fixed time when one
 * was given; otherwise 1000 seconds at the first frame, and a sixtieth
 * of a second more at each frame *)
val time_of_frame : cli -> int -> float

(* What the playground's platforms write over a frame, at the bottom
 * left: the picture's size in pixels and the frames a second (0 when a
 * frame is dumped). It is a shape to draw after the view's, at its
 * [scale] (pixels a unit), and its letters are 10 pixels whatever the
 * scale. *)
val fps_counter : width:int -> height:int -> scale:float -> int -> Playground.shape

(* The screen as large as the window. A program's screen is normally
 * the playground's square of 1,000 units, scaled into what the
 * platform has, which is what a game wants. With the flag window (a
 * program's own, or one that its main adds to the flags it gives
 * run_app), the screen is the window's instead, a unit a pixel, and it
 * follows the window when the window is given another size
 * (Sub.on_resize): a browser's page is as wide as its window.
 * "window=1280x900" gives the size it starts at; "window" alone leaves
 * the size to the platform (SDL makes it 1280 by 900 if the display
 * has the room; ppm makes it the square of 1,000 units, and the
 * picture is the same as without the flag). Plan 9's draw platform
 * reads it too. *)
type window = Square | Follows of (int * int) option

val window : Playground.flags -> window

(* a frame as a PPM picture (P6: the size, then the red, green and blue
 * of each pixel, row after row) *)
val ppm : Framebuffer.t -> string
