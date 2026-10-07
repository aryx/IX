(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* ix: the playground's playground/platforms/software/Shape_render_software.ml,
 * less: its pictures (Image, Bitmap: drawn here as their box, grey, until
 * Blit is copied too), its debug views (bounding boxes, wireframe: the
 * playground's "b" and "f" keys), render_region and pixel_bounds. And its
 * optional arguments said (render's options and scale, Fill's rule). *)

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* From Playground shapes to pixels. The pipeline, for each shape:
 *
 *   shape, in its own local coordinates
 *     (e.g. [rectangle red 100. 50.] is the box from (-50, -25) to (50, 25))
 *       |
 *       | shape transform: its scale, rotate, and move
 *       v
 *   Elm world coordinates (origin at the center of the window, y up)
 *       |
 *       | screen transform: y flip + move the origin to the center
 *       v
 *   pixel coordinates (origin at the top-left corner, y down)
 *       |
 *       | rasterization: which pixels does the shape cover?
 *       v
 *   pixels in the framebuffer
 *
 * The two transforms are Affine matrices, multiplied into one before
 * any point is transformed; a [group] just multiplies in one more.
 *
 * Rectangles, polygons, and ngons are polygons: their corners go
 * through the transform, then Fill.polygon fills them. Circles use the
 * midpoint circle algorithm (Circle), unless the transform stretches
 * them into ellipses, which, like ovals, become polygons with many
 * sides. Words are drawn with the lines of a vector font (Hershey).
 *)

(*****************************************************************************)
(* Colors *)
(*****************************************************************************)

(* Playground colors to 0xRRGGBB ints; e.g. Hex "#cc0000" -> 0xcc0000,
 * Rgb (255, 128, 0) -> 0xff8000 *)
let rgb_of_color (color : Color.t) : int =
  match color with
  | Rgb (r, g, b) -> (r lsl 16) lor (g lsl 8) lor b
  | Hex s when String.length s = 7 && s.[0] = '#' -> int_of_string ("0x" ^ String.sub s 1 6)
  | Hex s -> failwith (Printf.sprintf "wrong color format: %s" s)

