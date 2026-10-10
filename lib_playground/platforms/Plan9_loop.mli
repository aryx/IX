(* The loop of a Plan 9 platform (docs/plans/plan_playground.md): what
 * the platform that computes its pixels (software/) and the one that
 * asks the draw device for each shape (draw/) share. The display
 * opened, the mouse and the keyboard read, the program stepped by the
 * clock, and a frame shown by the platform's own way.
 *
 * The clock. A program's Tick is a sixtieth of a second of its world,
 * whatever the machine (a piece of Tetris falls by ticks): so the ticks
 * due since the start are counted on the system's clock and all given,
 * then one frame is shown. A machine that shows 5 frames a second plays
 * the same game as one that shows 60, less smoothly.
 *
 * The keys. Where there is a /dev/kbd (mini-9pi's, and a window of
 * mini-rio's: the keys down, at each change), a key is down and up as
 * it is, and the console's characters are only what was typed. Where
 * there is none, a key is down from its character to the next tick;
 * and so are, with a /dev/kbd too, the keys that edit a text (Enter,
 * Backspace, Tab, Escape): theirs is the console's order, after the
 * characters typed before them, which the kbd's messages do not keep.
 * Ctrl-Q ends the program, as on the playground's platforms, and so
 * does Delete.
 *
 * Where it stands: below are Display and Draw (the draw device's
 * messages, as every graphical program of mini-9pi's sends them),
 * the kernel's mouse and keyboard files, and its clock; above, the
 * two platforms, which differ only by what they do when this loop
 * says "show this frame". In a window of mini-rio's the same files
 * are the window's: the program does not know which it has.
 *
 * design:
 * The clock's rule is the fixed time step of games: the world
 * advances by ticks of one length, as many as the real time that
 * passed asks for, and drawing is done when there is time left. The
 * other rule, one update a frame given the frame's own duration,
 * makes the game's physics depend on the machine's speed -- a jump
 * a little higher on a slow one (Integrate.mli has the arithmetic;
 * Glenn Fiedler's "Fix Your Timestep!" is the usual reference).
 *
 * usage: game [-frames n [-script script] [-fixed-time seconds]] [name=value]...
 *   keys=on     (a flag) the keys down at each of the system's messages
 *               (/dev/kbd), on the standard error
 *   stats=on    (a flag) every 40 frames, what a frame cost, on the
 *               standard error: the update, the view, the showing
 *   -frames n   n frames at once, the script's keys in them, then the
 *               picture stays: a session that is the same each time,
 *               for a test to compare its screen (Session.mli) *)

(* a platform's own: where it draws (made again when the window changes:
 * the one before is freed), the picture's square there (for the mouse),
 * a frame shown (the view's shapes, the frames a second to write;
 * false when there was nothing to draw: the frame before, again) *)
type 'w window = {
  make : Display.t -> 'w;
  at : 'w -> Rectangle.t;
  show : Display.t -> 'w -> Playground.shape list -> int -> bool;
  free : 'w -> unit;
}

(* Playground_platform's two, the second with the platform's window *)
val flags : < Cap.argv ; .. > -> Playground.flags
val run_app :
  'w window -> < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. > ->
  Playground.flags -> ('model, 'msg) Playground.app -> unit
