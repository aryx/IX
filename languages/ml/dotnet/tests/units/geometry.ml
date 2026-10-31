(* a unit that the others use: its types, exception and functions are
   reached from them as Geometry's (the class Geometry, its nested
   classes) *)
type shape = Circle of int | Rect of int * int
type 'a tagged = { tag : string; item : 'a }

exception Degenerate of string

let area s =
  match s with
  | Circle r -> if r <= 0 then raise (Degenerate "circle") else 3 * r * r
  | Rect (w, h) -> if w <= 0 || h <= 0 then raise (Degenerate "rect") else w * h

let unit_square = Rect (1, 1)
let label s = { tag = (match s with Circle _ -> "circle" | Rect _ -> "rect"); item = s }

let () = print_endline "geometry: ready"