(* Images don't have a color; their box is drawn in light gray *)
let image_placeholder_rgb = 0xc0c0c0

(*****************************************************************************)
(* Transforms *)
(*****************************************************************************)

(* Elm world coordinates -> pixel coordinates. For a 1000x1000
 * framebuffer:
 *   Elm (0, 0), the center        -> pixel (500, 500)
 *   Elm (0, 100), above center    -> pixel (500, 400)
 *   Elm (-500, 500), top-left     -> pixel (0, 0)
 * i.e. first flip y (scale 1 -1), then move the origin to the center. *)
let screen_transform (fb : Framebuffer.t) : Affine.t =
  Affine.compose
    (Affine.translate (float fb.width /. 2.) (float fb.height /. 2.))
    (Affine.scale 1. (-1.))

(* A shape's own scale, then rotation, then move -- the same order as
 * the web backend's SVG "translate(x, y) rotate(a) scale(s)", which
 * also applies right to left. Scaling or rotating *after* moving would
 * scale or rotate the shape's position around the window's center too.
 * Playground angles are in degrees, counterclockwise. *)
let shape_transform (shape : Playground.shape) : Affine.t =
  let radians = shape.angle *. Float.pi /. 180. in
  Affine.compose
    (Affine.translate shape.x shape.y)
    (Affine.compose (Affine.rotate radians) (Affine.scale shape.scale shape.scale))

(*****************************************************************************)
(* Forms as polygons, circles, and boxes *)
(*****************************************************************************)
(* Every form becomes, in pixel coordinates, either a polygon or (for
 * circles that stay circles) a center and a radius *)

let rectangle_corners w h =
  let x = w /. 2. and y = h /. 2. in
  [ (-.x, y); (x, y); (x, -.y); (-.x, -.y) ]

(* n corners on the circle of radius r, the first one at the top (90
 * degrees), then every 360/n degrees clockwise, like elm-playground;
 * e.g. for a triangle, at 90, -30, and -150 degrees:
 * (0, r), (0.87r, -0.5r), (-0.87r, -0.5r) *)
let ngon_corners n r =
  List.init n (fun i ->
      let degrees = 90. -. (360. *. float i /. float n) in
      let radians = degrees *. Float.pi /. 180. in
      (r *. cos radians, r *. sin radians))

(* A circle stays a circle when [m] only moves, rotates, flips, and
 * scales by the same amount in every direction: its two columns (where
 * the x and y axes go) must be perpendicular (dot product 0) and of
 * the same length. Then the center is where (0, 0) goes and the radius
 * is scaled by that length. Otherwise (e.g. a group scaled only
 * horizontally... not possible in Playground today, but free to
 * support) it's an ellipse. *)
let circle_in_pixels (m : Affine.t) (r : float) : ((float * float) * float) option =
  let scale_x = Float.hypot m.a m.b and scale_y = Float.hypot m.c m.d in
  let perpendicular = Float.abs ((m.a *. m.c) +. (m.b *. m.d)) < 1e-9 *. scale_x *. scale_y in
  if perpendicular && Float.abs (scale_x -. scale_y) < 1e-9 *. scale_x then
    Some (Affine.apply m (0., 0.), r *. scale_x)
  else None

(* An ellipse (or a circle that doesn't stay one) as a polygon in pixel
 * coordinates, with as many sides as its size on screen needs *)
let ellipse_polygon (m : Affine.t) ~rx ~ry : (float * float) list =
  let scale = Float.max (Float.hypot m.a m.b) (Float.hypot m.c m.d) in
  let segments = Circle.segments_for_radius (Float.max rx ry *. scale) in
  List.map (Affine.apply m) (Circle.ellipse_points ~rx ~ry ~segments)

(*****************************************************************************)
(* Text *)
(*****************************************************************************)

(* The pen's width, in font units: 1/12 of the em, a regular weight *)
let pen_width = Hershey.units_per_em /. 12.

(* Hershey font units to the local coordinates of a [words] shape:
 * centered on (0, 0) like in the other backends (the web's
 * text-anchor="middle" and dominant-baseline="central"): move left by
 * half the text's width (Hershey's y = 0 already is the middle of the
 * em), flip y (the font's y goes down), and scale the em to the font
 * size; e.g. at font size 10, "A" is 18 * 10/30 = 6 units wide *)
let text_to_local ~width : Affine.t =
  let s = Playground.words_font_size /. Hershey.units_per_em in
  Affine.compose (Affine.scale s (-.s)) (Affine.translate (-.width /. 2.) 0.)

(* By how much [m] scales lengths (on average, if it stretches more in
 * one direction): the square root of how much it scales areas *)
let length_scale (m : Affine.t) : float = sqrt (Float.abs ((m.a *. m.d) -. (m.b *. m.c)))

(*****************************************************************************)
(* Options *)
(*****************************************************************************)

type options = { alpha_blending : bool; antialiasing : bool }

let default_options = { alpha_blending = true; antialiasing = true }

(* The opacity to draw with. Without blending, there's no "partly
 * there": e.g. [fade 0.2] draws fully opaque, only [fade 0.] hides *)
let effective_alpha (options : options) (alpha : float) : float =
  if options.alpha_blending then alpha else if alpha > 0. then 1. else 0.

(*****************************************************************************)
(* Drawing polygons and circles *)
(*****************************************************************************)

(* With [~aa] (antialiasing), each function below uses the antialiased
 * version of its algorithm: Fill.polygons_aa instead of Fill.polygon,
 * Line.draw_aa (Wu) instead of Line.draw (Bresenham) *)

let fill_polygon ~(aa : bool) (fb : Framebuffer.t) (points : (float * float) list) ~(rgb : int) ~(alpha : float) : unit =
  if aa then Fill.polygons_aa ~rule:Fill.Nonzero fb [ points ] ~rgb ~alpha
  else Fill.polygon ~rule:Fill.Nonzero fb points ~rgb ~alpha

(* The midpoint circle algorithm works on the pixel grid: its center is
 * a pixel (the one containing the real center) and its radius a whole
 * number of pixels, so the circle can be up to half a pixel off --
 * one reason why modern renderers prefer polygons, whose corners can
 * be anywhere between pixels. It also only decides "in or out" for
 * each pixel, so antialiased circles are polygons. *)
let circle_polygon ((cx, cy), r) =
  Circle.ellipse_points ~rx:r ~ry:r ~segments:(Circle.segments_for_radius r)
  |> List.map (fun (x, y) -> (cx +. x, cy +. y))

let fill_circle ~(aa : bool) (fb : Framebuffer.t) (((cx, cy), r) as circle) ~(rgb : int) ~(alpha : float) : unit =
  if aa then Fill.polygons_aa ~rule:Fill.Nonzero fb [ circle_polygon circle ] ~rgb ~alpha
  else
    let pixel v = int_of_float (Float.floor v) in
    Circle.fill fb ~cx:(pixel cx) ~cy:(pixel cy) ~r:(int_of_float (Float.round r)) ~rgb ~alpha

(* A line through points, 1 pixel wide *)
let thin_polyline ~(aa : bool) (fb : Framebuffer.t) (points : (float * float) list) ~(rgb : int) ~(alpha : float) : unit =
  let rec loop = function
    | p :: (q :: _ as rest) ->
        if aa then Line.draw_aa fb p q ~rgb ~alpha else Line.draw fb p q ~rgb ~alpha;
        loop rest
    | [ _ ] | [] -> ()
  in
  loop points

(* Text: Hershey's strokes, drawn 1 pixel wide when the pen would be
 * thinner than that anyway, else as thick strokes *)
let draw_words (options : options) (fb : Framebuffer.t) (m : Affine.t) (str : string) ~(rgb : int) ~(alpha : float) : unit =
  let strokes, width = Hershey.layout str in
  let m = Affine.compose m (text_to_local ~width) in
  let lines = List.map (List.map (Affine.apply m)) strokes in
  let pen = pen_width *. length_scale m in
  let aa = options.antialiasing in
  if pen < 1.5 then List.iter (fun l -> thin_polyline ~aa fb l ~rgb ~alpha) lines
  else if aa then Fill.polygons_aa ~rule:Fill.Nonzero fb (Stroke.contours lines ~width:pen) ~rgb ~alpha
  else Stroke.polylines fb lines ~width:pen ~rgb ~alpha

(*****************************************************************************)
(* Shapes *)
(*****************************************************************************)

(* The color to draw a (non-group) form with *)
let form_rgb (form : Playground.form) : int =
  match form with
  | Circle (color, _)
  | Oval (color, _, _)
  | Rectangle (color, _, _)
  | Ngon (color, _, _)
  | Polygon (color, _)
  | Words (color, _) ->
      rgb_of_color color
  | Image _ | Bitmap _ | Group _ -> image_placeholder_rgb

(* A (non-group) form, [m] taking its local coordinates to pixels *)
let render_form (options : options) (fb : Framebuffer.t) (m : Affine.t) (form : Playground.form) ~rgb ~alpha =
  let aa = options.antialiasing in
  let polygon local_corners = fill_polygon ~aa fb (List.map (Affine.apply m) local_corners) ~rgb ~alpha in
  match form with
  | Rectangle (_, w, h) -> polygon (rectangle_corners w h)
  | Polygon (_, points) -> polygon points
  | Ngon (_, n, r) -> polygon (ngon_corners n r)
  | Circle (_, r) -> (
      match circle_in_pixels m r with
      | Some circle -> fill_circle ~aa fb circle ~rgb ~alpha
      | None -> fill_polygon ~aa fb (ellipse_polygon m ~rx:r ~ry:r) ~rgb ~alpha)
  | Oval (_, w, h) -> fill_polygon ~aa fb (ellipse_polygon m ~rx:(w /. 2.) ~ry:(h /. 2.)) ~rgb ~alpha
  (* ix: a picture's box, until Blit is here *)
  | Image (w, h, _) | Bitmap (w, h, _) -> polygon (rectangle_corners w h)
  | Words (_, str) -> draw_words options fb m str ~rgb ~alpha
  | Group _ -> ()

(* [m] is the transform from the coordinates [shape] lives in (the
 * window's, or its enclosing group's) to pixel coordinates *)
let rec render_shape (options : options) (fb : Framebuffer.t) (m : Affine.t) (shape : Playground.shape) : unit =
  let m = Affine.compose m (shape_transform shape) in
  match shape.form with
  | Group shapes ->
      (* TODO: alpha, like Shape_render_native; doing it right needs an
       * offscreen layer (fading each child separately would let
       * overlapping children show through each other) *)
      List.iter (render_shape options fb m) shapes
  | form ->
      render_form options fb m form ~rgb:(form_rgb form) ~alpha:(effective_alpha options shape.alpha)

let render ~(options : options) ~(scale : float) (fb : Framebuffer.t) (shapes : Playground.shape list) : unit =
  let m = if scale = 1. then screen_transform fb else Affine.compose (screen_transform fb) (Affine.scale scale scale) in
  List.iter (render_shape options fb m) shapes
