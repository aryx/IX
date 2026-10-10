(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The platform without a window (docs/plans/plan_playground.md,
 * decision 4): the program is run a number of frames, its keys and its
 * mouse those of a script, and the last frame is written as a picture
 * (PPM). The playground's own tests run its games so (its platforms'
 * -dump-frame, -fixed-time and -script: the same words here, Session's,
 * so that a frame is compared with theirs), and ix's run on Linux with
 * no SDL.
 *
 * The pixels are Shape_render_software's, in a Framebuffer of the
 * playground's screen, 1000 by 1000 (the flag size=n: n by n, the
 * picture scaled, as a platform with a smaller window draws it). The
 * flag redraw=each draws every frame, by what changed since the one
 * before (Redraw), as a platform with a window does: the same picture.
 *
 * usage: game -dump-frame n file.ppm [-fixed-time seconds] [-script script] [name=value]... *)

let flags (caps : < Cap.argv ; .. >) : Playground.flags = Playground.flags_of_strings (Session.parse (CapSys.argv caps)).args

(* no window, no cursor *)
let set_cursor (_ : Playground.cursor) : unit = ()

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  let cli = Session.parse (CapSys.argv caps) in
  if cli.frames <= 0 || cli.file = "" then failwith ("this program has no window here: -dump-frame n file. " ^ Session.usage);
  let run = Session.start app flags in
  let size = match List.assoc_opt "size" flags with Some s -> int_of_string s | None -> int_of_float Playground.default_width in
  let scale = float size /. Playground.default_width in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  let picture = Framebuffer.create ~width:size ~height:size in
  let redraw = Redraw.create ~width:size ~height:size ~scale options in
  let counter = Session.fps_counter ~width:size ~height:size ~scale 0 in
  (* The last frame is what is written, so it alone is drawn; with the
   * flag redraw=each, every frame is, as a platform with a window
   * draws them: what changed since the one before (Redraw), put in the
   * picture kept here. The picture is the same, which
   * games/tests/frames.sh holds Redraw to (a game whose whole picture
   * changes at each frame is then minutes by mini-ml's code). *)
  (* (redraw=all: every frame too, and each one whole: what a frame costs) *)
  let how = List.assoc_opt "redraw" flags in
  if how = Some "all" then Redraw.enabled := false;
  let each = how = Some "each" || how = Some "all" in
  for n = 1 to cli.frames do
    Session.frame run cli.script n (Session.time_of_frame cli n);
    (* (the view is taken at each frame, as a window's platform takes
     * it, though only the last is drawn: a program may count on it,
     * as the playground's Gui does, whose widgets of an update are kept
     * until the view that draws them; five frames' labels drawn at
     * once, one over the other, were bolder than the playground's) *)
    let shapes = Session.view run in
    if each || n = cli.frames then Redraw.paste picture (Redraw.frame redraw (shapes @ [ counter ]))
  done;
  FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc (Session.ppm picture)) (Fpath.v cli.file)
