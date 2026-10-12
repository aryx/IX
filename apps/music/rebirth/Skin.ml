(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Skin.mli *)

type palette = {
  name : string;
  metal : (int * int * int) array;
  ink : (int * int * int) array;
  keys808 : (int * int * int) array;
  key909 : int * int * int;
  lamp : int * int * int;
  playing : int * int * int;
  glow : int * int * int;
  cap : int * int * int;
  wall : int * int * int;
}

(* the pictures made so far, each under what was asked *)
type t = { colors : palette; made : (string, Rgba_image.t) Hashtbl.t }

let make (colors : palette) : t = { colors; made = Hashtbl.create 64 }
let palette (t : t) : palette = t.colors
let color ((r, g, b) : int * int * int) : Color.t = Color.rgb r g b

(* what is written on a cap (a button's, a key's): dark on a light
 * one, the skin's light on a dark one *)
let on_cap (t : t) : Color.t =
  let (r, g, b) = t.colors.cap in
  if r + g + b > 384 then Color.rgb 20 20 22 else color t.colors.glow

let all : palette list =
  [ { name = "rb-338";
      metal = [| (198, 200, 204); (198, 200, 204); (44, 44, 48); (186, 184, 176); (150, 160, 172); (70, 74, 84) |];
      ink = [| (28, 28, 30); (28, 28, 30); (240, 140, 50); (40, 40, 40); (24, 28, 34); (225, 225, 230) |];
      keys808 = [| (205, 55, 45); (235, 120, 40); (235, 200, 60); (236, 232, 218) |];
      key909 = (232, 232, 226);
      lamp = (255, 50, 30); playing = (255, 225, 60); glow = (255, 70, 40);
      cap = (214, 216, 220); wall = (22, 22, 26) };
    { name = "night";
      metal = [| (58, 64, 78); (58, 64, 78); (30, 32, 40); (46, 50, 62); (40, 46, 60); (26, 28, 36) |];
      ink = [| (190, 205, 230); (190, 205, 230); (120, 210, 255); (200, 210, 225); (170, 190, 220); (190, 205, 230) |];
      keys808 = [| (60, 110, 200); (70, 150, 210); (90, 190, 200); (150, 170, 190) |];
      key909 = (120, 134, 156);
      lamp = (90, 230, 255); playing = (255, 190, 70); glow = (110, 220, 255);
      cap = (40, 44, 54); wall = (8, 9, 12) } ]

(*****************************************************************************)
(* Pixels *)
(*****************************************************************************)

(* a picture, each pixel asked: red, green, blue, and how opaque (255:
 * all) *)
let image (w : int) (h : int) (f : int -> int -> int * int * int * int) : Rgba_image.t =
  let img = Rgba_image.create ~width:w ~height:h in
  let byte (v : int) : char = Char.chr (if v < 0 then 0 else if v > 255 then 255 else v) in
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      let (r, g, b, a) = f x y in
      let at = 4 * ((y * w) + x) in
      Bytes.set img.rgba at (byte r);
      Bytes.set img.rgba (at + 1) (byte g);
      Bytes.set img.rgba (at + 2) (byte b);
      Bytes.set img.rgba (at + 3) (byte a)
    done
  done;
  img

let kept (t : t) (what : string) (make : unit -> Rgba_image.t) : Rgba_image.t =
  match Hashtbl.find_opt t.made what with
  | Some img -> img
  | None -> let img = make () in Hashtbl.replace t.made what img; img

(* 0 to 255 from a pixel's place: the low 30 bits of products, the same
 * on a machine of 32 bits and on one of 64 *)
let noise (x : int) (y : int) (seed : int) : int =
  let m = 0x3fffffff in
  let n = (((x land 0xffff) * 7919) lxor ((y land 0xffff) * 104729) lxor (seed * 1299709)) land m in
  let n = ((n lxor (n lsr 13)) * 1274126177) land m in
  let n = ((n lxor (n lsr 15)) * 668265263) land m in
  (n lsr 11) land 0xff

(* a colour lighter or darker by [d] *)
let shade ((r, g, b) : int * int * int) (d : int) : int * int * int = (r + d, g + d, b + d)
let mix ((r, g, b) : int * int * int) ((r', g', b') : int * int * int) (k : int) : int * int * int =
  (* k of 256 of the second *)
  (r + ((r' - r) * k / 256), g + ((g' - g) * k / 256), b + ((b' - b) * k / 256))
let opaque ((r, g, b) : int * int * int) : int * int * int * int = (r, g, b, 255)

(* brushed metal at a pixel: a streak a row, the brush's, which is
 * noise stretched 32 pixels along x; grain; lighter at the top, where
 * the light is *)
let brushed (base : int * int * int) (seed : int) (x : int) (y : int) (h : int) : int * int * int =
  let cell = x lsr 5 and t = x land 31 in
  let a = noise cell y seed and b = noise (cell + 1) y seed in
  let streak = (a + ((b - a) * t / 32)) - 128 in
  let grain = noise x y (seed + 1) - 128 in
  shade base ((streak / 9) + (grain / 24) + (10 - (20 * y / max 1 h)))

(* a plate's edges: light at the top and the left, dark at the bottom
 * and the right, two pixels each *)
let bevel (w : int) (h : int) (x : int) (y : int) (c : int * int * int) : int * int * int =
  if y < 2 || x < 2 then shade c 34 else if y >= h - 2 || x >= w - 2 then shade c (-46) else c

(* how far a pixel's centre is from a point, in 16ths of a pixel *)
let distance16 (x : int) (y : int) (cx16 : int) (cy16 : int) : int =
  let dx = (16 * x) + 8 - cx16 and dy = (16 * y) + 8 - cy16 in
  int_of_float (sqrt (float_of_int ((dx * dx) + (dy * dy))))

(* 0 to 255: how much of a pixel at distance d (16ths) is inside a disc
 * of radius r (16ths): its edge a pixel wide *)
let inside (d : int) (r : int) : int = let k = (r - d + 8) * 16 in if k < 0 then 0 else if k > 255 then 255 else k

(*****************************************************************************)
(* The pictures *)
(*****************************************************************************)

let panel (t : t) (k : int) (w : int) (h : int) : Rgba_image.t =
  kept t (Printf.sprintf "panel %d %d %d" k w h) (fun () ->
      let base = t.colors.metal.(k) in
      image w h (fun x y ->
          let c = brushed base (17 * (k + 1)) x y h in
          (* the 808's stripes under its name, red, orange, yellow; the
           * 909's orange line *)
          let c =
            if k = 2 && x > 95 && x < 260 && y >= h - 14 && y < h - 5 then t.colors.keys808.((y - (h - 14)) / 3)
            else if k = 3 && x > 20 && x < w - 20 && y >= h - 9 && y < h - 6 then (235, 120, 40)
            else c in
          opaque (bevel w h x y c)))

(* a knob: a shadow under it, a dark skirt with its ridges, a cap
 * lit from the top left, a pointer *)
let knob (t : t) (d : int) (fraction : float) : Rgba_image.t =
  let steps = 64 in
  let f = if fraction < 0. then 0. else if fraction > 1. then 1. else fraction in
  let i = int_of_float ((f *. float_of_int steps) +. 0.5) in
  kept t (Printf.sprintf "knob %d %d" d i) (fun () ->
      (* (the toolkit's angle: Look.knob_angle) *)
      let a = (225. -. (270. *. float_of_int i /. float_of_int steps)) *. 3.14159265358979 /. 180. in
      let ca = cos a and sa = sin a in
      let c16 = 8 * d and r = (8 * d) - 40 in
      let cap = t.colors.cap in
      image d d (fun x y ->
          let dist = distance16 x y c16 c16 in
          let shadow = inside (distance16 x y (c16 + 24) (c16 + 40)) (r + 8) in
          let body = inside dist r in
          if body = 0 then (0, 0, 0, shadow * 110 / 255)
          else begin
            let dx = float_of_int ((16 * x) + 8 - c16) /. 16. and dy = float_of_int (c16 - ((16 * y) + 8)) /. 16. in
            let rr = float_of_int r /. 16. in
            (* the skirt, ridged around; the cap inside it, a cone: lit
             * where it faces the top left *)
            let radius = sqrt ((dx *. dx) +. (dy *. dy)) in
            let facing = if radius < 0.01 then 0. else ((dy -. dx) /. radius) *. 0.707 in
            let c =
              if radius > rr *. 0.74 then begin
                let ridge = int_of_float (atan2 dy dx *. 24. /. 3.14159265358979) in
                shade (38, 38, 42) ((if (ridge + 48) land 1 = 0 then 10 else -6) + int_of_float (facing *. 26.))
              end
              else shade cap (int_of_float (facing *. 38. *. (0.3 +. (radius /. rr))) - 4) in
            (* the pointer: from near the centre to the cap's edge *)
            let along = (dx *. ca) +. (dy *. sa) and across = Float.abs ((dy *. ca) -. (dx *. sa)) in
            let c = if along > rr *. 0.18 && along < rr *. 0.72 && across < 1.4 then (let (r, g, b) = cap in if r + g + b > 384 then (20, 20, 22) else t.colors.glow) else c in
            let (cr, cg, cb) = c in
            if body = 255 then (cr, cg, cb, 255) else (cr, cg, cb, max body (shadow * 110 / 255))
          end))

(* a lamp in a picture: its light at (cx, cy), 3 pixels, and its glow
 * around when lit, over what is under *)
let lit_at (x : int) (y : int) (cx : int) (cy : int) (light : int * int * int) (on : bool) (under : int * int * int) : int * int * int =
  let d = distance16 x y ((16 * cx) + 8) ((16 * cy) + 8) in
  if d <= 48 then (if on then mix light (255, 255, 255) (if d < 20 then 150 else 0) else mix (0, 0, 0) light 70)
  else if on && d < 150 then mix under light ((150 - d) * 150 / 102)
  else under

(* a key: its colour, rounded, lighter at its top edge and darker under,
 * as a thing one presses; its lamp at the top *)
let key (t : t) (machine : int) (step : int) (lamp : int) : Rgba_image.t =
  let group = if machine = 2 then (step / 4) mod 4 else 4 in
  kept t (Printf.sprintf "key %d %d" group lamp) (fun () ->
      let w = 26 and h = 40 in
      let base = if group < 4 then t.colors.keys808.(group) else t.colors.key909 in
      let light = if lamp = 2 then t.colors.playing else t.colors.lamp in
      image w h (fun x y ->
          let corner = (x < 2 || x >= w - 2) && (y < 2 || y >= h - 2) in
          if corner then (0, 0, 0, 0)
          else begin
            let c = shade base (12 - (30 * y / h) + ((noise x y 5 - 128) / 40)) in
            let c = if y < 2 then shade c 40 else if y >= h - 4 then shade c (-60) else if x < 1 then shade c 20 else if x >= w - 1 then shade c (-30) else c in
            opaque (lit_at x y (w / 2) 7 light (lamp > 0) c)
          end))

(* a 303's step: a window in the panel, dark, deeper at its top; the
 * step playing glows *)
let cell (t : t) (playing : bool) : Rgba_image.t =
  kept t (if playing then "cell on" else "cell off") (fun () ->
      let w = 26 and h = 40 in
      image w h (fun x y ->
          let inner = (20, 22, 24) in
          let c = if playing then mix inner t.colors.playing 90 else inner in
          let c = shade c ((noise x y 9 - 128) / 50) in
          let c = if y < 3 then shade c (-14 + (4 * y)) else if y >= h - 1 || x >= w - 1 then shade c 40 else if x < 1 then shade c (-10) else c in
          opaque c))

(* a switch: a slot, a lever up when on, its lamp over it *)
let switch (t : t) (on : bool) : Rgba_image.t =
  kept t (if on then "switch on" else "switch off") (fun () ->
      let w = 22 and h = 44 in
      image w h (fun x y ->
          let slot = (26, 26, 30) in
          let lever_top = if on then 12 else 24 in
          let c =
            if y >= lever_top && y < lever_top + 16 && x >= 3 && x < w - 3 then begin
              let c = shade (176, 178, 184) (14 - (2 * (y - lever_top))) in
              if y = lever_top then shade c 40 else if y = lever_top + 15 then shade c (-50) else c
            end
            else if y >= 10 && y < h - 2 && x >= 2 && x < w - 2 then shade slot (if y < 13 then -12 else 0)
            else (0, 0, 0) in
          if (y >= 10 && y < h - 2 && x >= 2 && x < w - 2) || y < 10 then begin
            if y < 10 then begin
              let (r, g, b) = lit_at x y (w / 2) 4 t.colors.lamp on (0, 0, 0) in
              (r, g, b, if (r, g, b) = (0, 0, 0) then 0 else 255)
            end
            else opaque c
          end
          else (0, 0, 0, 90)))

(* a button: a cap raised from the panel *)
let button (t : t) (w : int) (h : int) : Rgba_image.t =
  kept t (Printf.sprintf "button %d %d" w h) (fun () ->
      image w h (fun x y ->
          let corner = (x < 2 || x >= w - 2) && (y < 2 || y >= h - 2) in
          if corner then (0, 0, 0, 0)
          else begin
            let c = shade t.colors.cap (10 - (22 * y / h) + ((noise x y 3 - 128) / 40)) in
            opaque (if y < 2 then shade c 34 else if y >= h - 3 then shade c (-56) else if x < 1 then shade c 16 else if x >= w - 1 then shade c (-30) else c)
          end))

(* a display's window: black glass sunk in the panel, a faint shine
 * across its top *)
let window (t : t) (w : int) (h : int) : Rgba_image.t =
  kept t (Printf.sprintf "window %d %d" w h) (fun () ->
      image w h (fun x y ->
          let c = (10, 12, 12) in
          let c = if y < 2 || x < 2 then (0, 0, 0) else if y >= h - 2 || x >= w - 2 then (70, 72, 76) else c in
          let shine = if y >= 2 && y < h / 3 && x >= 2 && x < w - 2 then 10 - (30 * y / h) else 0 in
          opaque (shade c (max 0 shine))))

(* a rack's rail, [h] high: dark steel, a screw near each end *)
let rail (t : t) (h : int) : Rgba_image.t =
  kept t (Printf.sprintf "rail %d" h) (fun () ->
      let w = 22 in
      image w h (fun x y ->
          let c = brushed (46, 46, 52) 77 y x w in
          let c = bevel w h x y c in
          let screw (cy : int) (c : int * int * int) : int * int * int =
            let d = distance16 x y ((16 * (w / 2)) + 8) ((16 * cy) + 8) in
            if d > 88 then c
            else begin
              let dx = x - (w / 2) and dy = y - cy in
              (* a slot across it, lit from the top left *)
              if dy = dx / 3 || dy = (dx / 3) + 1 then (40, 40, 44) else shade (164, 166, 172) (((-dx - dy) * 7) + ((noise x y 4 - 128) / 30))
            end in
          opaque (screw 12 (screw (h - 13) c))))
