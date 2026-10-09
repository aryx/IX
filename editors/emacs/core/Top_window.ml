(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Top_window.mli *)
open Efuns

let place (top : top_window) : unit = Window.place top.window 0 0 top.top_width (top.top_height - 1)

let create (caps : caps) (rows : int) (cols : int) (buf : buffer) : top_window =
  let frame = Frame.create caps buf in
  let top = {
    top_width = cols; top_height = rows; window = WFrame frame; top_active_frame = frame;
    top_prefix = []; top_key = ""; top_message = ""; top_killed = false;
  } in
  place top;
  Globals.editor.top_windows <- top :: Globals.editor.top_windows;
  top

let of_frame (frame : frame) : top_window =
  List.find (fun (top : top_window) -> List.memq frame (Window.frames top.window)) Globals.editor.top_windows

let message (frame : frame) (s : string) : unit = (of_frame frame).top_message <- s

let resize (top : top_window) (rows : int) (cols : int) : unit =
  top.top_width <- cols;
  top.top_height <- rows;
  place top

(*****************************************************************************)
(* Keys *)
(*****************************************************************************)

(* what the keys do in the first of the frame's maps that says *)
let binding (frame : frame) (keys : key list) : binding option =
  let buf = frame.frm_buffer in
  let maps = (buf.buf_map :: List.map (fun (m : minor_mode) -> m.min_map) buf.buf_minor_modes)
             @ [ buf.buf_major_mode.maj_map; Globals.editor.edt_map ] in
  List.find_map (fun (map : map) -> Keymap.get_binding map keys) maps

let handle_key (top : top_window) (key : key) : unit =
  let frame = top.top_active_frame in
  let typed : key list =
    match top.top_prefix with
    | "ESC" :: before -> ("M-" ^ key) :: before
    | before -> key :: before in
  let keys = List.rev typed in
  let said = String.concat " " keys in
  top.top_prefix <- [];
  top.top_message <- "";
  top.top_key <- key;
  let found =
    if key = "ESC" then Some (Prefix (Keymap.create ()))
    else
      match binding frame keys with
      | None when Keymap.is_char key && List.length keys = 1 -> binding frame [ Keymap.any_char ]
      | b -> b in
  match found with
  | Some (Prefix _) ->
      top.top_prefix <- typed;
      top.top_message <- said ^ "-"
  | None -> top.top_message <- said ^ " is undefined"
  | Some (Function action) ->
      (try action frame with
       | Failure s | Sys_error s -> top.top_message <- s
       | Not_found -> top.top_message <- "Not found"
       | Invalid_argument s -> top.top_message <- "Invalid argument: " ^ s);
      (* (the frame's buffer after the command, which may have changed it) *)
      Text.boundary top.top_active_frame.frm_buffer.buf_text

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

let display (top : top_window) : Curses.t =
  let screen = ref (Curses.create ~rows:top.top_height ~cols:top.top_width) in
  let cursor : (int * int) option ref = ref None in
  List.iter (fun (frame : frame) ->
    let s, at = Frame.display frame !screen in
    screen := s;
    if frame == top.top_active_frame then cursor := Some at) (Window.frames top.window);
  screen := Curses.put ~attrs:Vt.plain (top.top_height - 1) 0 top.top_message !screen;
  Curses.cursor !cursor !screen

let program (top : top_window) : top_window Tui.program = {
  init = top;
  update = (fun (event : Tui.event) (top : top_window) ->
    (match event with
     | Key bytes -> handle_key top (Keymap.of_bytes bytes)
     | Resize (rows, cols) -> resize top rows cols
     | Tick _ -> ());
    top);
  view = display;
  over = (fun (top : top_window) -> top.top_killed);
}
