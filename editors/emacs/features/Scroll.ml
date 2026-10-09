(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Scroll.mli *)
open Efuns

(* the frame's first line n lines further (before, n negative) *)
let scroll (frame : frame) (n : int) : unit =
  let text = frame.frm_buffer.buf_text in
  Text.set_position text frame.frm_start (Text.forward_line text (Text.get_position frame.frm_start) n)

(* the lines of text a frame shows, less the two kept *)
let screen (frame : frame) : int = max 1 (frame.frm_height - 3)

let forward_screen (frame : frame) : unit =
  let start = Text.get_position frame.frm_start in
  scroll frame (screen frame);
  if Text.get_position frame.frm_start = start then failwith "End of buffer";
  if not (Frame.point_shown frame) then Frame.goto frame (Text.get_position frame.frm_start)

let backward_screen (frame : frame) : unit =
  if Text.get_position frame.frm_start = 0 then failwith "Beginning of buffer";
  scroll frame (-(screen frame));
  if not (Frame.point_shown frame) then Frame.goto frame (Frame.last_line frame)

let recenter (frame : frame) : unit = Frame.recenter frame ((frame.frm_height - 1) / 2)

let () = Action.define_all [ "forward_screen", forward_screen; "backward_screen", backward_screen; "recenter", recenter ]
