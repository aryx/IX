(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Emouse.mli *)
open Efuns

(* the frame the mouse is in, and its place there; not while a
 * question is asked: the keys are the minibuffer's *)
let under (frame : frame) : top_window * frame * int * int =
  let top = Top_window.of_frame frame in
  let row, col = top.top_mouse in
  (match top.top_mini with Some _ -> failwith "The minibuffer is in use" | None -> ());
  match List.find_opt (fun (f : frame) ->
    row >= f.frm_ypos && row < f.frm_ypos + f.frm_height && col >= f.frm_xpos && col < f.frm_xpos + f.frm_width)
    (Window.frames top.window) with
  | Some f -> (top, f, row - f.frm_ypos, col - f.frm_xpos)
  | None -> failwith "No window there"

let mouse_set_frame (frame : frame) : unit =
  let top, f, row, col = under frame in
  top.top_active_frame <- f;
  if row < f.frm_height - 1 then Frame.goto f (Frame.position_at f row col)

let scroll (frame : frame) (action : action) : unit =
  let _, f, _, _ = under frame in
  action f; action f; action f

let mouse_scroll_up (frame : frame) : unit = scroll frame Scroll.scroll_down
let mouse_scroll_down (frame : frame) : unit = scroll frame Scroll.scroll_up

let () = Action.define_all [
  "mouse_set_frame", mouse_set_frame; "mouse_scroll_up", mouse_scroll_up; "mouse_scroll_down", mouse_scroll_down;
]
