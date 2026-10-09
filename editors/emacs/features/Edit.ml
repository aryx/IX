(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Edit.mli *)
open Efuns

(* (a point at an insertion stays before it: the frame's is moved) *)
let insert_string (frame : frame) (s : string) : unit =
  let pos = Frame.point frame in
  Text.insert frame.frm_buffer.buf_text pos s;
  Frame.goto frame (pos + String.length s)

let self_insert_command (frame : frame) : unit = insert_string frame (Top_window.of_frame frame).top_key
let insert_return (frame : frame) : unit = insert_string frame "\n"
let insert_tab (frame : frame) : unit = insert_string frame "\t"

let delete_char (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text and pos = Frame.point frame in
  if pos = Text.length text then failwith "End of buffer";
  ignore (Text.delete text pos (Frame.next text pos - pos))

let delete_backspace_char (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text and pos = Frame.point frame in
  if pos = 0 then failwith "Beginning of buffer";
  let before = Frame.prev text pos in
  ignore (Text.delete text before (pos - before))

let undo (frame : frame) : unit =
  match Text.undo frame.frm_buffer.buf_text with
  | Some pos -> Frame.goto frame pos
  | None -> failwith "No further undo information"

let () = Action.define_all [
  "undo", undo;
  "self_insert_command", self_insert_command; "insert_return", insert_return; "insert_tab", insert_tab;
  "delete_char", delete_char; "delete_backspace_char", delete_backspace_char;
]
