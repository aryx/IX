(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Memshape.mli *)

type drawfn = Memimage.t -> Memimage.rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* (a source, its point and the operator go together, an ink: mini-ml's
 * functions have 7 parameters at most on arm, and these had up to 11) *)
type ink = Memimage.t * (int * int) * int

(* a run of pixels [x0, x1) of row y, from src as sp is to (rx, ry) *)
let span (draw : drawfn) dst (rx, ry) (src, (sx, sy), op) (x0, x1, y) =
  if x0 < x1 then draw dst (x0, y, x1, y + 1) src (sx + x0 - rx, sy + y - ry) Memlayer.opaque (0, 0) op

(* A shape's runs, drawn: [body] is given what to do with each one.
 * Written directly when the colour and the image allow it
 * (Memdraw.solid: a game's polygons and the strokes of its words, a
 * run each row or each pixel, were a draw each); else each a draw.
 * [box]: all the shape may cover, for the screen. *)
let runs (draw : drawfn) dst ref_ ink box body =
  let (src, _, op) = ink in
  match Memdraw.solid dst src op with
  | Some put ->
      Memdraw.solid_start dst box;
      body (fun (x0, x1, y) -> if x0 < x1 then put x0 x1 y);
      Memdraw.solid_done dst box
  | None -> body (span draw dst ref_ ink)

(* scanline fill: each row's crossings (at pixel centres), paired by
 * the rule *)
let fillpoly draw dst pts wind src sp op =
  let ink = (src, sp, op) in
  match pts with
  | [] -> ()
  | first :: _ ->
      let edges =
        let rec pairs = function a :: (b :: _ as rest) -> (a, b) :: pairs rest | [ a ] -> [ (a, first) ] | [] -> [] in
        pairs pts in
      let ys = List.map snd pts and xs_ = List.map fst pts in
      let ymin = List.fold_left min max_int ys and ymax = List.fold_left max min_int ys in
      let xmin = List.fold_left min max_int xs_ and xmax = List.fold_left max min_int xs_ in
      (* OPTIMIZATION: the edges that cross a row are kept from row to
       * row (those that start at each row found once; one is let go at
       * its last), and the crossings sorted by comparing their
       * numbers. A turned rectangle has 2 of its 4 edges on a row, a
       * circle given as a polygon 2 of its 60; and a row was every
       * edge looked at, a tuple each, then List.sort compare, the
       * runtime's comparison of any two values. A game's board is
       * fifty polygons a frame (docs/plans/plan_playground_speed.md).
       * old (the same crossings, in the same order):
       *   let xs = List.fold_left (fun acc ((x0, y0), (x1, y1)) ->
       *     if y0 = y1 then acc
       *     else begin
       *       let (x0, y0, x1, y1, dir) = if y0 < y1 then (x0, y0, x1, y1, 1) else (x1, y1, x0, y0, -1) in
       *       if y >= y0 && y < y1 then (crossing, dir) :: acc else acc
       *     end) [] edges in
       *   let xs = List.sort compare xs in *)
      let rows = ymax - ymin in
      let starts = Array.make (rows + 1) [] in
      List.iter (fun ((x0, y0), (x1, y1)) ->
        if y0 <> y1 then begin
          let ((_, ya, _, _, _) as e) = if y0 < y1 then (x0, y0, x1, y1, 1) else (x1, y1, x0, y0, -1) in
          starts.(ya - ymin) <- e :: starts.(ya - ymin)
        end) edges;
      let before ((x : int), (d : int)) ((x' : int), (d' : int)) = if x < x' then -1 else if x > x' then 1 else if d < d' then -1 else if d > d' then 1 else 0 in
      let active = ref [] in
      runs draw dst first ink (xmin, ymin, xmax + 1, ymax + 1) (fun put ->
      for y = ymin to ymax - 1 do
        (match starts.(y - ymin) with [] -> () | l -> active := l @ !active);
        if List.exists (fun (_, _, _, (y1 : int), _) -> y >= y1) !active then
          active := List.filter (fun (_, _, _, (y1 : int), _) -> y < y1) !active;
        (* the crossings of y + 1/2: x, direction *)
        let xs = List.map (fun (x0, y0, x1, y1, dir) ->
          ((((2 * y) + 1 - (2 * y0)) * (x1 - x0) + ((y1 - y0) * ((2 * x0) + 1))) / (2 * (y1 - y0)), dir)) !active in
        let xs = match xs with
          | [ a; b ] -> if before a b <= 0 then xs else [ b; a ]
          | _ -> List.sort before xs in
        let rec pairs w inside = function
          | (x, dir) :: ((x', _) :: _ as rest) ->
              let w = w + dir in
              let inside' = if wind = -1 then w <> 0 else w land 1 = 1 in
              if inside' then put (x, x', y);
              pairs w inside' rest
          | _ -> () in
        ignore (pairs 0 false xs)
      done)

let round f = int_of_float (if f < 0.0 then f -. 0.5 else f +. 0.5)

(* a pixel's disc (Enddisc's), filled *)
let disc draw dst (cx, cy) r ink ref_ =
  runs draw dst ref_ ink (cx - r, cy - r, cx + r + 1, cy + r + 1) (fun put ->
  for dy = - r to r do
    let dx = round (sqrt (float_of_int ((r * r) - (dy * dy)))) in
    put (cx - dx, cx + dx + 1, cy + dy)
  done)

