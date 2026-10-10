(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: mini-chrome's libs/pdf/Pdf_image.ml; a JPEG's pixels are a Bytes (Rgba_image's here); paint's canvas and clip are a pair and its fill, alpha and shown a triple, its parameters 7 where they were 10: mini-ml's arm code takes no more (docs/plans/plan_pdf.md) *)

(* See Pdf_image.mli *)

open Pdf_object

(* a picture in a page: its samples read as colours, and painted in
 * its unit square. Not [shown]: a grey box where it is *)
let paint (pdf : Pdf.t) ((canvas, clip) : Pdf_canvas.t * Pdf_canvas.clip) (ctm : Affine.t) ~(resources : Pdf_object.t) ((fill, alpha, shown) : Pdf_color.rgb * float * bool) (d : dict) (raw : string) : unit =
  let get = Pdf.get pdf d in
  let either a b = match get a with Null -> get b | v -> v in
  let w = to_int (either "Width" "W") and h = to_int (either "Height" "H") in
  let data, left = Pdf_filter.decode (Pdf.resolve pdf) (List.map (fun (k, v) -> ((match k with "F" -> "Filter" | "DP" -> "DecodeParms" | k -> k), v)) d) raw in
  let stencil = either "ImageMask" "IM" = Bool true in
  let inverted = match either "Decode" "D" with Array (a :: _) -> to_float (Pdf.resolve pdf a) = 1. | _ -> false in
  (* its transparency, a grey picture of its own *)
  let soft =
    match get "SMask" with
    | Stream (sd, _) as s ->
        let sw = to_int (Pdf.get pdf sd "Width") and sh = to_int (Pdf.get pdf sd "Height") and bytes = Pdf.data pdf s in
        if sw > 0 && sh > 0 && String.length bytes >= sw * sh then Some (fun x y -> float_of_int (Char.code bytes.[(y * sh / h * sw) + (x * sw / w)]) /. 255.) else None
    | _ -> None
  in
  let soft_alpha x y = match soft with Some f -> f x y | None -> 1. in
  let sample : (int -> int -> float * float * float * float) option =
    match left with
    | Some ("DCTDecode" | "DCT") -> (
        match Jpeg.decode data with
        | img -> Some (fun x y -> let i = 4 * ((min y (img.height - 1) * img.width) + min x (img.width - 1)) in (float_of_int (Char.code (Bytes.get img.rgba i)), float_of_int (Char.code (Bytes.get img.rgba (i + 1))), float_of_int (Char.code (Bytes.get img.rgba (i + 2))), soft_alpha x y))
        | exception _ -> None)
    | Some _ -> None
    | None ->
        let bpc = if stencil then 1 else max 1 (to_int (either "BitsPerComponent" "BPC")) in
        let sp : Pdf_color.space = if stencil then Gray else Pdf_color.space pdf resources (either "ColorSpace" "CS") in
        let n = match sp with Rgb -> 3 | Cmyk -> 4 | _ -> 1 in
        let row = ((w * n * bpc) + 7) / 8 and top = float_of_int ((1 lsl bpc) - 1) in
        let value x y c =
          let bit = (((x * n) + c) * bpc) and base = y * row in
          if base + ((bit + bpc - 1) / 8) >= String.length data then 0
          else if bpc = 8 then Char.code data.[base + (bit / 8)]
          else if bpc = 16 then Char.code data.[base + (bit / 8)] * 257
          else (Char.code data.[base + (bit / 8)] lsr (8 - bpc - (bit land 7))) land ((1 lsl bpc) - 1)
        in
        Some
          (fun x y ->
            if stencil then (let r, g, b = fill in (r, g, b, if (value x y 0 = 0) <> inverted then 1. else 0.))
            else
              let v c = let f = float_of_int (value x y c) /. (if bpc = 16 then 65535. else top) in if inverted then 1. -. f else f in
              let r, g, b = match sp with Indexed _ -> Pdf_color.color sp [ float_of_int (value x y 0) ] | _ -> Pdf_color.color sp (List.init n v) in
              (r, g, b, soft_alpha x y))
  in
  if w > 0 && h > 0 then
    match if shown || stencil then sample else None with
    | Some sample -> Pdf_canvas.image canvas clip ctm ~w ~h sample alpha
    | None -> Pdf_canvas.fill canvas clip ~even_odd:false [ List.map (Affine.apply ctm) [ (0., 0.); (1., 0.); (1., 1.); (0., 1.) ] ] (200., 200., 200.) alpha

