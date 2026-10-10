(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf_color.ml (docs/plans/plan_pdf.md) *)

(* See Pdf_color.mli *)

open Pdf_object

type rgb = float * float * float

(* what a colour's numbers mean *)
type space = Gray | Rgb | Cmyk | Indexed of space * string | Tint | Pattern

let color (space : space) (v : float list) : rgb =
  let k x = 255. *. Float.max 0. (Float.min 1. x) in
  let rec of_space space v =
    match (space, v) with
    | Gray, g :: _ -> (k g, k g, k g)
    | Rgb, [ r; g; b ] -> (k r, k g, k b)
    | Cmyk, [ c; m; y; b ] -> (k ((1. -. c) *. (1. -. b)), k ((1. -. m) *. (1. -. b)), k ((1. -. y) *. (1. -. b)))
    | Tint, t :: _ -> (k (1. -. t), k (1. -. t), k (1. -. t))
    | Indexed (base, table), i :: _ ->
        let n = match base with Gray | Tint -> 1 | Cmyk -> 4 | _ -> 3 in
        let at = n * int_of_float i in
        if at + n <= String.length table then of_space base (List.init n (fun j -> float_of_int (Char.code table.[at + j]) /. 255.)) else (0., 0., 0.)
    | Pattern, _ -> (128., 128., 128.)
    | _ -> (0., 0., 0.)
  in
  of_space space v

(* a colour space's name or description: the device's three, a
 * profile's (by its number of components), a palette's, a single ink's *)
let rec space (pdf : Pdf.t) (resources : Pdf_object.t) (v : Pdf_object.t) : space =
  let of_count n = if n = 1 then Gray else if n = 4 then Cmyk else Rgb in
  match Pdf.resolve pdf v with
  | Name ("DeviceGray" | "G" | "CalGray") -> Gray
  | Name ("DeviceRGB" | "RGB" | "CalRGB" | "Lab") -> Rgb
  | Name ("DeviceCMYK" | "CMYK") -> Cmyk
  | Name "Pattern" -> Pattern
  | Name n -> ( match Pdf.get pdf (Pdf.dict pdf (Pdf.get pdf (Pdf.dict pdf resources) "ColorSpace")) n with Null -> Gray | v -> space pdf Null v)
  | Array (Name "ICCBased" :: s :: _) -> of_count (to_int (Pdf.get pdf (Pdf.dict pdf s) "N"))
  | Array (Name ("CalGray") :: _) -> Gray
  | Array (Name ("CalRGB" | "Lab") :: _) -> Rgb
  | Array (Name ("Indexed" | "I") :: base :: _ :: table :: _) -> Indexed (space pdf resources base, match Pdf.resolve pdf table with String s -> s | Stream _ as s -> Pdf.data pdf s | _ -> "")
  | Array (Name ("Separation" | "DeviceN") :: _) -> Tint
  | Array (Name "Pattern" :: _) -> Pattern
  | _ -> Gray

