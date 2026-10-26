(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeDrawing.mli *)
open TinyLibPlayground
open TinyOfficeModel

(*****************************************************************************)
(* The drawing *)
(*****************************************************************************)

(* A drawing's data is a line a shape, at its place in the drawing's
 * box:
 *
 *     box 10 10 80 30 cpu
 *     arrow 90 25 160 60
 *     text 20 70 a note
 *
 * a box and its label; an arrow, across then up or down (a block
 * diagram's connector: what the shapes draw is rectangles, and a
 * slanted line would need another kind); words. pic's idea (Brian
 * Kernighan, 1982: a picture as lines of text), drawn with the mouse. *)

let tools = [ "box"; "arrow"; "text" ]

(* a drawing's shapes: their kind, their numbers, their label *)
let figures (data : string) : (string * int list * string) list =
  List.concat_map (fun l ->
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
    | _ -> []) (String.split_on_char '\n' data)

let figure_line ((kind, nums, label) : string * int list * string) : string =
  String.concat ""
    (kind :: List.map (fun n -> " " ^ string_of_int n) nums
     @ (if label = "" then [ "\n" ] else [ " "; label; "\n" ]))

(* a shape drawn, the box's corner at (ox, oy); an arrow's head is
 * rectangles narrowing to its end, along its last stretch *)
let figure_shapes (ox : int) (oy : int) (colour : int)
    ((kind, nums, label) : string * int list * string) : shape list =
  match kind, nums with
  | "box", [ x; y; w; h ] ->
      let x = ox + x and y = oy + y in
      let label =
        if 8 * String.length label > w - 4 then
          String.sub label 0 (max 0 ((w - 4) / 8))
        else label in
      [ Move (x, y, Rect (colour, w, 1)); Move (x, y + h - 1, Rect (colour, w, 1));
        Move (x, y, Rect (colour, 1, h));
        Move (x + w - 1, y, Rect (colour, 1, h));
        Move (x + ((w - (8 * String.length label)) / 2), y + ((h - 16) / 2),
              Words (colour, label)) ]
  | "arrow", [ x0; y0; x1; y1 ] ->
      let x0 = ox + x0 and y0 = oy + y0 and x1 = ox + x1 and y1 = oy + y1 in
      let head = List.init 4 (fun k ->
        if y1 > y0 then Move (x1 - k, y1 - k, Rect (colour, (2 * k) + 1, 1))
        else if y1 < y0 then
          Move (x1 - k, y1 + k, Rect (colour, (2 * k) + 1, 1))
        else if x1 >= x0 then
          Move (x1 - k, y0 - k, Rect (colour, 1, (2 * k) + 1))
        else Move (x1 + k, y0 - k, Rect (colour, 1, (2 * k) + 1))) in
      [ Move (min x0 x1, y0, Rect (colour, abs (x1 - x0) + 1, 1));
        Move (x1, min y0 y1, Rect (colour, 1, abs (y1 - y0) + 1)) ] @ head
  | "text", [ x; y ] -> [ Move (ox + x, oy + y, Words (colour, label)) ]
  | _ -> []

(* what a stroke of a tool makes, from (x0, y0) to (x1, y1) *)
let stroked (tool : int) (x0 : int) (y0 : int) (x1 : int) (y1 : int)
    : string * int list * string =
  if tool = 0 then
    "box", [ min x0 x1; min y0 y1; abs (x1 - x0); abs (y1 - y0) ], ""
  else if tool = 1 then "arrow", [ x0; y0; x1; y1 ], ""
  else "text", [ x1; y1 ], ""

(* the shape a stroke made, added; a box or an arrow too small is a
 * click, not a shape *)
let draw_stroke (o : office) (tool : int)
    ((x0, y0, x1, y1) : int * int * int * int) =
  let b = List.nth o.page o.sel in
  if tool = 2 || (tool = 0 && abs (x1 - x0) >= 8 && abs (y1 - y0) >= 8)
     || (tool = 1 && abs (x1 - x0) + abs (y1 - y0) >= 8) then
    change o (b.data ^ figure_line (stroked tool x0 y0 x1 y1))

(* A key in a drawing: Tab another tool; a character the last shape's
 * label longer; Backspace shorter, and an empty label's shape removed;
 * C-g the drawing left *)
let sketch_key (o : office) (tool : int) (k : int) =
  let b = List.nth o.page o.sel in
  let figs = figures b.data in
  let relabel f = match List.rev figs with
    | (kind, nums, label) :: rest ->
      change o
        (String.concat ""
           (List.map figure_line (List.rev rest @ f kind nums label)))
    | [] -> () in
  if k = 9 then o.editing <- Sketch ((tool + 1) mod 3, None)
  else if k >= 32 && k < 127 then
    relabel (fun kind nums label ->
      [ kind, nums, label ^ String.make 1 (Char.chr k) ])
  else if k = 8 || k = 127 then
    relabel (fun kind nums label ->
      if label = "" then []
      else [ kind, nums, String.sub label 0 (String.length label - 1) ])
  else if k = 7 then o.editing <- Nothing
  else o.message <- "a drawing: Tab, the mouse, a label typed; C-g"


(* A drawing: its shapes, and the stroke being made, in blue *)
let drawing_view (b : obj) (tool : int)
    (stroke : (int * int * int * int) option) : shape list =
  List.concat_map (figure_shapes b.x b.y black) (figures b.data)
  @ (match stroke with
     | Some (x0, y0, x1, y1) ->
       figure_shapes b.x b.y blue (stroked tool x0 y0 x1 y1)
     | None -> [])
