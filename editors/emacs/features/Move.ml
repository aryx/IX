(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Move.mli *)
open Efuns

let move_forward (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text and pos = Frame.point frame in
  if pos = Text.length text then failwith "End of buffer";
  Frame.goto frame (Frame.next text pos)

let move_backward (frame : frame) : unit =
  let pos = Frame.point frame in
  if pos = 0 then failwith "Beginning of buffer";
  Frame.goto frame (Frame.prev frame.frm_buffer.buf_text pos)

let line_move (frame : frame) (n : int) : unit =
  let text = frame.frm_buffer.buf_text and pos = Frame.point frame in
  let col = match frame.frm_goal with Some (col, at) when at = pos -> col | _ -> Frame.column text pos in
  let target = Text.forward_line text pos n in
  if target = Text.bol text pos then failwith (if n > 0 then "End of buffer" else "Beginning of buffer");
  Frame.goto frame (Frame.position_of_column text target col);
  frame.frm_goal <- Some (col, Frame.point frame)

let forward_line (frame : frame) : unit = line_move frame 1
let backward_line (frame : frame) : unit = line_move frame (-1)

let beginning_of_line (frame : frame) : unit = Frame.goto frame (Text.bol frame.frm_buffer.buf_text (Frame.point frame))
let end_of_line (frame : frame) : unit = Frame.goto frame (Text.eol frame.frm_buffer.buf_text (Frame.point frame))

(* (a byte of a character beyond ASCII is of a word: é is a letter) *)
let in_word (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c >= '\x80'

(* what is not of a word passed, then a word *)
let forward_word (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let rec skip (word : bool) (pos : int) : int =
    if pos < Text.length text && in_word (Text.get text pos) = word then skip word (pos + 1) else pos in
  Frame.goto frame (skip true (skip false (Frame.point frame)))

let backward_word (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let rec skip (word : bool) (pos : int) : int =
    if pos > 0 && in_word (Text.get text (pos - 1)) = word then skip word (pos - 1) else pos in
  Frame.goto frame (skip true (skip false (Frame.point frame)))

let begin_of_file (frame : frame) : unit = Frame.goto frame 0
let end_of_file (frame : frame) : unit = Frame.goto frame (Text.length frame.frm_buffer.buf_text)

let () = Action.define_all [
  "move_forward", move_forward; "move_backward", move_backward;
  "forward_line", forward_line; "backward_line", backward_line;
  "beginning_of_line", beginning_of_line; "end_of_line", end_of_line;
  "forward_word", forward_word; "backward_word", backward_word;
  "begin_of_file", begin_of_file; "end_of_file", end_of_file;
]
