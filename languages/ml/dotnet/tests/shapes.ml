(* a unit that C# uses (interop.cs): its record and variant are classes,
   its functions static methods, nothing converted between the two *)
type point = { x : int; y : int }
type shape = Circle of point * int | Rect of point * point

let area s =
  match s with
  | Circle (_, r) -> 3 * r * r
  | Rect (a, b) -> (b.x - a.x) * (b.y - a.y)

let translate p dx dy = { x = p.x + dx; y = p.y + dy }

let describe s = match s with Circle _ -> "a circle" | Rect _ -> "a rectangle"

(* functions given and returned: C#'s lambdas, ML's Funcs. (let f k =
   fun n -> ... is ML's f k n, a method of two arguments, as F#'s; a
   function made after a let is returned as one) *)
let map_area (f : int -> int) s = f (area s)
let scale k = let factor = k in fun n -> n * factor
