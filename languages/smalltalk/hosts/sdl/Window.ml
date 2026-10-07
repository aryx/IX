(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)

open Tsdl

let ok = function Ok v -> v | Error _ -> failwith ("SDL: " ^ Sdl.get_error ())

(* the keys that are not characters, as Squeak's codes *)
let key_code (k : int) : int option =
  if k = Sdl.K.return || k = Sdl.K.kp_enter then Some 13
  else if k = Sdl.K.tab then Some 9
  else if k = Sdl.K.backspace then Some 8
  else if k = Sdl.K.left then Some 28
  else if k = Sdl.K.right then Some 29
  else if k = Sdl.K.up then Some 30
  else if k = Sdl.K.down then Some 31
  else None

let run (system : Squeak.system) (scale : int) (transcript : string -> unit) : unit =
  ok (Sdl.init Sdl.Init.video);
  let w = Squeak.width and h = Squeak.height in
  let window = ok (Sdl.create_window "mini-squeak" ~w:(w * scale) ~h:(h * scale) Sdl.Window.windowed) in
  let renderer = ok (Sdl.create_renderer window) in
  (* the Display's bytes as they are: red, green, blue, alpha *)
  let texture = ok (Sdl.create_texture renderer Sdl.Pixel.format_rgba32 Sdl.Texture.access_streaming ~w ~h) in
  let pixels = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (w * h * 4) in
  Sdl.start_text_input ();
  (* what the machine reads: the mouse (x, y, the buttons: 4 red, 2
   * yellow, 1 blue) and the characters typed, waiting *)
  let mouse = ref (0, 0, 0) and keys : int Queue.t = Queue.create () in
  let host : St_interp.host =
    { St_boot.quiet_host with
      transcript;
      milliseconds = (fun () -> Int32.to_int (Sdl.get_ticks ()));
      mouse = (fun () -> !mouse);
      keyboard = (fun () -> Queue.take_opt keys) } in
  let squeak = Squeak.start system host in
  let e = Sdl.Event.create () in
  let quit = ref false in
  let control () : bool = Sdl.get_mod_state () land Sdl.Kmod.ctrl <> 0 in
  while not !quit do
    let interrupt = ref false in
    while Sdl.poll_event (Some e) do
      let k = Sdl.Event.(get e typ) in
      if k = Sdl.Event.quit then quit := true
      else if k = Sdl.Event.mouse_motion then begin
        let _, _, b = !mouse in
        mouse := (Sdl.Event.(get e mouse_motion_x) / scale, Sdl.Event.(get e mouse_motion_y) / scale, b)
      end
      else if k = Sdl.Event.mouse_button_down || k = Sdl.Event.mouse_button_up then begin
        let which = Sdl.Event.(get e mouse_button_button) in
        let bit =
          if which = Sdl.Button.left then (if control () then 1 else 4)
          else if which = Sdl.Button.right then 2
          else if which = Sdl.Button.middle then 1
          else 0 in
        let x = Sdl.Event.(get e mouse_button_x) / scale and y = Sdl.Event.(get e mouse_button_y) / scale in
        let _, _, b = !mouse in
        (* (the left button let go: whichever of the two it was) *)
        mouse := (x, y, if k = Sdl.Event.mouse_button_down then b lor bit else if which = Sdl.Button.left then b land lnot 5 else b land lnot bit)
      end
      else if k = Sdl.Event.text_input && not (control ()) then
        String.iter (fun (c : char) -> if Char.code c >= 32 && Char.code c < 127 then Queue.add (Char.code c) keys) Sdl.Event.(get e text_input_text)
      else if k = Sdl.Event.key_down then begin
        let code = Sdl.Event.(get e keyboard_keycode) in
        if control () then (if code = Sdl.K.c then interrupt := true)
        else match key_code code with Some c -> Queue.add c keys | None -> ()
      end
    done;
    Squeak.cycle squeak ~interrupt:!interrupt;
    (match Squeak.picture squeak with
     | Some (pw, ph, bytes) when pw = w && ph = h ->
         for i = 0 to Bytes.length bytes - 1 do
           Bigarray.Array1.unsafe_set pixels i (Char.code (Bytes.unsafe_get bytes i))
         done;
         ok (Sdl.update_texture texture None pixels (w * 4));
         ok (Sdl.render_clear renderer);
         ok (Sdl.render_copy renderer texture);
         Sdl.render_present renderer
     | _ -> ());
    Sdl.delay 10l
  done;
  Sdl.quit ()
