(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The platform with a window on Linux (SDL): what bin/mini-drscheme is
 * linked with. The playground's software platform again, as ../software
 * is, with SDL's window where that one has Plan 9's draw device: a
 * frame is drawn by the program in its own memory (Redraw, over
 * Shape_render_software: the parts that changed since the frame
 * before), copied into the window's picture and shown.
 *
 * The window starts a square of 1000 pixels, the playground's units one
 * for one, or of the screen's usable height where that is less (the
 * flag size=n: n pixels), and may be given another size: the picture is a square, the
 * playground's 1000 units on the smaller of the window's sides, in its
 * middle, as ../software's, and drawn again at that size (not the old
 * pixels stretched: the letters stay sharp). The playground's platforms
 * have this for the one drawn by Cairo (Native_loop_2d's on_resize).
 *
 * The clock is ../Plan9_loop's: a program's Tick is a sixtieth of a
 * second of its world, so the ticks due since the start are counted on
 * the system's clock and all given, then one frame is drawn.
 *
 * The keys. SDL says a key down and up, and apart from them the
 * characters typed (Sub.on_typed). Ctrl-Q ends the program, as on the
 * playground's platforms, and so does closing the window.
 *
 * usage: program [-frames n [-script script] [-fixed-time seconds]] [name=value]...
 *   -frames n   n frames at once, the script's keys in them, then the
 *               picture stays (Session.mli)
 *   redraw=all  (a flag) each frame drawn whole, not what changed only
 *   window=WxH  (a flag) the program's screen is the window's, a unit a
 *               pixel, W by H at first and following it after
 *               (Session.mli); what a browser asks, not a game *)

open Tsdl

let ok = function Ok v -> v | Error _ -> failwith ("SDL: " ^ Sdl.get_error ())

(* an SDL key, as the playground names it (a browser's names; a letter
 * is its own) *)
let key_name (k : int) : string option =
  if k = Sdl.K.up then Some "ArrowUp"
  else if k = Sdl.K.down then Some "ArrowDown"
  else if k = Sdl.K.left then Some "ArrowLeft"
  else if k = Sdl.K.right then Some "ArrowRight"
  else if k = Sdl.K.lshift || k = Sdl.K.rshift then Some "Shift"
  else if k = Sdl.K.lctrl || k = Sdl.K.rctrl then Some "Control"
  else if k = Sdl.K.lalt || k = Sdl.K.ralt then Some "Alt"
  else if k = Sdl.K.space then Some "space"
  else if k = Sdl.K.return || k = Sdl.K.kp_enter then Some "Enter"
  else if k = Sdl.K.backspace then Some "Backspace"
  else if k = Sdl.K.tab then Some "Tab"
  else if k = Sdl.K.escape then Some "Escape"
  else if k = Sdl.K.delete then Some "Delete"
  else if k > 32 && k < 127 then Some (String.make 1 (Char.chr k))
  else None

let flags (caps : < Cap.argv ; .. >) : Playground.flags = Playground.flags_of_strings (Session.parse (CapSys.argv caps)).args

