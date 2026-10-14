(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Doc_image.mli *)

let picture (name : string) (bytes : string) (wide : float) (per_inch : float) (most : float) : (Doc.block, string) result =
  let starts (w : string) : bool = String.length bytes >= String.length w && String.sub bytes 0 (String.length w) = w in
  (* (a drawing: lib_graphics's Svg draws no text, and ix's are boxes
   * with words in them) *)
  if starts "<svg" || starts "<?xml" then Error "an SVG file, not read as a picture"
  else
    match (try Ok (if starts "GIF8" then Gif.decode bytes else Image_file.decode bytes) with Failure why -> Error why | Invalid_argument why -> Error why | Not_found -> Error "a file cut short") with
    | Error why -> Error why
    | Ok img ->
        if img.width <= 0 || img.height <= 0 then Error "a picture of no pixel"
        else begin
          let own = float_of_int img.width /. per_inch in
          let w = Float.min most (if wide > 0. then wide else own) in
          (* (whole hundredths of an inch: the same by every compiler) *)
          let w = Float.max 0.01 (Float.round (w *. 100.) /. 100.) in
          let h = Float.max 0.01 (Float.round (w *. float_of_int img.height /. float_of_int img.width *. 100.) /. 100.) in
          let p : Doc.picture = { wide = w; high = h; marks = [ Doc.Image (0., 0., w, h, name, img) ] } in
          Ok (Doc.Picture p)
        end
