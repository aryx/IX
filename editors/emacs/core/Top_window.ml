(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Top_window.mli *)
open Efuns

let place (top : top_window) : unit = Window.place top.window 0 0 top.top_width (top.top_height - 1)

let create (caps : caps) (rows : int) (cols : int) (buf : buffer) : top_window =
  let frame = Frame.create caps buf in
  let top = {
    top_width = cols; top_height = rows; window = WFrame frame; top_active_frame = frame;
    top_prefix = []; top_key = ""; top_mouse = (0, 0); top_message = ""; top_mini = None; top_recorded = None; top_killed = false;
  } in
  place top;
  Globals.editor.top_windows <- top :: Globals.editor.top_windows;
  top

(* (the minibuffer's frame is not in the tree) *)
let of_frame (frame : frame) : top_window =
  List.find (fun (top : top_window) ->
    List.memq frame (Window.frames top.window)
    || (match top.top_mini with Some mini -> mini.mini_frame == frame | None -> false)) Globals.editor.top_windows

let message (frame : frame) (s : string) : unit = (of_frame frame).top_message <- s

let resize (top : top_window) (rows : int) (cols : int) : unit =
  top.top_width <- cols;
  top.top_height <- rows;
  place top

let set_window (top : top_window) (window : window) (active : frame) : unit =
  top.window <- window;
  top.top_active_frame <- active;
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
  (match top.top_recorded with Some keys -> top.top_recorded <- Some (key :: keys) | None -> ());
  let typed : key list =
    match top.top_prefix with
    | "ESC" :: before -> ("M-" ^ key) :: before
    | before -> key :: before in
  let keys = List.rev typed in
  let said = String.concat " " keys in
  top.top_prefix <- [];
  top.top_message <- "";
  top.top_key <- key;
  let typing = Keymap.is_char key && List.length keys = 1 && binding frame keys = None in
  let found =
    if key = "ESC" then Some (Prefix (Keymap.create ()))
    else if typing then binding frame [ Keymap.any_char ]
    else binding frame keys in
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
      (* (every buffer shown: the command may have changed the frame's
       * buffer, or have been an answer in the minibuffer that changed
       * the text of the frame that asked); a word typed is undone as
       * one: no boundary between its letters *)
      if not typing || key = " " then
        List.iter (fun (f : frame) -> Text.boundary f.frm_buffer.buf_text) (top.top_active_frame :: Window.frames top.window)

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

let display (top : top_window) : Curses.t =
  let screen = ref (Curses.create ~rows:top.top_height ~cols:top.top_width) in
  (* the editor's ground, where it is not the terminal's own *)
  let plain = Globals.editor.edt_plain in
  if plain <> Vt.plain then
    for row = 0 to top.top_height - 1 do screen := Curses.put ~attrs:plain row 0 (String.make top.top_width ' ') !screen done;
  let cursor : (int * int) option ref = ref None in
  let last = top.top_height - 1 in
  (* whose cursor is shown, of the tree's frames *)
  let shown = match top.top_mini with Some mini -> mini.mini_back | None -> top.top_active_frame in
  List.iter (fun (frame : frame) ->
    let s, at = Frame.display frame !screen in
    screen := s;
    (* a bar between two windows side by side *)
    if frame.frm_xpos > 0 then
      for row = frame.frm_ypos to frame.frm_ypos + frame.frm_height - 1 do
        screen := Curses.put ~attrs:plain row (frame.frm_xpos - 1) "|" !screen
      done;
    if frame == shown then cursor := Some at) (Window.frames top.window);
  (match top.top_mini with
   | None -> screen := Curses.put ~attrs:plain last 0 top.top_message !screen
   | Some mini ->
       (* the prompt, the answer's frame, and what is said after it *)
       let frame = mini.mini_frame in
       let x = Utf8.length mini.mini_prompt in
       Window.place (WFrame frame) x last (top.top_width - x) 1;
       screen := Curses.put ~attrs:plain last 0 mini.mini_prompt !screen;
       let s, at = Frame.display frame !screen in
       screen := s;
       if not mini.mini_cursor_back then cursor := Some at;
       let text = frame.frm_buffer.buf_text in
       if top.top_message <> "" then
         screen := Curses.put ~attrs:plain last (x + Frame.column text (Text.length text) + 1) ("[" ^ top.top_message ^ "]") !screen);
  Curses.cursor !cursor !screen

type model = { top : top_window }

let program (top : top_window) : model Tui.program = {
  init = { top };
  update = (fun (event : Tui.event) (m : model) ->
    match event with
    | Key bytes ->
        (match Keymap.mouse bytes with Some at -> m.top.top_mouse <- at | None -> ());
        handle_key m.top (Keymap.of_bytes bytes);
        { top = m.top }
    | Resize (rows, cols) -> resize m.top rows cols; { top = m.top }
    | Tick _ -> m);
  view = (fun (m : model) -> display m.top);
  over = (fun (m : model) -> m.top.top_killed);
}
