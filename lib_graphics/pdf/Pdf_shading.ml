(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf_shading.ml; two Option.value ~default written as their match; paint's canvas and clip are a pair, its parameters 7 where they were 8 (mini-ml's arm code takes no more) (docs/plans/plan_pdf.md) *)

(* See Pdf_shading.mli *)

open Pdf_object

(* a function of one number: a power between two values, pieces
 * joined, or a table of samples; one a component, or one for all *)
let rec apply (pdf : Pdf.t) (f : Pdf_object.t) (x : float) : float list =
  let floats key d = match Pdf.get pdf d key with Array l -> List.map (fun v -> to_float (Pdf.resolve pdf v)) l | _ -> [] in
  match Pdf.resolve pdf f with
  | Array fs -> List.concat_map (fun f -> apply pdf f x) fs
  | (Dict d | Stream (d, _)) as fn -> (
      let x = match floats "Domain" d with lo :: hi :: _ -> Float.max lo (Float.min hi x) | _ -> x in
      match to_int (Pdf.get pdf d "FunctionType") with
      | 2 ->
          let c0 = match floats "C0" d with [] -> [ 0. ] | l -> l and c1 = match floats "C1" d with [] -> [ 1. ] | l -> l in
          let n = to_float (Pdf.get pdf d "N") in
          List.map2 (fun a b -> a +. (Float.pow x n *. (b -. a))) c0 (if List.length c1 = List.length c0 then c1 else c0)
      | 3 ->
          let functions = match Pdf.get pdf d "Functions" with Array l -> l | _ -> [] and bounds = floats "Bounds" d and encode = floats "Encode" d in
          let lo0, hi0 = match floats "Domain" d with lo :: hi :: _ -> (lo, hi) | _ -> (0., 1.) in
          let rec piece k lo = function
            | [ f ] -> (k, lo, hi0, f)
            | f :: rest -> ( match List.nth_opt bounds k with Some b when x < b -> (k, lo, b, f) | Some b -> piece (k + 1) b rest | None -> (k, lo, hi0, f))
            | [] -> (k, lo, hi0, Null)
          in
          let k, lo, hi, f = piece 0 lo0 functions in
          let e0 = (match List.nth_opt encode (2 * k) with Some v -> v | None -> 0.) and e1 = (match List.nth_opt encode ((2 * k) + 1) with Some v -> v | None -> 1.) in
          apply pdf f (if hi > lo then e0 +. ((x -. lo) /. (hi -. lo) *. (e1 -. e0)) else e0)
      | 0 ->
          let data = Pdf.data pdf fn and size = max 1 (to_int (match Pdf.get pdf d "Size" with Array (s :: _) -> Pdf.resolve pdf s | _ -> Int 1)) in
          let range = floats "Range" d and bits = to_int (Pdf.get pdf d "BitsPerSample") in
          let n = List.length range / 2 and bytes = max 1 (bits / 8) in
          let lo, hi = match floats "Domain" d with lo :: hi :: _ -> (lo, hi) | _ -> (0., 1.) in
          let at = int_of_float (Float.round ((x -. lo) /. Float.max 1e-9 (hi -. lo) *. float_of_int (size - 1))) in
          List.init n (fun c ->
              let o = ((at * n) + c) * bytes in
              let v = if o + bytes <= String.length data then float_of_int (Char.code data.[o]) /. 255. else 0. in
              let r0 = List.nth range (2 * c) and r1 = List.nth range ((2 * c) + 1) in
              r0 +. (v *. (r1 -. r0)))
      | _ -> [ 0.5 ])
  | _ -> [ 0.5 ]

(* a gradient: along a line (kind 2) or between two circles (kind 3),
 * its colours a function of how far; painted where the clip allows.
 * [flat]: one colour, the middle one *)
let paint (pdf : Pdf.t) ((canvas, clip) : Pdf_canvas.t * Pdf_canvas.clip) ~(resources : Pdf_object.t) ~(alpha : float) ~(flat : bool) (sh : Pdf_object.t) (m : Affine.t) : unit =
  let d = Pdf.dict pdf sh in
  let get = Pdf.get pdf d in
  let coords = match get "Coords" with Array l -> List.map (fun v -> to_float (Pdf.resolve pdf v)) l | _ -> [] in
  let sp = Pdf_color.space pdf resources (get "ColorSpace") in
  let t0, t1 = match get "Domain" with Array [ a; b ] -> (to_float (Pdf.resolve pdf a), to_float (Pdf.resolve pdf b)) | _ -> (0., 1.) in
  let before, after = match get "Extend" with Array [ a; b ] -> (Pdf.resolve pdf a = Bool true, Pdf.resolve pdf b = Bool true) | _ -> (false, false) in
  (* the colours, 256 steps of them *)
  let colors = Array.init 256 (fun i -> try Pdf_color.color sp (apply pdf (get "Function") (t0 +. (float_of_int i /. 255. *. (t1 -. t0)))) with _ -> (128., 128., 128.)) in
  let at (s : float) = if (s < 0. && not before) || (s > 1. && not after) then None else Some colors.(if flat then 128 else max 0 (min 255 (int_of_float (255. *. s)))) in
  if Float.abs ((m.a *. m.d) -. (m.b *. m.c)) > 1e-12 then (
    let inverse = Affine.invert m in
    match (to_int (get "ShadingType"), coords) with
    | 2, [ x0; y0; x1; y1 ] ->
        let dx = x1 -. x0 and dy = y1 -. y0 in
        let len = Float.max 1e-12 ((dx *. dx) +. (dy *. dy)) in
        Pdf_canvas.shade canvas clip (fun px py -> let x, y = Affine.apply inverse (px, py) in at ((((x -. x0) *. dx) +. ((y -. y0) *. dy)) /. len)) alpha
    | 3, [ x0; y0; r0; x1; y1; r1 ] ->
        (* the circle through the point, of those between the two: the furthest along *)
        let cdx = x1 -. x0 and cdy = y1 -. y0 and dr = r1 -. r0 in
        let a = (cdx *. cdx) +. (cdy *. cdy) -. (dr *. dr) in
        Pdf_canvas.shade canvas clip
          (fun px py ->
            let x, y = Affine.apply inverse (px, py) in
            let px = x -. x0 and py = y -. y0 in
            let b = (px *. cdx) +. (py *. cdy) +. (r0 *. dr) and c = (px *. px) +. (py *. py) -. (r0 *. r0) in
            let roots = if Float.abs a < 1e-12 then (if Float.abs b < 1e-12 then [] else [ c /. (2. *. b) ]) else let disc = (b *. b) -. (a *. c) in if disc < 0. then [] else [ (b +. Float.sqrt disc) /. a; (b -. Float.sqrt disc) /. a ] in
            let ok s = r0 +. (s *. dr) >= 0. && ((s >= 0. || before) && (s <= 1. || after)) in
            match List.filter ok (List.sort (fun a b -> compare b a) roots) with s :: _ -> at (Float.max 0. (Float.min 1. s)) | [] -> None)
          alpha
    | _ -> ())