let line draw dst (x0, y0) (x1, y1) (end0, end1, radius) ink =
  if radius = 0 then begin
    (* Bresenham: each pixel a run of one *)
    let dx = abs (x1 - x0) and dy = - (abs (y1 - y0)) in
    let sx = if x0 < x1 then 1 else -1 and sy = if y0 < y1 then 1 else -1 in
    runs draw dst (x0, y0) ink (min x0 x1, min y0 y1, max x0 x1 + 1, max y0 y1 + 1) (fun put ->
    let rec go x y err =
      put (x, x + 1, y);
      if x <> x1 || y <> y1 then begin
        let e2 = 2 * err in
        let x, err = if e2 >= dy then x + sx, err + dy else x, err in
        let y, err = if e2 <= dx then y + sy, err + dx else y, err in
        go x y err
      end in
    go x0 y0 (dx + dy))
  end else begin
    (* the segment's rectangle, 1+2*radius wide, filled *)
    let (src, sp, op) = ink in
    let fx = float_of_int (x1 - x0) and fy = float_of_int (y1 - y0) in
    let len = sqrt ((fx *. fx) +. (fy *. fy)) in
    let w = float_of_int radius +. 0.5 in
    let nx = if len = 0.0 then 0 else round (-. fy *. w /. len) and ny = if len = 0.0 then 0 else round (fx *. w /. len) in
    fillpoly draw dst [ (x0 + nx, y0 + ny); (x1 + nx, y1 + ny); (x1 - nx, y1 - ny); (x0 - nx, y0 - ny) ] 1 src
      (let (a, b) = sp in (a + nx, b + ny)) op;
    if end0 = 1 then disc draw dst (x0, y0) radius ink (x0, y0);
    if end1 = 1 then disc draw dst (x1, y1) radius ink (x0, y0)
  end

let poly draw dst pts (end0, end1, radius) (src, sp, op) =
  let rec go = function
    | a :: (b :: rest as more) ->
        let (ax, ay) = a and (px, py) = List.hd pts and (sx, sy) = sp in
        line draw dst a b ((if a == List.hd pts then end0 else 1), (if rest = [] then end1 else 1), radius)
          (src, (sx + ax - px, sy + ay - py), op);
        go more
    | _ -> () in
  go pts

(* the pixels (x, y) around c with inner <= (x/a)^2 + (y/b)^2 <= outer,
 * as runs of each row; [keep] which of them (an arc's angles) *)
let ring draw dst (cx, cy) (a, b, thick) ink keep =
  let fa = float_of_int a and fb = float_of_int b in
  let t = float_of_int (max thick 0) in
  let inside x y ra rb = ra > 0.0 && rb > 0.0 && ((x *. x) /. (ra *. ra)) +. ((y *. y) /. (rb *. rb)) <= 1.0 in
  let e = max thick 0 in
  runs draw dst (cx, cy) ink (cx - a - e, cy - b - e, cx + a + e + 2, cy + b + e + 1) (fun put ->
  for dy = - (b + max thick 0) to b + max thick 0 do
    let run = ref None in
    let flush_ x = match !run with Some x0 -> put (cx + x0, cx + x, cy + dy); run := None | None -> () in
    for dx = - (a + max thick 0) to a + max thick 0 + 1 do
      let x = float_of_int dx and y = float_of_int dy in
      let on =
        dx <= a + max thick 0 && keep dx dy
        && (if thick < 0 then inside x y (fa +. 0.5) (fb +. 0.5)
            else inside x y (fa +. t +. 0.5) (fb +. t +. 0.5) && not (inside x y (fa -. t -. 0.5) (fb -. t -. 0.5))) in
      if on then (if !run = None then run := Some dx) else flush_ dx
    done
  done)

let ellipse draw dst c abt ink = ring draw dst c abt ink (fun _ _ -> true)

let arc draw dst c abt ink (alpha, phi) =
  let norm d = let d = d mod 360 in if d < 0 then d + 360 else d in
  let from = norm alpha and span_ = if phi < 0 then - phi else phi in
  let start = if phi < 0 then norm (alpha + phi) else from in
  ring draw dst c abt ink (fun dx dy ->
    let deg = norm (round (atan2 (float_of_int (- dy)) (float_of_int dx) *. 180.0 /. 3.14159265358979)) in
    span_ >= 360 || norm (deg - start) <= span_)
