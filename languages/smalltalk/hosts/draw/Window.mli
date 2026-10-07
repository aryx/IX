(* Squeak in a window of mini-rio's, under mini-9pi (or on all the
 * screen, with no window system): the third host, a Plan 9 program
 * over ix's lib_graphics (docs/plans/plan_system_squeak.md, stage 5).
 * The Display is the window's size (800 by 600 at most), its pixels
 * loaded into an image of the draw device and drawn in the window when
 * they changed; the mouse and the keys are the window's (/dev/mouse,
 * /dev/cons, by Mouse and Keyboard).
 *
 * The mouse's buttons, by Smalltalk's colours: the left is the red
 * one, the right the yellow, the middle the blue. Control-C stops what
 * runs too long.
 *
 * [run caps system transcript]: until the window is deleted. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

val run : < caps; .. > -> Squeak.system -> (string -> unit) -> unit
