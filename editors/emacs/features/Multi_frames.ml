(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Multi_frames.mli. (From the minibuffer's frame, which is in no
 * window, each fails: Window's Not_found.) *)
open Efuns

let cut_frame (frame : frame) (comb : window -> window -> window) : unit =
  let top = Top_window.of_frame frame in
  let other = Frame.create frame.caps frame.frm_buffer in
  Frame.goto other (Frame.point frame);
  Text.set_position frame.frm_buffer.buf_text other.frm_start (Text.get_position frame.frm_start);
  Top_window.set_window top (Window.replace top.window frame (comb (WFrame frame) (WFrame other))) frame

let vertical_cut_frame (frame : frame) : unit =
  if frame.frm_height < 6 then failwith "Window too small to split";
  cut_frame frame (fun (a : window) (b : window) -> VComb (a, b))

let horizontal_cut_frame (frame : frame) : unit =
  if frame.frm_width < 20 then failwith "Window too small to split";
  cut_frame frame (fun (a : window) (b : window) -> HComb (a, b))

let next_frame (frame : frame) : unit =
  let top = Top_window.of_frame frame in
  let rec after (l : frame list) : frame =
    match l with
    | f :: next :: _ when f == frame -> next
    | _ :: rest -> after rest
    | [] -> List.hd (Window.frames top.window) in
  if not (List.memq frame (Window.frames top.window)) then raise Not_found;
  top.top_active_frame <- after (Window.frames top.window)

let delete_frame (frame : frame) : unit =
  let top = Top_window.of_frame frame in
  match Window.remove top.window frame with
  | None -> failwith "Attempt to delete the sole window"
  | Some window ->
      next_frame frame;
      let active = top.top_active_frame in
      Frame.kill frame;
      Top_window.set_window top window active

let one_frame (frame : frame) : unit =
  let top = Top_window.of_frame frame in
  let others = List.filter (fun (f : frame) -> f != frame) (Window.frames top.window) in
  if List.length others = List.length (Window.frames top.window) then raise Not_found;
  List.iter Frame.kill others;
  Top_window.set_window top (WFrame frame) frame

let () = Action.define_all [
  "vertical_cut_frame", vertical_cut_frame; "horizontal_cut_frame", horizontal_cut_frame;
  "next_frame", next_frame; "delete_frame", delete_frame; "one_frame", one_frame;
]
