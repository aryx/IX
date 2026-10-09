(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)
open Efuns

let rec frames (window : window) : frame list =
  match window with
  | WFrame frame -> [ frame ]
  | HComb (a, b) | VComb (a, b) -> frames a @ frames b

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
