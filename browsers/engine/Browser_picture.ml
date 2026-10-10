(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/display/Browser_picture.ml, its first version (docs/plans/plan_browser.md) *)

(* See Browser_picture.mli *)

type t = Waiting | Arrived of Rgba_image.t | Broken

(* ix: Option.value written out; Png and Jpeg by Image_file *)
let decode (bytes : string) : t =
  let starts magic = String.length bytes >= String.length magic && String.sub bytes 0 (String.length magic) = magic in
  try
    if starts "GIF8" then Arrived (Gif.decode bytes)
    else if Image_file.known bytes then Arrived (Image_file.decode bytes)
    else if Svg.sniff bytes then
      (* drawn at its own size (a picture without one: CSS's 300 by 150) *)
      match Svg.parse bytes with
      | Some svg ->
          let w, h = match Svg.size svg with Some size -> size | None -> (300., 150.) in
          Arrived (Svg.render svg ~width:(int_of_float (Float.round w)) ~height:(int_of_float (Float.round h)))
      | None -> Broken
    else Broken
  with _ -> Broken

let broken_size = 24.

let size (t : t) : (float * float) option =
  match t with
  | Arrived img -> Some (float_of_int img.width, float_of_int img.height)
  | Broken -> Some (broken_size, broken_size)
  | Waiting -> None
