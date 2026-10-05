(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Draw.mli *)

open Display

(* 'd': dst, src, mask (their numbers), dst's rectangle, src's point, mask's *)
let draw_mask (dst : image) r (src : image) sp (mask : image) mp =
  message dst.display (fun b ->
    Buffer.add_char b 'd';
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
    Buffer.add_char b 'L';
    long b dst.id; point b p0; point b p1; long b 0; long b 0; long b thick; long b src.id; point b Point.zero)
