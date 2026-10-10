(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/fonts/Outline.ml; polygons' tolerance is said, where it was optional (Curve's 0.1) (docs/plans/plan_pdf.md) *)

(* See Outline.mli *)

type point = float * float
type segment = Line of point | Quadratic of point * point | Cubic of point * point * point
type contour = { start : point; segments : segment list }
type t = contour list

(* each contour as a polygon, its points put through [f] and its curves made lines *)
let polygons ~(tolerance : float) (f : point -> point) (o : t) : point list list =
  List.map
    (fun c ->
      let rec go (from : point) (segments : segment list) (acc : point list) : point list =
        match segments with
        | [] -> List.rev acc
        | Line p :: rest -> go p rest (f p :: acc)
        | Quadratic ((cx, cy), p) :: rest ->
            (* a quadratic curve as a cubic: its control point two thirds of the way *)
            let x0, y0 = from and x1, y1 = p in
            let c1 = (x0 +. (2. /. 3. *. (cx -. x0)), y0 +. (2. /. 3. *. (cy -. y0))) and c2 = (x1 +. (2. /. 3. *. (cx -. x1)), y1 +. (2. /. 3. *. (cy -. y1))) in
            go from (Cubic (c1, c2, p) :: rest) acc
        | Cubic (c1, c2, p) :: rest -> (
            match Curve.flatten ~tolerance (f from) (f c1) (f c2) (f p) with _ :: points -> go p rest (List.rev_append points acc) | [] -> go p rest acc)
      in
      go c.start c.segments [ f c.start ])
    o

let bounds (o : t) : (float * float * float * float) option =
  match List.concat (polygons ~tolerance:0.1 (fun p -> p) o) with
  | [] -> None
  | (x, y) :: rest -> Some (List.fold_left (fun (x0, y0, x1, y1) (x, y) -> (Float.min x0 x, Float.min y0 y, Float.max x1 x, Float.max y1 y)) (x, y, x, y) rest)

(* a pen: what a font's program draws with -- a move starts a contour,
 * lines and curves go on from where the pen is *)
type pen = { mutable x : float; mutable y : float; mutable current : (point * segment list) option; mutable finished : contour list }

let pen () : pen = { x = 0.; y = 0.; current = None; finished = [] }

let close (p : pen) : unit =
  (match p.current with Some (start, (_ :: _ as segments)) -> p.finished <- { start; segments = List.rev segments } :: p.finished | _ -> ());
  p.current <- None

let move (p : pen) (dx : float) (dy : float) : unit =
  close p;
  p.x <- p.x +. dx;
  p.y <- p.y +. dy

let add (p : pen) (s : segment) : unit =
  let start, segments = match p.current with Some c -> c | None -> ((p.x, p.y), []) in
  p.current <- Some (start, s :: segments);
  let x, y = match s with Line q | Quadratic (_, q) | Cubic (_, _, q) -> q in
  p.x <- x;
  p.y <- y

let line (p : pen) (dx : float) (dy : float) : unit =
  let from = (p.x, p.y) in
  if p.current = None then p.current <- Some (from, []);
  p.x <- p.x +. dx;
  p.y <- p.y +. dy;
  add p (Line (p.x, p.y))

(* a curve by three steps: to its two control points, to its end *)
let curve (p : pen) (dx1 : float) (dy1 : float) (dx2 : float) (dy2 : float) (dx3 : float) (dy3 : float) : unit =
  if p.current = None then p.current <- Some ((p.x, p.y), []);
  let c1 = (p.x +. dx1, p.y +. dy1) in
  let c2 = (fst c1 +. dx2, snd c1 +. dy2) in
  p.x <- fst c2 +. dx3;
  p.y <- snd c2 +. dy3;
  add p (Cubic (c1, c2, (p.x, p.y)))

let drawn (p : pen) : t =
  close p;
  List.rev p.finished
