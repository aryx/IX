(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)

open Tsdl

let ok = function Ok v -> v | Error _ -> failwith ("SDL: " ^ Sdl.get_error ())

(* the keys that are not characters, by Vt.key's names *)
let key_name (k : int) : string option =
  let names = [
    Sdl.K.return, "Enter"; Sdl.K.kp_enter, "Enter"; Sdl.K.backspace, "Backspace"; Sdl.K.tab, "Tab"; Sdl.K.escape, "Escape";
    Sdl.K.up, "ArrowUp"; Sdl.K.down, "ArrowDown"; Sdl.K.left, "ArrowLeft"; Sdl.K.right, "ArrowRight";
    Sdl.K.home, "Home"; Sdl.K.kend, "End"; Sdl.K.pageup, "PageUp"; Sdl.K.pagedown, "PageDown";
    Sdl.K.insert, "Insert"; Sdl.K.delete, "Delete";
    Sdl.K.f1, "F1"; Sdl.K.f2, "F2"; Sdl.K.f3, "F3"; Sdl.K.f4, "F4"; Sdl.K.f5, "F5"; Sdl.K.f6, "F6";
    Sdl.K.f7, "F7"; Sdl.K.f8, "F8"; Sdl.K.f9, "F9"; Sdl.K.f10, "F10"; Sdl.K.f11, "F11"; Sdl.K.f12, "F12";
  ] in
  List.assoc_opt k names

(* the window's pixels shown: a picture of the screen's cells, and the
 * texture it is copied to *)
type shown = { picture : Picture.t; texture : Sdl.texture; pixels : (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t }

let run (title : string) (scale : int) (rows : int) (cols : int) (p : 'model Tui.program) : unit =
  ok (Sdl.init Sdl.Init.video);
  let font = Picture.font () in
  let cw, ch = Picture.cell font in
  let window = ok (Sdl.create_window title ~w:(cols * cw * scale) ~h:(rows * ch * scale) Sdl.Window.(windowed + resizable)) in
  let renderer = ok (Sdl.create_renderer window) in
  Sdl.start_text_input ();
  (* a picture of the whole rows and columns that fit in w by h pixels *)
  let sized (w : int) (h : int) : int * int * shown =
    let rows = max 1 (h / (ch * scale)) and cols = max 1 (w / (cw * scale)) in
    let picture = Picture.create (cols * cw) (rows * ch) in
    let texture = ok (Sdl.create_texture renderer Sdl.Pixel.format_rgb24 Sdl.Texture.access_streaming ~w:picture.w ~h:picture.h) in
    (rows, cols, { picture; texture; pixels = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (Bytes.length picture.pixels) }) in
  let rows, cols, first = sized (cols * cw * scale) (rows * ch * scale) in
  let shown = ref first in
  let model = ref (p.update (Tui.Resize (rows, cols)) p.init) in
  (* the screen the picture has: None, all of it is to paint *)
  let screen : Curses.t option ref = ref None in
  let e = Sdl.Event.create () in
  let quit = ref false in
  let last = ref (Sdl.get_ticks ()) in
  let key (k : string) : unit = model := p.update (Tui.Key k) !model in
  while not !quit && not (p.over !model) do
    while Sdl.poll_event (Some e) do
      let k = Sdl.Event.(get e typ) in
      let m = Sdl.get_mod_state () in
      let ctrl = m land Sdl.Kmod.ctrl <> 0 and alt = m land Sdl.Kmod.alt <> 0 in
      if k = Sdl.Event.quit then quit := true
      else if k = Sdl.Event.window_event && Sdl.Event.(get e window_event_id) = Sdl.Event.window_event_size_changed then begin
        let w, h = Sdl.get_window_size window in
        Sdl.destroy_texture !shown.texture;
        let rows, cols, next = sized w h in
        shown := next;
        screen := None;
        model := p.update (Tui.Resize (rows, cols)) !model
      end
      (* a character typed; with Control or Alt it comes as a key *)
      else if k = Sdl.Event.text_input && not ctrl && not alt then
        String.iter (fun (c : char) -> if Char.code c >= 32 && Char.code c < 127 then key (String.make 1 c)) Sdl.Event.(get e text_input_text)
      else if k = Sdl.Event.key_down then begin
        let code = Sdl.Event.(get e keyboard_keycode) in
        let name =
          match key_name code with
          | Some n -> Some n
          | None -> if (ctrl || alt) && code >= 32 && code < 127 then Some (String.make 1 (Char.chr code)) else None in
        match name with
        | Some n -> (match Keys.key alt ctrl n with Some bytes -> key bytes | None -> ())
        | None -> ()
      end
    done;
    let now = Sdl.get_ticks () in
    model := p.update (Tui.Tick (Float.min 0.25 (Int32.to_float (Int32.sub now !last) /. 1000.))) !model;
    last := now;
    let next = p.view !model in
    if !screen <> Some next then begin
      let s = !shown in
      Cells.show (Picture.surface s.picture font) !screen next;
      screen := Some next;
      for i = 0 to Bytes.length s.picture.pixels - 1 do
        Bigarray.Array1.unsafe_set s.pixels i (Char.code (Bytes.unsafe_get s.picture.pixels i))
      done;
      ok (Sdl.update_texture s.texture None s.pixels (s.picture.w * 3))
    end;
    (* (drawn each pass: the window's edge past the last cell is black,
     * and what another window covered comes back) *)
    ok (Sdl.set_render_draw_color renderer 0 0 0 255);
    ok (Sdl.render_clear renderer);
    ok (Sdl.render_copy ~dst:(Sdl.Rect.create ~x:0 ~y:0 ~w:(!shown.picture.w * scale) ~h:(!shown.picture.h * scale)) renderer !shown.texture);
    Sdl.render_present renderer;
    Sdl.delay 20l
  done;
  Sdl.quit ()
