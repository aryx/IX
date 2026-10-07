(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The platform that asks the draw device for each shape, on Plan 9
 * (mini-9pi; in a window of mini-rio's or on the bare screen):
 * docs/plans/plan_playground.md, stage 3. The playground's native
 * platform, Cairo become Plan 9's draw device.
 *
 * A frame is a list of messages: a rectangle to fill, a polygon, an
 * ellipse, the strokes of a word's letters as lines. The kernel has the
 * pixels and does the drawing; the program computes none. The other
 * platform (../software) computes them all and gives the device a
 * picture.
 *
 *     the view's shapes
 *       | each shape's place: its moves, turns and scales, those of the
 *       | groups it is in (Affine), then the window's
 *       v
 *     points on the window, whole numbers
 *       | Draw.fill, fillpoly, fillellipse, poly: a message each
 *       v
 *     an image of the kernel's, off the screen (the frame is not seen
 *       | half drawn)
 *       v  Draw.draw: one copy
 *     the window
 *
 * What the device does not do, and so is not here: an edge is not
 * smoothed (a pixel is in a shape or is not), and a picture (Image,
 * Bitmap) is its box, grey: the device neither scales nor turns one.
 * A shape that fades is drawn through its colour's opacity, which the
 * device knows.
 *
 * The loop is Plan9_loop's. *)

(* where the program draws: the window, the picture's square in it, the
 * image the frame is drawn in before it is shown, the colours made so
 * far (each an image of one pixel, repeated: by its red, green, blue
 * and opacity), and the last frame's shapes *)
type window = {
  view : Display.image;
  at : Rectangle.t;
  back : Display.image;
  size : int;
  scale : float;
  colors : (int, Display.image) Hashtbl.t;
  mutable last : Playground.shape list option;
}

let window (display : Display.t) : window =
  let view = Display.screen display in
  let w = Rectangle.dx view.r and h = Rectangle.dy view.r in
  let n = max 1 (min w h) in
  let x = view.r.min.x + ((w - n) / 2) and y = view.r.min.y + ((h - n) / 2) in
  let white = Display.color display Display.white in
  Draw.fill view view.r white;
  Display.free white;
  { view; at = Rectangle.v x y (x + n) (y + n); size = n; scale = float n /. Playground.default_width;
    (* (the screen's format: showing it is a copy) *)
    back = Display.alloc display (Rectangle.v 0 0 n n) (Display.format display) ~repl:false Display.white;
    colors = Hashtbl.create 64; last = None }

(* a colour's red, green and blue (Hex "#cc0000", or Rgb) *)
let rgb_of_color (color : Color.t) : int * int * int =
  match color with
  | Rgb (r, g, b) -> (r, g, b)
  | Hex s when String.length s = 7 && s.[0] = '#' ->
      let n = int_of_string ("0x" ^ String.sub s 1 6) in
      ((n lsr 16) land 0xFF, (n lsr 8) land 0xFF, n land 0xFF)
  | Hex s -> failwith ("wrong color format: " ^ s)

(* the image to draw with: the colour, as opaque as alpha says (the
 * device wants a colour's red, green and blue already multiplied by
 * its opacity) *)
let ink (win : window) ((r, g, b) : int * int * int) (alpha : float) : Display.image =
  let a = max 0 (min 255 (int_of_float ((alpha *. 255.) +. 0.5))) in
  let key = (((((r lsl 8) lor g) lsl 8) lor b) * 256) + a in
  match Hashtbl.find_opt win.colors key with
  | Some i -> i
  | None ->
      (* (a game that shades by distance has hundreds: they are let go when too many) *)
      if Hashtbl.length win.colors >= 1024 then begin
        Hashtbl.iter (fun (_ : int) (i : Display.image) -> Display.free i) win.colors;
        Hashtbl.reset win.colors
      end;
      let m (v : int) : int = ((v * a) + 127) / 255 in
      let i = Display.color win.back.display { Display.red = m r; green = m g; blue = m b; alpha = a } in
      Hashtbl.replace win.colors key i;
      i

let round (v : float) : int = int_of_float (Float.floor (v +. 0.5))
let pt ((x, y) : float * float) : Point.t = Point.v (round x) (round y)

(* a shape's own scale, then its turn, then its move (Shape_render_software's) *)
let shape_transform (shape : Playground.shape) : Affine.t =
  let radians = shape.angle *. Float.pi /. 180. in
  Affine.compose (Affine.translate shape.x shape.y) (Affine.compose (Affine.rotate radians) (Affine.scale shape.scale shape.scale))

(* is m only moves and scales along the axes: a rectangle stays one *)
let upright (m : Affine.t) : bool = Float.abs m.b < 1e-9 && Float.abs m.c < 1e-9
(* by how much m scales lengths *)
let length_scale (m : Affine.t) : float = sqrt (Float.abs ((m.a *. m.d) -. (m.b *. m.c)))

let rectangle_corners (w : float) (h : float) : (float * float) list =
  let x = w /. 2. and y = h /. 2. in
  [ (-.x, y); (x, y); (x, -.y); (-.x, -.y) ]

let polygon (win : window) (m : Affine.t) (corners : (float * float) list) (src : Display.image) : unit =
  Draw.fillpoly win.back (List.map (fun (p : float * float) -> pt (Affine.apply m p)) corners) src

let rectangle (win : window) (m : Affine.t) (w : float) (h : float) (src : Display.image) : unit =
  if upright m then begin
    (* its two corners: a fill, the device's fastest *)
    let x0, y0 = Affine.apply m (-.w /. 2., h /. 2.) and x1, y1 = Affine.apply m (w /. 2., -.h /. 2.) in
    let r = Rectangle.v (round (Float.min x0 x1)) (round (Float.min y0 y1)) (round (Float.max x0 x1)) (round (Float.max y0 y1)) in
    Draw.draw win.back r src None Point.zero
  end
  else polygon win m (rectangle_corners w h) src

let ellipse (win : window) (m : Affine.t) (rx : float) (ry : float) (src : Display.image) : unit =
  if upright m then
    Draw.fillellipse win.back (pt (Affine.apply m (0., 0.))) (round (Float.abs m.a *. rx)) (round (Float.abs m.d *. ry)) src
  else begin
    (* turned: its outline as a polygon, as many sides as its size asks *)
    let segments = Circle.segments_for_radius (Float.max rx ry *. length_scale m) in
    polygon win m (Circle.ellipse_points ~rx ~ry ~segments) src
  end

(* Words: the font of strokes (Hershey), each stroke a line through its
 * points, as wide as the pen at this size *)
let words (win : window) (m : Affine.t) (str : string) (src : Display.image) : unit =
  let strokes, width = Hershey.layout str in
  let s = Playground.words_font_size /. Hershey.units_per_em in
  let m = Affine.compose m (Affine.compose (Affine.scale s (-.s)) (Affine.translate (-.width /. 2.) 0.)) in
  let pen = Hershey.units_per_em /. 12. *. length_scale m in
  let thick = max 0 (round ((pen -. 1.) /. 2.)) in
  List.iter (fun (stroke : (float * float) list) -> Draw.poly win.back (List.map (fun (p : float * float) -> pt (Affine.apply m p)) stroke) thick src) strokes

let rec shape (win : window) (m : Affine.t) (s : Playground.shape) : unit =
  let m = Affine.compose m (shape_transform s) in
  let src (c : Color.t) : Display.image = ink win (rgb_of_color c) s.alpha in
  if s.alpha > 0. then
    match s.form with
    | Group shapes -> List.iter (shape win m) shapes
    | Rectangle (c, w, h) -> rectangle win m w h (src c)
    | Polygon (c, points) -> polygon win m points (src c)
    | Ngon (c, n, r) ->
        polygon win m
          (List.init n (fun (i : int) ->
               let a = (90. -. (360. *. float i /. float n)) *. Float.pi /. 180. in
               (r *. cos a, r *. sin a)))
          (src c)
    | Circle (c, r) -> ellipse win m r r (src c)
    | Oval (c, w, h) -> ellipse win m (w /. 2.) (h /. 2.) (src c)
    | Words (c, str) -> words win m str (src c)
    (* (a picture's box) *)
    | Image (w, h, _) | Bitmap (w, h, _) -> rectangle win m w h (ink win (0xc0, 0xc0, 0xc0) s.alpha)

(* a frame: every shape asked of the device, on white, then shown. A
 * frame whose shapes are the last one's is not drawn again. *)
let show (display : Display.t) (win : window) (shapes : Playground.shape list) (fps : int) : bool =
  let shapes = shapes @ [ Session.fps_counter ~width:win.size ~height:win.size ~scale:win.scale fps ] in
  if win.last = Some shapes then false
  else begin
    win.last <- Some shapes;
    Draw.draw win.back win.back.r (ink win (255, 255, 255) 1.) None Point.zero;
    (* the playground's units to the picture's pixels: up is less, the middle is (0, 0) *)
    let half = float win.size /. 2. in
    let m = Affine.compose (Affine.compose (Affine.translate half half) (Affine.scale 1. (-1.))) (Affine.scale win.scale win.scale) in
    List.iter (shape win m) shapes;
    Draw.draw win.view win.at win.back None Point.zero;
    Display.flush display;
    true
  end

let flags = Plan9_loop.flags

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  Plan9_loop.run_app
    { Plan9_loop.make = window; at = (fun (w : window) -> w.at); show;
      free = (fun (w : window) -> Hashtbl.iter (fun (_ : int) (i : Display.image) -> Display.free i) w.colors; Display.free w.back) }
    caps flags app
