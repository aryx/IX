(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineSDL.mli *)
open Tsdl

type event = Quit | At of int * int | Button of int * bool | Key of int * bool | Wheel of int
type t = { present : int -> int -> string -> unit; poll : unit -> event list; cursor : int -> unit; play : string -> unit; queued : unit -> int }

let key_byte usage ~shift ~ctrl =
  let plain = "abcdefghijklmnopqrstuvwxyz1234567890\n\027\b\t -=[]\\\000;'`,./"
  and shifted = "ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()\n\027\b\t _+{}|\000:\"~<>?" in
  if usage >= 4 && usage <= 56 then
    if ctrl && usage <= 29 then Some (usage - 3)
    else (match Char.code (if shift then shifted else plain).[usage - 4] with 0 -> None | c -> Some c)
  else match usage with 82 -> Some 128 | 81 -> Some 129 | 80 -> Some 130 | 79 -> Some 131 | 76 -> Some 127 | _ -> None

let ok = function Ok v -> v | Error _ -> failwith ("SDL: " ^ Sdl.get_error ())

let create ~title =
  ok (Sdl.init Sdl.Init.video);
  (* the window, its renderer and the frame's texture, made at the first
   * frame (and again if the frame's size changes) *)
  let window = ref None and texture = ref None and size = ref (0, 0) and last = ref "" in
  let pixels = ref (Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 0) in
  let draw () =
    match !window, !texture with
    | Some (_, r), Some tex -> ok (Sdl.render_clear r); ok (Sdl.render_copy r tex); Sdl.render_present r
    | _ -> () in
  let present w h data =
    if !size <> (w, h) then begin
      (match !window with
       | None ->
           let times = match Sdl.get_current_display_mode 0 with Ok mode -> max 1 (mode.Sdl.dm_h * 3 / 4 / h) | Error _ -> 1 in
           let win = ok (Sdl.create_window title ~w:(times * w) ~h:(times * h) Sdl.Window.(windowed + resizable)) in
           window := Some (win, ok (Sdl.create_renderer win))
       | Some (win, _) -> Sdl.set_window_size win ~w ~h);
      let _, r = Option.get !window in
      (* the frame drawn as large as fits, its proportions kept; and the
       * mouse's place given in the frame's pixels *)
      ok (Sdl.render_set_logical_size r w h);
      texture := Some (ok (Sdl.create_texture r Sdl.Pixel.format_rgb24 Sdl.Texture.access_streaming ~w ~h));
      pixels := Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (3 * w * h);
      size := (w, h); last := ""
    end;
    if data <> !last then begin
      last := data;
      let px = !pixels in
      String.iteri (fun i c -> Bigarray.Array1.unsafe_set px i (Char.code c)) data;
      ok (Sdl.update_texture (Option.get !texture) None px (3 * w));
      draw ()
    end in
  let e = Sdl.Event.create () in
  (* SDL's buttons as Plan 9's: left 1, middle 2, right 4 *)
  let button b = if b = Sdl.Button.left then 1 else if b = Sdl.Button.middle then 2 else if b = Sdl.Button.right then 4 else 0 in
  let poll () =
    let evs = ref [] in
    let add ev = evs := ev :: !evs in
    while Sdl.poll_event (Some e) do
      let k = Sdl.Event.(get e typ) in
      let is t = k = t in
      if is Sdl.Event.quit then add Quit
      else if is Sdl.Event.window_event then
        (* a window uncovered or resized has lost its frame *)
        (match Sdl.Event.(window_event_enum (get e window_event_id)) with `Exposed | `Size_changed -> draw () | _ -> ())
      else if (is Sdl.Event.key_down || is Sdl.Event.key_up) && Sdl.Event.(get e keyboard_repeat) = 0 then
        add (Key (Sdl.Event.(get e keyboard_scancode), is Sdl.Event.key_down))
      else if is Sdl.Event.mouse_button_down || is Sdl.Event.mouse_button_up then begin
        let b = button Sdl.Event.(get e mouse_button_button) in
        if b <> 0 then add (Button (b, is Sdl.Event.mouse_button_down))
      end
      else if is Sdl.Event.mouse_motion then add (At (Sdl.Event.(get e mouse_motion_x), Sdl.Event.(get e mouse_motion_y)))
      else if is Sdl.Event.mouse_wheel then add (Wheel (- Sdl.Event.(get e mouse_wheel_y)))
    done;
    List.rev !evs in
  (* the arrow, or a hand over what can be clicked, as the system draws
   * them; each made once, when first asked for *)
  let cursors = Hashtbl.create 2 in
  let cursor n =
    match Hashtbl.find_opt cursors n with
    | Some c -> Sdl.set_cursor (Some c)
    | None ->
        (match Sdl.create_system_cursor (if n = 1 then Sdl.System_cursor.hand else Sdl.System_cursor.arrow) with
         | Ok c -> Hashtbl.replace cursors n c; Sdl.set_cursor (Some c)
         | Error _ -> ()) in
  (* the sound, opened at the first samples (None: no sound here) *)
  let device = lazy (
    match Sdl.init_sub_system Sdl.Init.audio with
    | Error _ -> None
    | Ok () ->
        let spec = { Sdl.as_freq = 8000; as_format = Sdl.Audio.s8; as_channels = 1; as_silence = 0; as_samples = 256; as_size = 0l; as_callback = None } in
        (match Sdl.open_audio_device None false spec 0 with
         | Ok (d, _) -> Sdl.pause_audio_device d false; Some d
         | Error _ -> None)) in
  let play samples =
    match Lazy.force device with
    | None -> ()
    | Some d ->
        let queued = Sdl.get_queued_audio_size d in
        if queued <= 4000 then begin
          let samples = if queued = 0 then String.make 800 '\000' ^ samples else samples in
          let ba = Bigarray.Array1.create Bigarray.int8_signed Bigarray.c_layout (String.length samples) in
          String.iteri (fun i c -> Bigarray.Array1.unsafe_set ba i (let v = Char.code c in if v > 127 then v - 256 else v)) samples;
          ignore (Sdl.queue_audio d ba)
        end in
  let queued () = match Lazy.force device with Some d -> Sdl.get_queued_audio_size d | None -> 0 in
  { present; poll; cursor; play; queued }
