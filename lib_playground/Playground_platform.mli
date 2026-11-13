(* A platform is what runs a Playground program: its window, its
 * clock, its keys and its mouse (docs/plans/done/plan_playground.md).
 * There is one interface, and a module of this name in each directory
 * beside it (ppm/ has no window and writes a frame to a file, for
 * Linux and the tests; sdl/ has a window on Linux). A program is
 * linked with one of them.
 *
 * Here are the four, by who makes the pixels and who shows them:
 *
 *              runs on     the pixels are made by      and shown by
 *   ppm/       Linux       Shape_render_software       nobody: the last
 *                                                      frame is a file
 *   sdl/       Linux       Shape_render_software       SDL's window
 *   software/  mini-9pi    Shape_render_software       the draw device,
 *                                                      given a picture
 *   draw/      mini-9pi    the kernel's draw device,   the same device
 *                          one message per shape
 *
 * The first three share one renderer, ix's own, behind three ways
 * out; the fourth computes nothing and asks the system. The tests'
 * frames check that the same game looks the same on all four. On
 * mini-9pi the two share their loop (Plan9_loop, which reads the
 * mouse, the keys and the clock). Everywhere, Session steps the
 * program, so a platform is little more than its way out.
 *
 *     a program  ---  Playground (shapes, an app)
 *                          |
 *                  Playground_platform.run_app        <- chosen at link
 *                    /       |         |        \
 *                  ppm      sdl     software    draw
 *                    \       |        /           |
 *                 Shape_render_software      /dev/draw's messages
 *                 (Fill, Line, Circle,       (Display, Draw)
 *                  Stroke, Hershey, Blit)
 *
 * ix: the playground's playground/Playground_platform.mli has more
 * (pictures loaded ahead, the window's pixels read back), and each
 * will come with the first program that asks for it. Its stored
 * documents are platforms/Store's here: one module for every
 * platform, which a library may name, since a platform is a program's
 * choice at its link. And its run_app has optional arguments, which
 * mini-ml does not have:
 *   run_app ?rendering ?flags ?network ?window app
 * Here the flags must be given, and so must the capabilities (that is
 * ix's way: what reaches the system takes the capability to do it).
 * So a program's last line, which in the playground is
 *   let main = Program.main __MODULE__ (fun () ->
 *     Playground_platform.run_app ~flags:(Playground_platform.flags ()) app)
 * is here
 *   let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () ->
 *     Playground_platform.run_app caps (Playground_platform.flags caps) app;
 *     Exit.OK)))
 * (flags ends a program that is asked for -help, or given an option
 * it does not know, with Exit.ExitCode; see Session.parse.)
 *
 * design:
 * One interface with several modules of the same name, one of them
 * picked by the build, is the oldest way to have a program run on
 * several systems. It is also the one that asks nothing of the
 * language: no functor, no object, and no table of functions looked
 * up at each call (mini-ml has neither of the first two). It is a C
 * program's one header with a file per system, and Plan 9's kernel is
 * built this way: the portable code calls names that each
 * architecture's directory defines. What it gives up is choosing when
 * the program runs: a game here is linked once for each platform it
 * is wanted on.
 *
 * terminology:
 * Platform is Elm's word (its Platform module runs a program). The
 * same part is called a backend in a compiler or a graphics library,
 * a driver in a kernel, and a port when a system is moved to a
 * machine.
 *)

(* [flags caps] gives the parameters the program was started with (see
 * Playground.flags): the command line's arguments without a dash, as
 * name=value or name. *)
val flags : < Cap.argv ; Cap.stdout ; Cap.stderr ; .. > -> Playground.flags

(* [run_app caps flags app] runs the program. Its init is given the
 * flags; then, at each frame, the events since the last frame are
 * given to its update (through its subscriptions), and its view is
 * drawn. The capabilities are those of all the platforms: a window
 * and its events (on Plan 9, the draw device, the mouse, the keyboard,
 * and the threads that read them), and a file to write (ppm/). *)
val run_app :
  < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ;
    Cap.clock ; .. > ->
  Playground.flags -> ('model, 'msg) Playground.app -> unit

(* [set_cursor c] sets the mouse's cursor over the window from now on
 * (Playground.cursor). In sdl/ it is the system's own shape; on Plan 9
 * and without a window, it does nothing yet. A program calls it when
 * what is under the mouse changes (as mini-netscape does, for a hand
 * over a link), not at each frame. *)
val set_cursor : Playground.cursor -> unit

(* The clipboard is the text that the desktop's programs share: a copy
 * puts text there ([set_clipboard], Ctrl+C) and a paste takes it
 * ([clipboard], which gives "" when it holds no text). Like
 * [set_cursor], these are effects, called from an update. In sdl/ the
 * clipboard is SDL's; on Plan 9 it is the window system's /dev/snarf
 * (Snarf); without a window (ppm/) it is a text the program keeps
 * itself. *)
val clipboard : unit -> string
val set_clipboard : string -> unit
