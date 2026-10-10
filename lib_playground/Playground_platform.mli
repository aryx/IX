(* What runs a Playground program: its window, its clock, its keys and
 * its mouse (docs/plans/plan_playground.md). One interface, a module of
 * this name in each directory beside (ppm/: no window, a frame written
 * to a file, for Linux and the tests; sdl/: a window on Linux); a
 * program is linked with one of them.
 *
 * ix: the playground's playground/Playground_platform.mli has more (the
 * clipboard, pictures loaded ahead, the window's pixels
 * read back), each to come with the first program that
 * asks for it (its documents stored are platforms/Store's here, one
 * module for every platform, which a library may name: a platform is
 * a program's choice, at its link); and its run_app has optional arguments, which mini-ml
 * has not:
 *   run_app ?rendering ?flags ?network ?window app
 * Here the flags are said, and the capabilities given (ix's way: what
 * reaches the system takes the capability to). So a program's last
 * line, the playground's
 *   let main = Program.main __MODULE__ (fun () ->
 *     Playground_platform.run_app ~flags:(Playground_platform.flags ()) app)
 * is here
 *   let () = Cap.main (fun caps ->
 *     Playground_platform.run_app caps (Playground_platform.flags caps) app)
 *)

(* The parameters the program was started with (see Playground.flags):
 * the command line's arguments without a dash, name=value or name. *)
val flags : < Cap.argv ; .. > -> Playground.flags

(* The program run: its init given the flags, then each frame the events
 * since the last one given to its update (through its subscriptions),
 * and its view drawn. The capabilities are every platform's: a window
 * and its events (Plan 9's: the draw device, the mouse, the keyboard,
 * the threads that read them), a file written (ppm/). *)
val run_app :
  < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. > ->
  Playground.flags -> ('model, 'msg) Playground.app -> unit

(* The mouse's cursor over the window from now on (Playground.cursor):
 * the system's own shape, in sdl/; nothing yet on Plan 9 nor without a
 * window. A program calls it when what is under the mouse changes
 * (mini-netscape: a hand over a link), not at each frame. *)
val set_cursor : Playground.cursor -> unit
