(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Drawing.mli *)
module P = TinyLibPlayground
open Model

(*****************************************************************************)
(* The drawing *)
(*****************************************************************************)

(* A drawing's data is a line a shape, at its place in the drawing's
 * box:
 *
 *     box 10 10 80 30 cpu
 *     arrow 90 25 160 60
 *     text 20 70 a note
 *     oval 170 50 60 30 io
 *
 * a box and its label; an arrow, from its first point to its second,
 * where its head is (two of the playground's polygons); words; an oval, the ellipse in its box, and its label. pic's idea
 * (Brian Kernighan, 1982: a picture as lines of text), drawn with the
 * mouse. *)

let tools = [ "box"; "arrow"; "text"; "oval" ]

(* a drawing's shapes: their kind, their numbers, their label *)
let figures (data : string) : (string * int list * string) list =
  data
  |> String.split_on_char '\n'
  |> List.concat_map (fun l ->
    match String.split_on_char ' ' l with
    | kind :: rest when List.mem kind tools ->
        let rec take k l =
          if k = 0 then [], l
          else (let v, r =
                  match l with
                  | v :: r ->
                    (match int_of_string_opt v with
                     | Some i -> i
                     | None -> 0), r
                  | [] -> 0, [] in
                let nums, words = take (k - 1) r in v :: nums, words) in
        let nums, words = take (if kind = "text" then 2 else 4) rest in
        [ kind, nums, String.concat " " words ]
    | _ -> [])

let figure_line ((kind, nums, label) : string * int list * string) : string =
  String.concat ""
    (kind :: List.map (fun n -> " " ^ string_of_int n) nums
     @ (if label = "" then [ "\n" ] else [ " "; label; "\n" ]))

(* a box's or an oval's label, in the middle of its box at (x, y), cut
 * to what fits in its width *)
let centred (colour : int) (x : int) (y : int) (w : int) (h : int)
    (label : string) : P.shape =
  let label =
    if 8 * String.length label > w - 4 then
      String.sub label 0 (max 0 ((w - 4) / 8))
    else label in
  P.Move (x + ((w - (8 * String.length label)) / 2), y + ((h - 16) / 2),
          P.Words (colour, label))

(* the whole part of n's square root, by Newton's steps down from r,
 * which is at least it *)
let rec root n r =
  let s = (r + (n / r)) / 2 in
  if s >= r then r else root n s

(* An arrow's line, a pixel thick: the polygon between the line and
 * the same line a pixel lower when it goes more across than down (a
 * pixel in each column, as Bresenham's line), a pixel to the right
 * otherwise. *)
let arrow_line (x0 : int) (y0 : int) (x1 : int) (y1 : int) : (int * int) list =
  if abs (x1 - x0) >= abs (y1 - y0) then
    [ x0, y0; x1, y1; x1, y1 + 1; x0, y0 + 1 ]
  else [ x0, y0; x1, y1; x1 + 1, y1; x0 + 1, y0 ]

(* its head: the tip at the arrow's end, the two other corners 8
 * pixels back along it and 4 on each side *)
let arrow_head (x0 : int) (y0 : int) (x1 : int) (y1 : int) : (int * int) list =
  let dx = x1 - x0 and dy = y1 - y0 in
  let far = abs dx + abs dy in
  let len = if far = 0 then 1 else root ((dx * dx) + (dy * dy)) far in
  (* k d / len, to the nearest *)
  let along k d =
    let n = 2 * k * abs d in
    (if d < 0 then -1 else 1) * ((n + len) / (2 * len)) in
  let bx = x1 - along 8 dx and by = y1 - along 8 dy
  and sx = along 4 dy and sy = along 4 dx in
  [ x1, y1; bx - sx, by + sy; bx + sx, by - sy ]

(* a shape drawn, the box's corner at (ox, oy) *)
let figure_shapes (ox : int) (oy : int) (colour : int)
    ((kind, nums, label) : string * int list * string) : P.shape list =
  match kind, nums with
  | "box", [ x; y; w; h ] ->
      let x = ox + x and y = oy + y in
      [ P.Move (x, y, P.Rect (colour, w, 1));
        P.Move (x, y + h - 1, P.Rect (colour, w, 1));
        P.Move (x, y, P.Rect (colour, 1, h));
        P.Move (x + w - 1, y, P.Rect (colour, 1, h));
        centred colour x y w h label ]
  | "oval", [ x; y; w; h ] ->
      let x = ox + x and y = oy + y in
      [ P.Move (x, y, P.Ellipse (colour, w, h)); centred colour x y w h label ]
  | "arrow", [ x0; y0; x1; y1 ] ->
      [ P.Move (ox, oy, P.Polygon (colour, arrow_line x0 y0 x1 y1));
        P.Move (ox, oy, P.Polygon (colour, arrow_head x0 y0 x1 y1)) ]
  | "text", [ x; y ] -> [ P.Move (ox + x, oy + y, P.Words (colour, label)) ]
  | _ -> []

(* what a stroke of a tool makes, from (x0, y0) to (x1, y1) *)
let stroked (tool : int) (x0 : int) (y0 : int) (x1 : int) (y1 : int)
    : string * int list * string =
  let around = [ min x0 x1; min y0 y1; abs (x1 - x0); abs (y1 - y0) ] in
  if tool = 0 then "box", around, ""
  else if tool = 1 then "arrow", [ x0; y0; x1; y1 ], ""
  else if tool = 2 then "text", [ x1; y1 ], ""
  else "oval", around, ""

(* the shape a stroke made, added; a box, an oval or an arrow too small
 * is a click, not a shape *)
let draw_stroke (o : office) (tool : int)
    ((x0, y0, x1, y1) : int * int * int * int) =
  let b = selected_box o in
  if tool = 2
     || ((tool = 0 || tool = 3) && abs (x1 - x0) >= 8 && abs (y1 - y0) >= 8)
     || (tool = 1 && abs (x1 - x0) + abs (y1 - y0) >= 8) then
    change o (b.data ^ figure_line (stroked tool x0 y0 x1 y1))

(* A key in a drawing: Tab another tool; a character the last shape's
 * label longer; Backspace shorter, and an empty label's shape removed;
 * C-g the drawing left *)
let sketch_key (o : office) (tool : int) (k : P.key) =
  let b = selected_box o in
  let figs = figures b.data in
  let relabel f = match List.rev figs with
    | (kind, nums, label) :: rest ->
      change o
        (String.concat ""
           (List.map figure_line (List.rev rest @ f kind nums label)))
    | [] -> () in
  match k with
  | P.Char '\t' -> o.editing <- Sketch ((tool + 1) mod List.length tools, None)
  | P.Char c when c >= ' ' && c < '\127' ->
      relabel (fun kind nums label -> [ kind, nums, label ^ String.make 1 c ])
  | P.Backspace ->
      relabel (fun kind nums label ->
        if label = "" then []
        else [ kind, nums, String.sub label 0 (String.length label - 1) ])
  | P.Ctrl 'g' -> o.editing <- Nothing
  | _ -> o.message <- "a drawing: Tab, the mouse, a label typed; C-g"


(* A drawing: its shapes, and the stroke being made, in blue *)
let drawing_view (b : obj) (tool : int)
    (stroke : (int * int * int * int) option) : P.shape list =
  List.concat_map (figure_shapes b.x b.y black) (figures b.data)
  @ (match stroke with
     | Some (x0, y0, x1, y1) ->
       figure_shapes b.x b.y blue (stroked tool x0 y0 x1 y1)
     | None -> [])
