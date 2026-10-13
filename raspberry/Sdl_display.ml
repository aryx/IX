(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The display in an SDL window (tsdl): the framebuffer as a streaming
 * texture in its own format (RGB565 for 16 bits: no conversion), sized
 * at its first frame, drawn when it changed; the keys by SDL's
 * scancodes, which are USB HID usages (SDL took them from there); the
 * mouse, relative as a USB mouse is: a click grabs the host's pointer
 * (SDL's relative mode: its motion the guest's, the host cursor gone),
 * Ctrl-Alt-G lets it go, as QEMU's window does; or, [absolute], the
 * pointer left to the host and its place in the window given (for a
 * machine whose mouse is not a USB one: tiny-machine's window). The
 * window can be resized, the frame drawn as large as fits in it, its
 * proportions kept; [fit] starts it large (tiny-machine's 640 by 480
 * is small on a large screen). The one module of mini-qemu linking a C library (plan_pi.md, decision 9). *)

open Tsdl

let ok = function Ok v -> v | Error _ -> failwith ("SDL: " ^ Sdl.get_error ())

(* the texture's format for the framebuffer's depth *)
let format = function
  | 16 -> Sdl.Pixel.format_rgb565
  | 24 -> Sdl.Pixel.format_rgb24
  | _ -> Sdl.Pixel.format_rgba32   (* red first, as QEMU's board (Framebuffer) *)

(* The jack's samples (Pwm) to the host's sound card, by SDL's queue: 512
 * at a time, the card opened at the rate the first ones come at (and
 * again when the guest changes it). The card plays at our clock, the
 * board at its own: when the board is slower, the queue runs empty and
 * SDL plays silence, the sound broken (the WAV of -audiodev is the
 * board's time, whole); when it is ahead by more than half a second
 * (a window's loop keeps it from that), what waits is dropped. A host
 * with no card is silent. *)
let audio () : rate:int -> int -> int -> unit =
  let chunk = 512 in
  let samples = Bigarray.Array1.create Bigarray.int16_signed Bigarray.c_layout (2 * chunk) and n = ref 0 in
  (* the card and its rate; None once it could not be opened *)
  let card = ref (Some None) in
  let open_at rate =
    (match !card with Some (Some (d, _)) -> Sdl.close_audio_device d | _ -> ());
    card := None;
    match Sdl.init_sub_system Sdl.Init.audio with
    | Error _ -> ()
    | Ok () ->
        let want = { Sdl.as_freq = rate; as_format = Sdl.Audio.s16_sys; as_channels = 2; as_silence = 0; as_samples = 1024; as_size = 0l; as_callback = None } in
        (match Sdl.open_audio_device None false want 0 with
         | Error _ -> ()
         | Ok (d, _) -> Sdl.pause_audio_device d false; card := Some (Some (d, rate))) in
  fun ~rate left right ->
    samples.{2 * !n} <- left;
    samples.{(2 * !n) + 1} <- right;
    incr n;
    if !n = chunk then begin
      n := 0;
      (match !card with
       | Some (Some (_, r)) when r = rate -> ()
       | Some _ -> open_at rate
       | None -> ());
      match !card with
      | Some (Some (d, _)) ->
          if Sdl.get_queued_audio_size d > 2 * rate then Sdl.clear_queued_audio d;
          ignore (Sdl.queue_audio d samples)
      | _ -> ()
    end

let create ?(absolute = false) ?(fit = false) ?meter ~title () =
  ok (Sdl.init Sdl.Init.video);
  let window = ref None and texture = ref None and shape = ref None and last = ref "" in
  (* the meter's strip: its texture, the stamp it was drawn at, its text *)
  let strip = ref None and stamp = ref (-1) and said = ref "" and grabbed = ref false in
  let name () = (if !said = "" then title else title ^ "  " ^ !said) ^ (if !grabbed then " (Ctrl-Alt-G releases the mouse)" else "") in
  let pixels = ref (Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 0) in
  (* the last frame drawn again: a window resized or uncovered has lost it *)
  let again = ref (fun () -> ()) in
  let present (g : Framebuffer.geometry) data =
    let m = Option.map (fun f -> f ~width:g.width) meter in
    let rows = match m with Some (m : Display.meter) -> m.rows | None -> 0 in
    if !shape <> Some g then begin
      (match !window with
       | None ->
           (* the window can be resized: the frame is drawn as large as
            * fits in it (render_set_logical_size, below, which also gives
            * the mouse's place in the frame's pixels). [fit]: it starts
            * at the largest whole number of times the frame that three
            * quarters of the screen's height hold *)
           let times =
             if not fit then 1
             else match Sdl.get_current_display_mode 0 with
               | Ok mode -> max 1 (mode.Sdl.dm_h * 3 / 4 / (g.height + rows))
               | Error _ -> 1 in
           let win = ok (Sdl.create_window title ~w:(times * g.width) ~h:(times * (g.height + rows)) Sdl.Window.(windowed + resizable)) in
           window := Some (win, ok (Sdl.create_renderer win))
       | Some (win, _) -> Sdl.set_window_size win ~w:g.width ~h:(g.height + rows));
      let _, r = Option.get !window in
      ok (Sdl.render_set_logical_size r g.width (g.height + rows));
      strip := (if rows > 0 then Some (ok (Sdl.create_texture r Sdl.Pixel.format_rgb24 Sdl.Texture.access_streaming ~w:g.width ~h:rows)) else None);
      stamp := -1;
      texture := Some (ok (Sdl.create_texture r (format g.depth) Sdl.Texture.access_streaming ~w:g.width ~h:g.height));
      pixels := Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (String.length data);
      shape := Some g; last := ""
    end;
    (* the meter's strip and line, when they have changed *)
    let metered =
      match m, !strip with
      | Some m, Some tex when m.stamp <> !stamp ->
          stamp := m.stamp; said := m.text;
          let px = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (String.length m.pixels) in
          String.iteri (fun i c -> Bigarray.Array1.unsafe_set px i (Char.code c)) m.pixels;
          ok (Sdl.update_texture tex None px (g.width * 3));
          Option.iter (fun (win, _) -> Sdl.set_window_title win (name ())) !window;
          true
      | _ -> false in
    let screen = Sdl.Rect.create ~x:0 ~y:0 ~w:g.width ~h:g.height in
    let draw r tex =
      ok (Sdl.render_clear r);
      ok (Sdl.render_copy ~dst:screen r tex);
      Option.iter (fun s -> ok (Sdl.render_copy ~dst:(Sdl.Rect.create ~x:0 ~y:g.height ~w:g.width ~h:rows) r s)) !strip;
      Sdl.render_present r in
    again := (fun () -> match !window, !texture with Some (_, r), Some tex -> draw r tex | _ -> ());
    (* a frame like the last one: nothing to draw *)
    if data = !last then (if metered then let _, r = Option.get !window in draw r (Option.get !texture))
    else begin
      (* OPTIMIZATION: only the rows that changed, the first to the last,
       * are copied and given to the texture: a cursor that moves is 32
       * rows of the 768, and the whole frame, a byte at a time, was 10
       * ms of each 33, which the board's time lost
       * (docs/plans/plan_mini_qemu_speed.md).
       * old: String.iteri (fun i c -> Bigarray.Array1.unsafe_set px i (Char.code c)) data;
       *      ok (Sdl.update_texture tex None px g.pitch) *)
      let same y = String.length !last = String.length data && String.sub data (y * g.pitch) g.pitch = String.sub !last (y * g.pitch) g.pitch in
      let lo = ref 0 and hi = ref g.height in
      while !lo < !hi - 1 && same !lo do incr lo done;
      while !hi - 1 > !lo && same (!hi - 1) do decr hi done;
      last := data;
      let px = !pixels in
      for i = !lo * g.pitch to (!hi * g.pitch) - 1 do Bigarray.Array1.unsafe_set px i (Char.code (String.unsafe_get data i)) done;
      let _, r = Option.get !window and tex = Option.get !texture in
      ok (Sdl.update_texture tex (Some (Sdl.Rect.create ~x:0 ~y:!lo ~w:g.width ~h:(!hi - !lo)))
            (Bigarray.Array1.sub px (!lo * g.pitch) ((!hi - !lo) * g.pitch)) g.pitch);
      (* old: render_clear, render_copy r tex (the whole window), render_present *)
      draw r tex
    end in
  let e = Sdl.Event.create () in
  let grab on =
    grabbed := on;
    ok (Sdl.set_relative_mouse_mode on);
    Option.iter (fun (win, _) -> Sdl.set_window_title win (name ())) !window in
  let button b = if b = Sdl.Button.left then 1 else if b = Sdl.Button.right then 2 else if b = Sdl.Button.middle then 4 else 0 in
  let poll () =
    let evs = ref [] in
    let add ev = evs := ev :: !evs in
    while Sdl.poll_event (Some e) do
      (* the event's type, one of Sdl.Event's constants *)
      let k = Sdl.Event.(get e typ) in
      let is t = k = t in
      if is Sdl.Event.quit then add Display.Quit
      else if is Sdl.Event.window_event then
        (match Sdl.Event.(window_event_enum (get e window_event_id)) with `Exposed | `Size_changed -> !again () | _ -> ())
      else if is Sdl.Event.key_down && !grabbed && Sdl.Event.(get e keyboard_keycode) = Sdl.K.g
              && Sdl.get_mod_state () land Sdl.Kmod.ctrl <> 0 && Sdl.get_mod_state () land Sdl.Kmod.alt <> 0 then
        grab false
      else if (is Sdl.Event.key_down || is Sdl.Event.key_up) && Sdl.Event.(get e keyboard_repeat) = 0 then
        add (Display.Key (Sdl.Event.(get e keyboard_scancode), is Sdl.Event.key_down))
      else if is Sdl.Event.mouse_button_down && not !grabbed && not absolute then grab true   (* the grabbing click is the host's *)
      else if is Sdl.Event.mouse_button_down || is Sdl.Event.mouse_button_up then begin
        let b = button Sdl.Event.(get e mouse_button_button) in
        if b <> 0 then add (Display.Button (b, is Sdl.Event.mouse_button_down))
      end
      else if is Sdl.Event.mouse_motion && absolute then
        add (Display.At (Sdl.Event.(get e mouse_motion_x), Sdl.Event.(get e mouse_motion_y)))
      else if is Sdl.Event.mouse_motion && !grabbed then
        add (Display.Motion (Sdl.Event.(get e mouse_motion_xrel), Sdl.Event.(get e mouse_motion_yrel)))
      else if is Sdl.Event.mouse_wheel && !grabbed then add (Display.Wheel (- Sdl.Event.(get e mouse_wheel_y)))
    done;
    List.rev !evs in
  { Display.present; poll }
