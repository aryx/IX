(* Squeak in a window on Linux (SDL): the Display shown, the mouse and
 * the keys given to the machine, the world's cycle run until the
 * window is closed. The one host mini-ml does not build (SDL is C's),
 * as mini-qemu's window; the others are a window of mini-rio and the
 * bare Pi (docs/plans/plan_system_squeak.md).
 *
 * The mouse's buttons, by Smalltalk's colours: the left is the red one
 * (pick up, select), the right the yellow (a text's menu: do it, print
 * it, accept), the middle the blue (a halo), and Control with the left
 * is the blue one too. Control-C stops what runs too long.
 *
 * [run system scale transcript]: the window [scale] times the
 * Display's 800 by 600; what Smalltalk's host is told, to [transcript]. *)

val run : Squeak.system -> int -> (string -> unit) -> unit
