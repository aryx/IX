(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Draw.mli *)

open Display

(* 'd': dst, src, mask (their numbers), dst's rectangle, src's point, mask's *)
let draw_mask (dst : image) r (src : image) sp (mask : image) mp =
  message dst.display (fun b ->
    char b 'd';
    long b dst.id; long b src.id; long b mask.id;
    rect b r; point b sp; point b mp)

(* (no mask is an opaque one) *)
let draw (dst : image) r src mask p =
  draw_mask dst r src p (match mask with Some m -> m | None -> opaque dst.display) p

let fill dst r src = draw dst r src None Point.zero

let border dst (r : Rectangle.t) n src =
  fill dst (Rectangle.v r.min.x r.min.y r.max.x (r.min.y + n)) src;
  fill dst (Rectangle.v r.min.x (r.max.y - n) r.max.x r.max.y) src;
  fill dst (Rectangle.v r.min.x (r.min.y + n) (r.min.x + n) (r.max.y - n)) src;
  fill dst (Rectangle.v (r.max.x - n) (r.min.y + n) r.max.x (r.max.y - n)) src

(* 'L': dst, the two points, how each end is (0: square), the
 * thickness, src and its point *)
let line (dst : image) p0 p1 thick (src : image) =
  message dst.display (fun b ->
    char b 'L';
    long b dst.id; point b p0; point b p1; long b 0; long b 0; long b thick; long b src.id; point b Point.zero)

(* a coordinate of a polygon's point, as the device reads them: what it
 * is more than the one before, in a byte, when that is small (-64 to
 * 63); else itself in three (libdraw's addcoord) *)
let coord b old v =
  let d = v - old in
  if d >= -0x40 && d <= 0x3f then byte b (d land 0x7f)
  else begin byte b (0x80 lor (v land 0x7f)); byte b (v asr 7); byte b (v asr 15) end

(* 'p' and 'P': dst, the points less one, two words (the ends' shapes;
 * for a filled one the rule: all ones, a point is inside when the edges
 * round it do not cancel out), the thickness, src and its point, the
 * points *)
let polygon letter (dst : image) (points : Point.t list) e0 thick (src : image) =
  match points with
  | [] -> ()
  | _ ->
      message dst.display (fun b ->
        char b letter;
        long b dst.id; byte b (List.length points - 1); byte b ((List.length points - 1) asr 8);
        long b e0; long b 0; long b thick; long b src.id; point b Point.zero;
        ignore (List.fold_left (fun ((ox, oy) : int * int) (p : Point.t) -> coord b ox p.x; coord b oy p.y; (p.x, p.y)) (0, 0) points))

let poly dst points thick src = polygon 'p' dst points 0 thick src
let fillpoly dst points src = polygon 'P' dst points (-1) 0 src

(* 'e' and 'E': dst, src, the centre, the two half axes, the thickness,
 * src's point, and an arc's two angles (none: the whole) *)
let ellipse_ letter (dst : image) (c : Point.t) a b_ thick (src : image) =
  message dst.display (fun b ->
    char b letter;
    long b dst.id; long b src.id; point b c; long b a; long b b_; long b thick; point b Point.zero; long b 0; long b 0)

let ellipse dst c a b thick src = ellipse_ 'e' dst c a b thick src
let fillellipse dst c a b src = ellipse_ 'E' dst c a b 0 src

