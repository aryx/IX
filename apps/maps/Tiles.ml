(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiles.mli *)

let size : int = 256
let max_zoom : int = 19

type key = { z : int; x : int; y : int }
type placed = { key : key; left : int; top : int }

let name (k : key) : string = Printf.sprintf "%d/%d/%d" k.z k.x k.y
let url (base : string) (k : key) : string = Printf.sprintf "%s/%s.png" base (name k)

(* (division and remainder rounding down: left of the world is negative) *)
let floor_div (a : int) (b : int) : int = if a >= 0 then a / b else -((b - 1 - a) / b)
let wrap (a : int) (n : int) : int = a - (floor_div a n * n)

let in_view (z : int) (cx : int) (cy : int) (w : int) (h : int) : placed list =
  let left = cx - (w / 2) and top = cy - (h / 2) in
  let n = 1 lsl z in
  let x0 = floor_div left size and x1 = floor_div (left + w - 1) size in
  let y0 = max 0 (floor_div top size) and y1 = min (n - 1) (floor_div (top + h - 1) size) in
  let rec cols (x : int) (acc : placed list) : placed list =
    if x > x1 then acc
    else
      let rec rows (y : int) (acc : placed list) : placed list =
        if y > y1 then acc
        else
          rows (y + 1)
            ({ key = { z; x = wrap x n; y }; left = (x * size) - left; top = (y * size) - top } :: acc)
      in
      cols (x + 1) (rows y0 acc)
  in
  (* the distance of a tile's centre from the window's, squared *)
  let far (p : placed) : int =
    let dx = p.left + (size / 2) - (w / 2) and dy = p.top + (size / 2) - (h / 2) in
    (dx * dx) + (dy * dy)
  in
  List.stable_sort (fun (a : placed) (b : placed) -> compare (far a) (far b)) (cols x0 [])

let rezoomed ~(dz : int) ~(px : int) ~(py : int) (cx : int) (cy : int) : int * int =
  let moved (c : int) (p : int) : int =
    let world = c + p in
    (if dz >= 0 then world lsl dz else floor_div world (1 lsl -dz)) - p
  in
  (moved cx px, moved cy py)

let centred (z : int) (cx : int) (cy : int) (h : int) : int * int =
  let world = size lsl z in
  let cy = if world <= h then world / 2 else max (h / 2) (min (world - (h - (h / 2))) cy) in
  (wrap cx world, cy)

let ancestor (k : key) (n : int) : key = { z = k.z - n; x = k.x lsr n; y = k.y lsr n }

let enlarged (parent : Rgba_image.t) (k : key) (n : int) : Rgba_image.t =
  let img = Rgba_image.create ~width:size ~height:size in
  let cell = 1 lsl n in
  let from_x = (k.x land (cell - 1)) * (size / cell) and from_y = (k.y land (cell - 1)) * (size / cell) in
  for y = 0 to size - 1 do
    let row = 4 * size * (from_y + (y / cell)) in
    for x = 0 to size - 1 do
      Bytes.blit parent.rgba (row + (4 * (from_x + (x / cell)))) img.rgba (4 * ((y * size) + x)) 4
    done
  done;
  img
