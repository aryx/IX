(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Copy_paste.mli *)
open Efuns

(* the last piece killed first *)
let kill_ring : string list ref = ref []

(* where the last kill left things: the text, its version and the
 * point; a kill that finds them so follows it, and is added to its
 * piece (as efuns' last_kill; no question of what the last command
 * was) *)
let last_kill : (Text.t * int * int) option ref = ref None

(* the same for the last yank, and how long it was: M-y replaces it *)
let last_insert : (Text.t * int * int * int) option ref = ref None

(* [kill frame pos len]: taken out to the ring; what is before the
 * point goes before the piece it is added to *)
let kill (frame : frame) (pos : int) (len : int) : unit =
  let text = frame.frm_buffer.buf_text and point = Frame.point frame in
  let follows = (match !last_kill with Some (t, v, p) -> t == text && v = Text.version text && p = point | None -> false) in
  if len = 0 then failwith "Nothing to kill";
  let s = Text.delete text pos len in
  (match !kill_ring with
   | piece :: rest when follows -> kill_ring := (if pos < point then s ^ piece else piece ^ s) :: rest
   | ring -> kill_ring := s :: ring);
  last_kill := Some (text, Text.version text, pos)

let mark_at_point (frame : frame) : unit =
  let buf = frame.frm_buffer in
  (match buf.buf_mark with
   | Some mark -> Text.set_position buf.buf_text mark (Frame.point frame)
   | None -> buf.buf_mark <- Some (Text.new_point buf.buf_text (Frame.point frame)));
  Top_window.message frame "Mark set"

let mark (frame : frame) : Text.point =
  match frame.frm_buffer.buf_mark with Some mark -> mark | None -> failwith "No mark set in this buffer"

let point_at_mark (frame : frame) : unit =
  let mark = mark frame and point = Frame.point frame in
  Frame.goto frame (Text.get_position mark);
  Text.set_position frame.frm_buffer.buf_text mark point

(* the region: where it starts, how long it is *)
let region (frame : frame) : int * int =
  let a = Text.get_position (mark frame) and b = Frame.point frame in
  (min a b, abs (a - b))

let kill_region (frame : frame) : unit = let pos, len = region frame in kill frame pos len

let copy_region (frame : frame) : unit =
  let pos, len = region frame in
  kill_ring := Text.sub frame.frm_buffer.buf_text pos len :: !kill_ring

let kill_end_of_line (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text and pos = Frame.point frame in
  let eol = Text.eol text pos in
  if pos = Text.length text then failwith "End of buffer";
  kill frame pos (max 1 (eol - pos))

(* from the point to where a move takes it *)
let kill_to (move : action) (frame : frame) : unit =
  let from = Frame.point frame in
  move frame;
  let pos = Frame.point frame in
  Frame.goto frame from;
  kill frame (min from pos) (abs (from - pos))

let kill_forward_word (frame : frame) : unit = kill_to Move.forward_word frame
let kill_backward_word (frame : frame) : unit = kill_to Move.backward_word frame

let insert_killed (frame : frame) : unit =
  match !kill_ring with
  | [] -> failwith "Kill ring is empty"
  | piece :: _ ->
      let text = frame.frm_buffer.buf_text in
      Edit.insert_string frame piece;
      last_insert := Some (text, Text.version text, Frame.point frame, String.length piece)

let insert_next_killed (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  match !last_insert, !kill_ring with
  | Some (t, v, p, len), piece :: rest when t == text && v = Text.version text && p = Frame.point frame ->
      ignore (Text.delete text (p - len) len);
      kill_ring := rest @ [ piece ];
      insert_killed frame
  | _ -> failwith "Previous command was not a yank"

let () = Action.define_all [
  "mark_at_point", mark_at_point; "point_at_mark", point_at_mark;
  "kill_region", kill_region; "copy_region", copy_region; "kill_end_of_line", kill_end_of_line;
  "kill_forward_word", kill_forward_word; "kill_backward_word", kill_backward_word;
  "insert_killed", insert_killed; "insert_next_killed", insert_next_killed;
]
