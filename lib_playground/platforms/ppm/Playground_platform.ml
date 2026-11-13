(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The platform without a window (docs/plans/done/plan_playground.md,
 * decision 4): the program is run for a number of frames, with the
 * keys and the mouse of a script, and the last frame is written as a
 * picture (PPM). The playground's own tests run its games this way
 * (with its platforms' -dump-frame, -fixed-time and -script; Session
 * takes the same words here, so that a frame can be compared with
 * theirs), and ix's tests run on Linux with no SDL.
 *
 * The pixels are drawn by Shape_render_software, in a Framebuffer of
 * the playground's screen, 1000 by 1000 (with the flag size=n, it is n
 * by n, and the picture is scaled, as a platform with a smaller window
 * draws it). The flag redraw=each draws every frame, by what changed
 * since the one before (Redraw), as a platform with a window does; the
 * picture is the same.
 *
 * usage: game -dump-frame n file.ppm [-fixed-time seconds] [-script script] [-dump-audio file.wav] [name=value]...
 *   -dump-audio   writes the sound of those frames, a sixtieth of a second
 *                 each
 *   size=n        (a flag) makes the picture n pixels square, not 1000
 *   window=WxH    (a flag) makes the picture, and the program's screen, W
 *                 by H
 *   pace=n        (a flag) plays n frames a second by the clock, not as
 *                 fast as they are computed, for two programs that play
 *                 together over a network (games/tests/network.sh) *)

let flags (caps : < Cap.argv ; Cap.stdout ; Cap.stderr ; .. >) : Playground.flags = Playground.flags_of_strings (Session.parse caps).args

(* no window, no cursor *)
let set_cursor (_ : Playground.cursor) : unit = ()

(* no desktop: the program's own text *)
let kept = ref ""
let clipboard () : string = !kept
let set_clipboard (s : string) : unit = kept := s

let run_app (caps : < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ;
    Cap.clock ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  let cli = Session.parse caps in
  (* (heap=game: the collector as Plan9_loop sets it for a game on
   * mini-9pi, for a count of instructions to be the board's) *)
  if List.assoc_opt "heap" flags = Some "game" then Gc.set { (Gc.get ()) with Gc.space_overhead = 700 };
  if cli.frames <= 0 || cli.file = "" then failwith ("this program has no window here: -dump-frame n file. " ^ Session.usage (Filename.basename (CapSys.argv caps).(0)));
  let run = Session.start app flags in
  let size = match List.assoc_opt "size" flags with Some s -> int_of_string s | None -> int_of_float Playground.default_width in
  (* window=WxH: the picture is that large, a unit a pixel, and so is the
   * program's screen (Session.mli) *)
  let width, height, scale =
    match Session.window flags with
    | Follows (Some (w, h)) ->
        Session.event run (Sub.EResized (w, h));
        (w, h, 1.)
    | Follows None | Square -> (size, size, float size /. Playground.default_width)
  in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  let picture = Framebuffer.create ~width ~height in
  let redraw = Redraw.create ~width ~height ~scale options in
  let counter = Session.fps_counter ~width ~height ~scale 0 in
  (* The last frame is what is written, so it alone is drawn; with the
   * flag redraw=each, every frame is, as a platform with a window
   * draws them: what changed since the one before (Redraw), put in the
   * picture kept here. The picture is the same, which
   * games/tests/frames.sh holds Redraw to (a game whose whole picture
   * changes at each frame is then minutes by mini-ml's code). *)
  (* (redraw=all: every frame too, and each one whole: what a frame costs) *)
  let how = List.assoc_opt "redraw" flags in
  Redraw.choose how;
  let each = how = Some "each" || how = Some "all" in
  let pace = match Option.bind (List.assoc_opt "pace" flags) int_of_string_opt with Some p when p > 0 -> 1. /. float p | _ -> 0. in
  for n = 1 to cli.frames do
    if pace > 0. then CapUnix.sleepf caps pace;
    Session.frame run cli.script n (Session.time_of_frame cli n);
    Session.hear cli;
    (* (the view is taken at each frame, as a window's platform takes
     * it, though only the last is drawn: a program may count on it,
     * as the playground's Gui does, whose widgets of an update are kept
     * until the view that draws them; five frames' labels drawn at
     * once, one over the other, were bolder than the playground's) *)
    let shapes = Session.view run in
    if each || n = cli.frames then Redraw.paste picture (Redraw.frame redraw (shapes @ [ counter ]))
  done;
  FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc (Session.ppm picture)) (Fpath.v cli.file);
  Session.dump_audio caps cli
