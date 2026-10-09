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
  recent : int array;
  inks : Display.image option array;
  written : (string, Affine.t * Point.t list list * int) Hashtbl.t;
  mutable last : Playground.shape list option;
}

(* The meter (the flag stats=on, with the loop's): of a frame's showing,
 * the messages made here and the device's time for them (the messages
 * are then all kept until the frame's end: Display.hold). *)
let stats = ref false
let m_messages = ref 0. and m_device = ref 0. and m_frames = ref 0
let meter (messages : float) (device : float) (shapes : int) : unit =
  m_messages := !m_messages +. messages; m_device := !m_device +. device;
  incr m_frames;
  if !m_frames = 40 then begin
    prerr_string (Printf.sprintf "  the showing: %d shapes, messages %.0f ms, the device %.0f ms each\n" shapes (!m_messages *. 25.) (!m_device *. 25.));
    flush stderr;
    m_messages := 0.; m_device := 0.; m_frames := 0
  end

(* the square's side, at most (the flag size=480; 0: the window's): a
 * shape's cost in the device is its pixels', and a game whose whole
 * picture turns is half as fast on a screen of 1024 by 768 as it was on
 * 640 by 480 (the author's Pi1, 2026-10-09: "cameltry now is at
 * 11fps", where it was 22) *)
let side = ref 0

let window (display : Display.t) : window =
  let view = Display.screen display in
  Display.hold display !stats;
  let w = Rectangle.dx view.r and h = Rectangle.dy view.r in
  let n = max 1 (min w h) in
  let n = if !side > 0 then min n !side else n in
  let x = view.r.min.x + ((w - n) / 2) and y = view.r.min.y + ((h - n) / 2) in
  let white = Display.color display Display.white in
  Draw.fill view view.r white;
  Display.free white;
  { view; at = Rectangle.v x y (x + n) (y + n); size = n; scale = float n /. Playground.default_width;
    (* (the screen's format: showing it is a copy) *)
    back = Display.alloc display (Rectangle.v 0 0 n n) (Display.format display) ~repl:false Display.white;
    colors = Hashtbl.create 64; recent = Array.make 256 (-1); inks = Array.make 256 None; written = Hashtbl.create 16; last = None }

(* What a shape costs here is counted in the plan
 * (docs/plans/plan_playground_speed.md): by mini-ml's code on arm a
 * frame of 230 rectangles was 7 million instructions before the device
 * had drawn anything, a third of them in what follows; so the common
 * cases have a short way, the general one kept beside it (old:). *)
let fast = ref true

(* a colour's red, green and blue (Hex "#cc0000", or Rgb) *)
let hex_digit (c : char) : int =
  if c >= '0' && c <= '9' then Char.code c - 48
  else if c >= 'a' && c <= 'f' then Char.code c - 87
  else if c >= 'A' && c <= 'F' then Char.code c - 55
  else -1
let rgb_of_color (color : Color.t) : int * int * int =
  match color with
  | Rgb (r, g, b) -> (r, g, b)
  | Hex s when String.length s = 7 && s.[0] = '#' ->
      let pair (i : int) : int = (hex_digit (String.unsafe_get s i) * 16) + hex_digit (String.unsafe_get s (i + 1)) in
      let r = pair 1 and g = pair 3 and b = pair 5 in
      (* (old, for all: a string made and read, 3,000 instructions) *)
      if !fast && r >= 0 && g >= 0 && b >= 0 then (r, g, b)
      else
        let n = int_of_string ("0x" ^ String.sub s 1 6) in
        ((n lsr 16) land 0xFF, (n lsr 8) land 0xFF, n land 0xFF)
  | Hex s -> failwith ("wrong color format: " ^ s)

(* the image to draw with: the colour, as opaque as alpha says (the
 * device wants a colour's red, green and blue already multiplied by
 * its opacity) *)
let ink (win : window) ((r, g, b) : int * int * int) (alpha : float) : Display.image =
  let a = max 0 (min 255 (int_of_float ((alpha *. 255.) +. 0.5))) in
  let key = (((((r lsl 8) lor g) lsl 8) lor b) * 256) + a in
  (* (asked for a moment ago: found without the table, whose hash is a
   * call of the runtime; 256 places, a colour's by its bits) *)
  let slot = (key lxor (key lsr 9) lxor (key lsr 17)) land 255 in
  match if !fast && Array.unsafe_get win.recent slot = key then Array.unsafe_get win.inks slot else None with
  | Some i -> i
  | None ->
  let i =
  match Hashtbl.find_opt win.colors key with
  | Some i -> i
  | None ->
      (* (a game that shades by distance has hundreds: they are let go when too many) *)
      if Hashtbl.length win.colors >= 1024 then begin
        Hashtbl.iter (fun (_ : int) (i : Display.image) -> Display.free i) win.colors;
        Hashtbl.reset win.colors;
        Array.fill win.recent 0 256 (-1)
      end;
      let m (v : int) : int = ((v * a) + 127) / 255 in
      let i = Display.color win.back.display { Display.red = m r; green = m g; blue = m b; alpha = a } in
      Hashtbl.replace win.colors key i;
      i in
  win.recent.(slot) <- key;
  win.inks.(slot) <- Some i;
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

(* an upright rectangle's pixels *)
let box (m : Affine.t) (w : float) (h : float) : Rectangle.t =
  (* its two corners: a fill, the device's fastest *)
  (* (no turn at all: an x is m.a times it, moved, the product with
   * m.c being 0; 4 products for 8) *)
  let (x0, y0), (x1, y1) =
    if !fast && m.b = 0. && m.c = 0. then
      let hw = w /. 2. and hh = h /. 2. in
      (((m.a *. -.hw) +. m.tx, (m.d *. hh) +. m.ty), ((m.a *. hw) +. m.tx, (m.d *. -.hh) +. m.ty))
    else (Affine.apply m (-.w /. 2., h /. 2.), Affine.apply m (w /. 2., -.h /. 2.)) in
  (* (the least of two rounded is the least rounded: whole numbers
   * compared, where Float.min is a function, of 360 instructions.
   * old: Rectangle.v (round (Float.min x0 x1)) (round (Float.min y0 y1)) (round (Float.max x0 x1)) (round (Float.max y0 y1))) *)
  let x0 = round x0 and y0 = round y0 and x1 = round x1 and y1 = round y1 in
  Rectangle.v (if x0 < x1 then x0 else x1) (if y0 < y1 then y0 else y1) (if x0 < x1 then x1 else x0) (if y0 < y1 then y1 else y0)

let rectangle (win : window) (m : Affine.t) (w : float) (h : float) (src : Display.image) : unit =
  if upright m then Draw.draw win.back (box m w h) src None Point.zero
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
(* (a word at the place it was last drawn, a score or the frames a
 * second: its strokes' points are kept, where each was a letter's
 * strokes found and every point moved, each frame) *)
(* (and Plan 9's own letters, the default font's (Font: a bitmap, 9 by
 * 15 pixels a letter), for a word that is upright and whose size here
 * is about theirs: a bitmap is not scaled. The author, 2026-10-08, of
 * mini-drscheme on his Pi1: "the text is hard to read; would it be
 * possible to reuse the font from plan9 instead of hershey thing?". A
 * letter is then one message, where it was a line for each of its
 * strokes. On a screen of 1024 by 768 a program's square is 768 pixels:
 * mini-drscheme's letters are 12 there and its cell 8 by 15, the font's;
 * in a small window they are the strokes again ("I guess we need to
 * default to hershey if the word requested need scaling?": yes). And a
 * word of several letters only if the font's is no wider than the
 * strokes' by a tenth: a program gave it the room the strokes take (a
 * button's name, a status line), and Plan 9's letters, all 9 wide, are
 * often wider; a letter alone was given a cell by a program that lays
 * its text out itself. The flag font=hershey: the strokes always.) *)
let bitmap = ref true
let font : Font.t option ref = ref None
let smallest = 11. and largest = 16.

let words (win : window) (m : Affine.t) (str : string) (src : Display.image) : unit =
  let size = Playground.words_font_size *. length_scale m in
  let fits (f : Font.t) : bool =
    String.length str = 1
    || float (Font.width f str) <= 1.1 *. snd (Hershey.layout str) *. size /. Hershey.units_per_em in
  let f = if !bitmap && upright m && size >= smallest && size <= largest then
      Some (match !font with Some f -> f | None -> let f = Font.default win.back.display in font := Some f; f)
    else None in
  if (match f with Some f -> fits f | None -> false) then begin
    let f = match f with Some f -> f | None -> assert false in
    (* (centred where the strokes are: on the shape's place) *)
    let c = pt (Affine.apply m (0., 0.)) in
    ignore (Font.string win.back (Point.v (c.x - (Font.width f str / 2)) (c.y - (Font.height f / 2))) src f str)
  end
  else
  let strokes, thick =
    match if !fast then Hashtbl.find_opt win.written str else None with
    | Some (m', strokes, thick) when m' = m -> (strokes, thick)
    | _ ->
        let at = m in
        let strokes, width = Hershey.layout str in
        let s = Playground.words_font_size /. Hershey.units_per_em in
        let m = Affine.compose m (Affine.compose (Affine.scale s (-.s)) (Affine.translate (-.width /. 2.) 0.)) in
        let pen = Hershey.units_per_em /. 12. *. length_scale m in
        let thick = max 0 (round ((pen -. 1.) /. 2.)) in
        let strokes = List.map (fun (stroke : (float * float) list) -> List.map (fun (p : float * float) -> pt (Affine.apply m p)) stroke) strokes in
        if Hashtbl.length win.written >= 64 then Hashtbl.reset win.written;
        Hashtbl.replace win.written str (at, strokes, thick);
        (strokes, thick) in
  List.iter (fun (stroke : Point.t list) -> Draw.poly win.back stroke thick src) strokes

(* A shape not turned: m, then its move and its scale, written out
 * (the same numbers as the three products below give, a turn of 0
 * being 1s and 0s: 8 products for 36, and no sine); one neither moved
 * nor scaled, a group most often: m. *)
let placed (m : Affine.t) (s : Playground.shape) : Affine.t =
  if !fast && s.angle = 0. then
    if s.x = 0. && s.y = 0. && s.scale = 1. then m
    else
      let k = s.scale in
      { Affine.a = m.a *. k; b = m.b *. k; c = m.c *. k; d = m.d *. k;
        tx = (m.a *. s.x) +. (m.c *. s.y) +. m.tx; ty = (m.b *. s.x) +. (m.d *. s.y) +. m.ty }
  else Affine.compose m (shape_transform s)

let rec shape (win : window) (m : Affine.t) (s : Playground.shape) : unit =
  let m = placed m s in
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

(* the frames a second, written at the bottom; not with fps=off (a
 * recorded session waits for a screen that is still, and a program
 * that waits for a key is still but for that number) *)
let counter = ref true

(* a frame: every shape asked of the device, on white, then shown. A
 * frame whose shapes are the last one's is not drawn again. *)
let show (display : Display.t) (win : window) (shapes : Playground.shape list) (fps : int) : bool =
  let shapes = if !counter then shapes @ [ Session.fps_counter ~width:win.size ~height:win.size ~scale:win.scale fps ] else shapes in
  if win.last = Some shapes then false
  else begin
    win.last <- Some shapes;
    let t0 = if !stats then Unix.gettimeofday () else 0. in
    (* the playground's units to the picture's pixels: up is less, the middle is (0, 0) *)
    let half = float win.size /. 2. in
    let m = Affine.compose (Affine.compose (Affine.translate half half) (Affine.scale 1. (-1.))) (Affine.scale win.scale win.scale) in
    (* OPTIMIZATION: the picture is not made white where the first
     * shapes cover it. A game's first shapes are its background, a
     * rectangle not turned, opaque, as wide as the picture
     * (TinyCameltry's one, TinyWolfenstein's ceiling and floor): they
     * are drawn first, their rows noted, and only the rows between
     * them are made white, none for those two. The white was the
     * picture written once more each frame, 460 KB of the 1.8 MB a
     * frame's four copies are (docs/plans/plan_playground_speed.md).
     * The same pixels: an opaque rectangle leaves nothing of what was
     * under it.
     * old: Draw.draw win.back win.back.r white None Point.zero;
     *      List.iter (shape win m) shapes *)
    let white = ink win (255, 255, 255) 1. in
    let all = win.back.r in
    let rec background (rows : (int * int) list) (shapes : Playground.shape list) : (int * int) list * Playground.shape list =
      match shapes with
      | s :: rest when !fast && s.alpha = 1. ->
          (match s.form with
           | Rectangle (c, w, h) when upright (placed m s) ->
               let r = box (placed m s) w h in
               if r.min.x <= all.min.x && r.max.x >= all.max.x then begin
                 Draw.draw win.back r (ink win (rgb_of_color c) 1.) None Point.zero;
                 background ((r.min.y, r.max.y) :: rows) rest
               end
               else (rows, shapes)
           | _ -> (rows, shapes))
      | _ -> (rows, shapes) in
    let rows, others = background [] shapes in
    (* the rows left, from the top: white *)
    let rec clear (y : int) (rows : (int * int) list) : unit =
      match rows with
      | (y0, y1) :: rest ->
          if y0 > y && y < all.max.y then Draw.draw win.back (Rectangle.v all.min.x y all.max.x (min y0 all.max.y)) white None Point.zero;
          clear (max y y1) rest
      | [] -> if y < all.max.y then Draw.draw win.back (Rectangle.v all.min.x y all.max.x all.max.y) white None Point.zero in
    clear all.min.y (List.sort (fun ((a : int), (_ : int)) ((b : int), (_ : int)) -> a - b) rows);
    List.iter (shape win m) others;
    Draw.draw win.view win.at win.back None Point.zero;
    let t1 = if !stats then Unix.gettimeofday () else 0. in
    Display.flush display;
    if !stats then meter (t1 -. t0) (Unix.gettimeofday () -. t1) (List.length shapes);
    true
  end

let flags = Plan9_loop.flags

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  stats := List.assoc_opt "stats" (Plan9_loop.flags caps) = Some "on";
  counter := List.assoc_opt "fps" (Plan9_loop.flags caps) <> Some "off";
  bitmap := List.assoc_opt "font" (Plan9_loop.flags caps) <> Some "hershey";
  side := (match List.assoc_opt "size" (Plan9_loop.flags caps) with Some s -> (try int_of_string s with Failure _ -> 0) | None -> 0);
  Plan9_loop.run_app
    { Plan9_loop.make = window; at = (fun (w : window) -> w.at); show;
      free = (fun (w : window) -> Hashtbl.iter (fun (_ : int) (i : Display.image) -> Display.free i) w.colors; Display.free w.back) }
    caps flags app
