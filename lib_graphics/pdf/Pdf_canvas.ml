(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: mini-chrome's libs/pdf/Pdf_canvas.ml; the paper's pixels are bytes, where they were floats (the type says why), and the picture's a Bytes (Rgba_image's here) (docs/plans/plan_pdf.md) *)

(* See Pdf_canvas.mli *)

type point = float * float

(* where painting is allowed: a box of pixels, and inside it, if the
 * clip is no rectangle, how much of each pixel (rows of the box) *)
(* ix: a mask's pixel is a byte, 0 to 255, where it was a float of an
 * array: by mini-ml each float of an array is a block of its own, 16
 * bytes a pixel on arm, and a page under a clip of its size was 11 MB
 * of mask, one more for each clip inside it *)
type clip = { x0 : int; y0 : int; x1 : int; y1 : int; mask : Bytes.t option }

type t = {
  width : int;
  height : int;
  (* red, green, blue of each pixel, a byte each, and a fourth that
   * stays 255: a page is opaque, and its bytes are then a picture's
   * as they are (to_image).
   * ix: bytes, where they were floats in an array, three a pixel:
   * mini-ml keeps each float of an array in a block of its own, and a
   * page at a pixel and a half a point was 3.6 million of them, and one
   * more made at each pixel painted (docs/plans/plan_pdf.md has the
   * memory and the time, before and after). What it costs: a colour
   * is rounded to a level each time something is laid on it, where
   * it was rounded once, at the end. *)
  pixels : Bytes.t;
  scratch : Framebuffer.t; (* a shape's coverage, before it is painted *)
}

let create ~(width : int) ~(height : int) : t =
  let scratch = Framebuffer.create ~width ~height in
  Framebuffer.clear scratch ~rgb:0;
  { width; height; pixels = Bytes.make (4 * width * height) '\255'; scratch }

let everywhere (t : t) : clip = { x0 = 0; y0 = 0; x1 = t.width; y1 = t.height; mask = None }
let allowed (c : clip) (x : int) (y : int) : float =
  match c.mask with None -> 1. | Some m -> float_of_int (Bytes.get_uint8 m (((y - c.y0) * (c.x1 - c.x0)) + (x - c.x0))) /. 255.

(* the pixels a shape touches inside a clip, each with how much of it
 * the shape covers: the shape filled white on the scratch picture,
 * read back in its box, and the box wiped *)
let cover (t : t) (c : clip) ~(even_odd : bool) (polygons : point list list) (f : int -> int -> float -> unit) : unit =
  match List.concat polygons with
  | [] -> ()
  | (x, y) :: rest ->
      let bx0, by0, bx1, by1 = List.fold_left (fun (x0, y0, x1, y1) (x, y) -> (Float.min x0 x, Float.min y0 y, Float.max x1 x, Float.max y1 y)) (x, y, x, y) rest in
      let clamp lo hi v = max lo (min hi v) in
      let inside lo hi v = if Float.is_nan v then lo else if v < float_of_int lo then lo else if v > float_of_int hi then hi else int_of_float v in
      let x0 = clamp c.x0 c.x1 (inside 0 t.width (Float.floor bx0) - 1) and x1 = clamp c.x0 c.x1 (inside 0 t.width (Float.ceil bx1) + 1) in
      let y0 = clamp c.y0 c.y1 (inside 0 t.height (Float.floor by0) - 1) and y1 = clamp c.y0 c.y1 (inside 0 t.height (Float.ceil by1) + 1) in
      if x1 > x0 && y1 > y0 then (
        Fill.polygons_aa ~rule:(if even_odd then Even_odd else Nonzero) t.scratch polygons ~rgb:0xffffff ~alpha:1.;
        for y = y0 to y1 - 1 do
          for x = x0 to x1 - 1 do
            let covered = Framebuffer.get_rgb t.scratch ~x ~y land 0xff in
            if covered > 0 then f x y (float_of_int covered /. 255. *. allowed c x y)
          done
        done);
      (* wiped where the shape was, clipped or not *)
      let wx0 = inside 0 t.width (Float.floor bx0) - 1 and wx1 = inside 0 t.width (Float.ceil bx1) + 1 in
      for y = max 0 (inside 0 t.height (Float.floor by0) - 1) to min (t.height - 1) (inside 0 t.height (Float.ceil by1) + 1) do
        Framebuffer.fill_span t.scratch ~y ~x0:(max 0 wx0) ~x1:(min t.width wx1) ~rgb:0 ~alpha:1.
      done

let blend (t : t) (x : int) (y : int) ((r, g, b) : float * float * float) (a : float) : unit =
  if a > 0. then (
    let i = 4 * ((y * t.width) + x) in
    (* old: t.pixels.(i) <- (r *. a) +. (t.pixels.(i) *. (1. -. a)), a float kept *)
    let over (k : int) (v : float) : unit =
      let level = (v *. a) +. (float_of_int (Char.code (Bytes.get t.pixels (i + k))) *. (1. -. a)) in
      Bytes.set t.pixels (i + k) (Char.chr (max 0 (min 255 (int_of_float (Float.round level)))))
    in
    over 0 r;
    over 1 g;
    over 2 b)

let fill (t : t) (c : clip) ~(even_odd : bool) (polygons : point list list) (color : float * float * float) (alpha : float) : unit =
  cover t c ~even_odd polygons (fun x y covered -> blend t x y color (covered *. alpha))

(* a clip made smaller: by a rectangle of whole pixels, or by any shape *)
let clip_box (c : clip) (bx0 : float) (by0 : float) (bx1 : float) (by1 : float) : clip =
  let x0 = max c.x0 (int_of_float (Float.round bx0)) and y0 = max c.y0 (int_of_float (Float.round by0)) in
  let x1 = max x0 (min c.x1 (int_of_float (Float.round bx1))) and y1 = max y0 (min c.y1 (int_of_float (Float.round by1))) in
  (* the part of the mask that is left: its rows' bytes *)
  let mask =
    match c.mask with
    | None -> None
    | Some m ->
        let w = x1 - x0 and old = c.x1 - c.x0 in
        let part = Bytes.create (w * (y1 - y0)) in
        for y = y0 to y1 - 1 do
          Bytes.blit m (((y - c.y0) * old) + (x0 - c.x0)) part ((y - y0) * w) w
        done;
        Some part
  in
  { x0; y0; x1; y1; mask }

let clip_shape (t : t) (c : clip) ~(even_odd : bool) (polygons : point list list) : clip =
  let points = List.concat polygons in
  if points = [] then { c with x1 = c.x0; y1 = c.y0; mask = None }
  else (
    let bx0 = List.fold_left (fun m (x, _) -> Float.min m x) infinity points and bx1 = List.fold_left (fun m (x, _) -> Float.max m x) neg_infinity points in
    let by0 = List.fold_left (fun m (_, y) -> Float.min m y) infinity points and by1 = List.fold_left (fun m (_, y) -> Float.max m y) neg_infinity points in
    let box = clip_box { c with mask = None } (Float.floor bx0) (Float.floor by0) (Float.ceil bx1) (Float.ceil by1) in
    let w = box.x1 - box.x0 in
    let mask = Bytes.make (w * (box.y1 - box.y0)) '\000' in
    cover t box ~even_odd polygons (fun x y covered -> Bytes.set_uint8 mask (((y - box.y0) * w) + (x - box.x0)) (int_of_float (Float.round (covered *. allowed c x y *. 255.))));
    { box with mask = Some mask })

(* a picture of w by h, its unit square put by [m] on the page: each
 * pixel of the page under it takes the picture's nearest four, mixed *)
let image (t : t) (c : clip) (m : Affine.t) ~(w : int) ~(h : int) (sample : int -> int -> float * float * float * float) (alpha : float) : unit =
  let det = (m.a *. m.d) -. (m.b *. m.c) in
  if Float.abs det > 1e-12 && w > 0 && h > 0 then (
    let corners = List.map (Affine.apply m) [ (0., 0.); (1., 0.); (0., 1.); (1., 1.) ] in
    let xs = List.map fst corners and ys = List.map snd corners in
    let box = clip_box c (Float.floor (List.fold_left Float.min infinity xs)) (Float.floor (List.fold_left Float.min infinity ys)) (Float.ceil (List.fold_left Float.max neg_infinity xs)) (Float.ceil (List.fold_left Float.max neg_infinity ys)) in
    let inverse = Affine.invert m in
    for y = box.y0 to box.y1 - 1 do
      for x = box.x0 to box.x1 - 1 do
        let u, v = Affine.apply inverse (float_of_int x +. 0.5, float_of_int y +. 0.5) in
        if u >= 0. && u < 1. && v >= 0. && v < 1. then (
          (* the picture's first row is at the top of its square, where v is 1 *)
          let fx = (u *. float_of_int w) -. 0.5 and fy = ((1. -. v) *. float_of_int h) -. 0.5 in
          let ix = int_of_float (Float.floor fx) and iy = int_of_float (Float.floor fy) in
          let tx = fx -. float_of_int ix and ty = fy -. float_of_int iy in
          let at dx dy = sample (max 0 (min (w - 1) (ix + dx))) (max 0 (min (h - 1) (iy + dy))) in
          let mix (r0, g0, b0, a0) (r1, g1, b1, a1) k = (r0 +. (k *. (r1 -. r0)), g0 +. (k *. (g1 -. g0)), b0 +. (k *. (b1 -. b0)), a0 +. (k *. (a1 -. a0))) in
          let r, g, b, a = mix (mix (at 0 0) (at 1 0) tx) (mix (at 0 1) (at 1 1) tx) ty in
          blend t x y (r, g, b) (a *. alpha *. allowed box x y))
      done
    done)

(* every pixel a clip allows, in a colour that depends on where it is (a gradient) *)
let shade (t : t) (c : clip) (color : float -> float -> (float * float * float) option) (alpha : float) : unit =
  for y = c.y0 to c.y1 - 1 do
    for x = c.x0 to c.x1 - 1 do
      let a = allowed c x y in
      if a > 0. then match color (float_of_int x +. 0.5) (float_of_int y +. 0.5) with Some rgb -> blend t x y rgb (a *. alpha) | None -> ()
    done
  done

(* old: the paper three bytes a pixel, copied here to a picture's four:
 * a page's picture twice in memory at the end of each page *)
let to_image (t : t) : Rgba_image.t = { width = t.width; height = t.height; rgba = t.pixels }
