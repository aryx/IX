(* variants: constant constructors and constructors of arguments, a
   recursive type, a match's cases tried in order, guards, or-patterns,
   constants and ranges as patterns, a function of several cases *)
type shape = Circle of int | Rect of int * int | Square of int | Empty

let area s =
  match s with
  | Circle r -> 3 * r * r
  | Rect (w, h) -> w * h
  | Square n -> n * n
  | Empty -> 0

let describe = function
  | Empty -> "nothing"
  | Circle r when r > 10 -> "a big circle"
  | Circle _ -> "a circle"
  | Rect _ | Square _ -> "a polygon"

type tree = Leaf | Node of tree * int * tree

let rec insert t x =
  match t with
  | Leaf -> Node (Leaf, x, Leaf)
  | Node (l, y, r) -> if x < y then Node (insert l x, y, r) else Node (l, y, insert r x)

let rec walk t =
  match t with
  | Leaf -> ()
  | Node (l, x, r) -> walk l; print_int x; print_char ' '; walk r

let rec sum t = match t with Leaf -> 0 | Node (l, x, r) -> sum l + x + sum r

let kind c =
  match c with
  | 'a' .. 'z' -> "lower"
  | 'A' .. 'Z' -> "upper"
  | '0' .. '9' -> "digit"
  | _ -> "other"

let name n = match n with 0 -> "zero" | 1 -> "one" | _ -> "many"

let greeting s = match s with "hi" | "hello" -> "a greeting" | _ -> "something else"

let () =
  print_int (area (Circle 2) + area (Rect (3, 4)) + area (Square 5) + area Empty);
  print_newline ();
  print_endline (describe (Circle 11) ^ ", " ^ describe (Circle 1) ^ ", " ^ describe (Square 2) ^ ", " ^ describe Empty);
  let t = insert (insert (insert (insert (insert Leaf 5) 2) 8) 1) 9 in
  walk t;
  print_newline ();
  print_int (sum t);
  print_newline ();
  print_endline (kind 'q' ^ " " ^ kind 'Q' ^ " " ^ kind '7' ^ " " ^ kind '!');
  print_endline (name 0 ^ " " ^ name 1 ^ " " ^ name 5);
  print_endline (greeting "hello" ^ ", " ^ greeting "bye")
