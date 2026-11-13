(* The loop of a Plan 9 platform (docs/plans/done/plan_playground.md):
 * what the platform that computes its pixels (software/) and the one
 * that asks the draw device for each shape (draw/) share. It opens the
 * display, reads the mouse and the keyboard, steps the program by the
 * clock, and shows a frame in the platform's own way.
 *
 * The clock. A program's Tick is a sixtieth of a second of its world,
 * whatever the machine (a piece of Tetris falls by ticks). So the ticks
 * due since the start are counted on the system's clock and all given,
 * then one frame is shown. A machine that shows 5 frames a second plays
 * the same game as one that shows 60, less smoothly.
 *
 * The keys. Where there is a /dev/kbd (mini-9pi's, and a window of
 * mini-rio's, which give the keys down at each change), a key is down
 * and up as it really is, and the console's characters are only what
 * was typed. Where there is none, a key is down from its character to
 * the next tick. The keys that edit a text (Enter, Backspace, Tab,
 * Escape) are down that way too, even with a /dev/kbd, because they
 * must come in the console's order, after the characters typed before
 * them, which the kbd's messages do not keep. Ctrl-Q ends the program,
 * as on the playground's platforms, and so does Delete.
 *
 * Where it stands: below this loop are Display and Draw (the draw
 * device's messages, as every graphical program of mini-9pi's sends
 * them), the kernel's mouse and keyboard files, and its clock. Above
 * it are the two platforms, which differ only in what they do when
 * this loop says "show this frame". In a window of mini-rio's the same
 * files are the window's: the program does not know which it has.
 *
 * design:
 * The clock's rule is the fixed time step of games: the world
 * advances by ticks of one length, as many as the real time that
 * passed asks for, and drawing is done when there is time left. The
 * other rule, one update a frame given the frame's own duration,
 * makes the game's physics depend on the machine's speed: a jump is
 * a little higher on a slow one (Integrate.mli has the arithmetic;
 * Glenn Fiedler's "Fix Your Timestep!" is the usual reference).
 *
 * usage: game [-frames n [-script script] [-fixed-time seconds]] [name=value]...
 *   keys=on     (a flag) writes the keys down at each of the system's
 *               messages (/dev/kbd) on the standard error
 *   stats=on    (a flag) every 40 frames, writes what a frame cost on the
 *               standard error: the update, the view, the showing
 *   idle=wait   (a flag, usually the program's own) when the picture is
 *               still and nothing happens, the program is looked at 4
 *               times a second, not 60, and there is no meter. It is not
 *               for a program that counts ticks through a still picture
 *               (a game). idle=spin on the command line makes the program
 *               run as other programs do
 *   -frames n   plays n frames at once, the script's keys in them, then
 *               the picture stays: a session that is the same each time,
 *               for a test to compare its screen (Session.mli) *)

(* what a platform gives the loop:
 * - [make] makes where it draws (it is made again when the window
 *   changes, and the one before is freed);
 * - [at] gives the picture's square there (for the mouse);
 * - [units] gives the program's screen in its units (1000 by 1000 for
 *   the square, or the window's pixels with the flag window);
 * - [show] shows a frame (the view's shapes, and the frames a second to
 *   write); it returns false when there was nothing to draw, because
 *   the frame was the one before again *)
type 'w window = {
  make : Display.t -> 'w;
  at : 'w -> Rectangle.t;
  units : 'w -> int * int;
  show : Display.t -> 'w -> Playground.shape list -> int -> bool;
  free : 'w -> unit;
}

(* the playground's screen, 1000 units by 1000 *)
val square : int * int

(* Playground_platform's two functions; the second takes the platform's
 * window *)
val flags : < Cap.argv ; Cap.stdout ; Cap.stderr ; .. > -> Playground.flags
val run_app :
  'w window ->
  < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.draw ; Cap.mouse ; Cap.keyboard ;
    Cap.fork ; Cap.open_out ; Cap.clock ; .. > ->
  Playground.flags -> ('model, 'msg) Playground.app -> unit

(* Playground_platform's cursor over the window: Plan 9's arrow, or a
 * picture of the platform's written to /dev/cursor *)
val set_cursor : Playground.cursor -> unit

(* Playground_platform's clipboard, which is /dev/snarf (Snarf) *)
val clipboard : unit -> string
val set_clipboard : string -> unit
