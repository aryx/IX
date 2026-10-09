(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)
open Efuns

let rec frames (window : window) : frame list =
  match window with
  | WFrame frame -> [ frame ]
  | HComb (a, b) | VComb (a, b) -> frames a @ frames b

(* f at the frame's leaf: what is there in its place, or nothing *)
let rec change (window : window) (frame : frame) (f : unit -> window option) : window option =
  match window with
  | WFrame fr -> if fr == frame then f () else Some window
  | HComb (a, b) -> (
      match change a frame f, change b frame f with
      | Some a, Some b -> Some (HComb (a, b))
      | None, other | other, None -> other)
  | VComb (a, b) -> (
      match change a frame f, change b frame f with
      | Some a, Some b -> Some (VComb (a, b))
      | None, other | other, None -> other)

let remove (window : window) (frame : frame) : window option =
  if not (List.memq frame (frames window)) then raise Not_found;
  change window frame (fun () -> None)

let replace (window : window) (frame : frame) (by : window) : window =
  if not (List.memq frame (frames window)) then raise Not_found;
  match change window frame (fun () -> Some by) with Some w -> w | None -> by

let rec place (window : window) (x : int) (y : int) (width : int) (height : int) : unit =
  match window with
  | WFrame frame ->
      frame.frm_xpos <- x;
      frame.frm_ypos <- y;
      frame.frm_width <- width;
      frame.frm_height <- height
  | HComb (a, b) ->
      let w = width / 2 in
      place a x y w height;
      place b (x + w + 1) y (width - w - 1) height
  | VComb (a, b) ->
      let h = height / 2 in
      place a x y width h;
      place b x (y + h) width (height - h)
