(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Image_file.mli *)

let extensions : string list = [ ".png"; ".jpg"; ".jpeg" ]

let starts (bytes : string) (prefix : string) : bool =
  String.length bytes >= String.length prefix && String.sub bytes 0 (String.length prefix) = prefix

let png (bytes : string) : bool = starts bytes Png.signature
let jpeg (bytes : string) : bool = starts bytes "\xFF\xD8"
let known (bytes : string) : bool = png bytes || jpeg bytes

let decode (bytes : string) : Rgba_image.t =
  if png bytes then Png.decode bytes else if jpeg bytes then Jpeg.decode bytes else failwith "neither a PNG nor a JPEG file"