(* the ticks given at once, at most (Plan9_loop's) *)
let most = 30

(* where the program draws: the picture's square in the window (its
 * side, its corner, the pixels a unit), the texture and the bytes given
 * to it, and what was drawn last (Redraw: a frame is the parts that
 * changed) *)
type picture = { w : int; h : int; x : int; y : int; scale : float; texture : Sdl.texture; pixels : (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t; redraw : Redraw.t }

(* [follows]: the picture is the window, a unit a pixel (the flag
 * window, Session.mli); else the square on its smaller side *)
let picture (renderer : Sdl.renderer) ~(follows : bool) ((ww, wh) : int * int) : picture =
  let size = max 1 (min ww wh) in
  let w, h, scale = if follows then (max 1 ww, max 1 wh, 1.) else (size, size, float size /. Playground.default_width) in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  { w; h; x = (ww - w) / 2; y = (wh - h) / 2; scale;
    (* a Framebuffer's bytes as they are: blue, green, red, and one not used *)
    texture = ok (Sdl.create_texture renderer Sdl.Pixel.format_argb8888 Sdl.Texture.access_streaming ~w ~h);
    pixels = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (w * h * 4);
    redraw = Redraw.create ~width:w ~height:h ~scale options }

(* the system's cursors, made once each (the playground's Native_cursor) *)
let cursors : (Playground.cursor * Sdl.cursor) list ref = ref []

let set_cursor (c : Playground.cursor) : unit =
  match c with
  | Playground.Hidden -> ignore (Sdl.show_cursor false)
  | _ -> (
      ignore (Sdl.show_cursor true);
      match List.assoc_opt c !cursors with
      | Some cursor -> Sdl.set_cursor (Some cursor)
      | None -> (
          let system =
            match c with
            | Playground.Hand -> Sdl.System_cursor.hand
            | Playground.Text -> Sdl.System_cursor.ibeam
            | Playground.Crosshair -> Sdl.System_cursor.crosshair
            | _ -> Sdl.System_cursor.arrow
          in
          match Sdl.create_system_cursor system with
          | Ok cursor ->
              cursors := (c, cursor) :: !cursors;
              Sdl.set_cursor (Some cursor)
          | Error _ -> ()))

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  let cli = Session.parse (CapSys.argv caps) in
  let own = Playground.flags_of_strings cli.args in
  if List.assoc_opt "redraw" own = Some "all" then Redraw.enabled := false;
  (* (the window's name: the program's) *)
  let name = Filename.remove_extension (Filename.basename (CapSys.argv caps).(0)) in
  ok (Sdl.init Sdl.Init.video);
  (* old: a window of 800 (the author, 2026-10-09, of mini-office's
   * labels there: "it's hard to see the label"): a unit of the
   * playground is a pixel now, a label a quarter taller, where the
   * screen has the room (its title bar's 40 pixels left) *)
  let size =
    match List.assoc_opt "size" own with
    | Some s -> int_of_string s
    | None -> (
        match Sdl.get_display_usable_bounds 0 with
        | Ok r -> max 400 (min (int_of_float Playground.default_width) (Sdl.Rect.h r - 40))
        | Error _ -> 800)
  in
  (* the flag window: the program's screen is the window's (Session.mli),
   * 1280 by 900 if no size is said and the display has the room *)
  let follows, (w, h) =
    match Session.window flags with
    | Square -> (false, (size, size))
    | Follows (Some size) -> (true, size)
    | Follows None -> (
        match Sdl.get_display_usable_bounds 0 with
        | Ok r -> (true, (max 400 (min 1280 (Sdl.Rect.w r)), max 400 (min 900 (Sdl.Rect.h r - 40))))
        | Error _ -> (true, (1000, 800)))
  in
  let window = ok (Sdl.create_window name ~w ~h Sdl.Window.resizable) in
  let renderer = ok (Sdl.create_renderer window) in
  let run = Session.start app flags in
  let window_size = ref (ok (Sdl.get_renderer_output_size renderer)) in
  let pic = ref (picture renderer ~follows !window_size) in
  (* the program told its screen: the window's, or the 1000 units still
   * (as on Plan 9) *)
  let told () : unit =
    Session.event run (Sub.EResized (if follows then (!pic.w, !pic.h) else (int_of_float Playground.default_width, int_of_float Playground.default_height))) in
  if follows then told ();
  (* the window given another size: the picture made again for it, and
   * the program told *)
  let resized () : unit =
    let now = ok (Sdl.get_renderer_output_size renderer) in
    if now <> !window_size then begin
      window_size := now;
      Sdl.destroy_texture !pic.texture;
      pic := picture renderer ~follows now;
      told ()
    end in
  (* a frame: its parts that changed, each copied where it goes in the
   * window's picture *)
  let show (shapes : Playground.shape list) (fps : int) : unit =
    resized ();
    let { w; h; x; y; scale; texture; pixels; redraw } = !pic in
    let counter = Session.fps_counter ~width:w ~height:h ~scale fps in
    let parts = Redraw.frame redraw (shapes @ [ counter ]) in
    List.iter
      (fun (((x0, y0, x1, _), fb) : (int * int * int * int) * Framebuffer.t) ->
        let row = 4 * (x1 - x0) in
        for y = 0 to fb.height - 1 do
          let from = y * row and at = 4 * (((y0 + y) * w) + x0) in
          for i = 0 to row - 1 do
            Bigarray.Array1.unsafe_set pixels (at + i) (Char.code (Bytes.unsafe_get fb.pixels (from + i)))
          done
        done)
      parts;
    if parts <> [] then ok (Sdl.update_texture texture None pixels (w * 4));
    (* (shown again though nothing changed: a window uncovered is drawn) *)
    ok (Sdl.set_render_draw_color renderer 255 255 255 255);
    ok (Sdl.render_clear renderer);
    ok (Sdl.render_copy ~dst:(Sdl.Rect.create ~x ~y ~w ~h) renderer texture);
    Sdl.render_present renderer in
  Sdl.start_text_input ();
  let e = Sdl.Event.create () in
  let quit = ref false in
  let control () : bool = Sdl.get_mod_state () land Sdl.Kmod.ctrl <> 0 in
  (* the mouse: its place in the playground's units (the middle of the
   * picture is 0, 0, up is more) *)
  let at (x : int) (y : int) : Sub.event =
    let p = !pic in
    Sub.EMouseMove (int_of_float ((float (x - p.x) -. (float p.w /. 2.)) /. p.scale), int_of_float (((float p.h /. 2.) -. float (y - p.y)) /. p.scale)) in
  let events () : unit =
    while Sdl.poll_event (Some e) do
      let k = Sdl.Event.(get e typ) in
      if k = Sdl.Event.quit then quit := true
      else if k = Sdl.Event.mouse_motion then Session.event run (at Sdl.Event.(get e mouse_motion_x) Sdl.Event.(get e mouse_motion_y))
      else if k = Sdl.Event.mouse_button_down || k = Sdl.Event.mouse_button_up then begin
        let which = Sdl.Event.(get e mouse_button_button) and down = k = Sdl.Event.mouse_button_down in
        Session.event run (at Sdl.Event.(get e mouse_button_x) Sdl.Event.(get e mouse_button_y));
        if which = Sdl.Button.left then Session.event run (Sub.EMouseButton down)
        else if which = Sdl.Button.middle then Session.event run (Sub.EMiddleMouseButton down)
        else if which = Sdl.Button.right then Session.event run (Sub.ERightMouseButton down)
      end
      (* the wheel's notches, up positive: a system set to "natural"
       * scrolling says them flipped (the playground's Native_loop_2d) *)
      else if k = Sdl.Event.mouse_wheel then begin
        let y = float Sdl.Event.(get e mouse_wheel_y) in
        Session.event run (Sub.EMouseWheel (if Sdl.Event.(get e mouse_wheel_direction) = Sdl.Event.mouse_wheel_flipped then -.y else y))
      end
      else if k = Sdl.Event.text_input && not (control ()) then Session.event run (Sub.ETyped Sdl.Event.(get e text_input_text))
      else if k = Sdl.Event.key_down || k = Sdl.Event.key_up then begin
        let code = Sdl.Event.(get e keyboard_keycode) and down = k = Sdl.Event.key_down in
        if down && control () && code = Sdl.K.q then quit := true
        (* (a key held says itself down again and again: once is enough) *)
        else if not (down && Sdl.Event.(get e keyboard_repeat) <> 0) then
          match key_name code with Some name -> Session.event run (Sub.EKeyChanged (down, name)) | None -> ()
      end
    done in
  if cli.frames > 0 then begin
    (* a session played at once, then its picture, until the window is closed *)
    for n = 1 to cli.frames do
      Session.frame run cli.script n (Session.time_of_frame cli n);
      (* (the view taken at each frame, as ppm/ does and says why) *)
      ignore (Session.view run)
    done;
    while not !quit do
      show (Session.view run) 0;
      Sdl.delay 50l;
      while Sdl.poll_event (Some e) do
        if Sdl.Event.(get e typ) = Sdl.Event.quit || (Sdl.Event.(get e typ) = Sdl.Event.key_down && control () && Sdl.Event.(get e keyboard_keycode) = Sdl.K.q) then quit := true
      done
    done
  end
  else begin
    let start = Unix.gettimeofday () in
    (* the ticks given so far; the frames drawn in the second that began at [since], and in the one before it *)
    let given = ref 0 and since = ref start and drawn = ref 0 and fps = ref 0 in
    while not !quit do
      events ();
      let now = Unix.gettimeofday () in
      let due = int_of_float ((now -. start) *. 60.) - !given in
      (* (more than [most]: the others are not owed any more) *)
      if due > most then given := !given + (due - most);
      for _ = 1 to min due most do
        incr given;
        (* (each tick its own time, Plan9_loop's way)
         * old: Session.frame run None !given now *)
        Session.frame run None !given (start +. (float !given /. 60.))
      done;
      if due > 0 then begin
        show (Session.view run) !fps;
        incr drawn;
        if now -. !since >= 1. then (fps := !drawn; drawn := 0; since := now)
      end;
      Sdl.delay 5l
    done
  end;
  Sdl.quit ()
