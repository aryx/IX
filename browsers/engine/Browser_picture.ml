(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/display/Browser_picture.ml, its first version (docs/plans/plan_browser.md) *)

(* See Browser_picture.mli *)

type t = Waiting | Arrived of Rgba_image.t | Broken

(* ix: no reader of pictures yet: lib_graphics/images (Png, Jpeg) is
 * being brought by plan_office.md's stage 7, Svg and Gif are this
 * plan's stage 5. Until then every picture that came is the broken
 * one, and the page keeps its room (its width= and height=) *)
let decode (_bytes : string) : t = Broken

let broken_size = 24.

let size (t : t) : (float * float) option =
  match t with
  | Arrived img -> Some (float_of_int img.width, float_of_int img.height)
  | Broken -> Some (broken_size, broken_size)
  | Waiting -> None
