(* inline records, C of { l : t; ... }: built and matched with braces,
 * the labels the constructor's (many share them); the record bound to
 * a name, its fields read and written, copied with a field changed *)

let line s = print_string s; print_newline ()
let show = string_of_int

(* the same labels in several constructors, and in a record *)
type point = { x : int; y : int }

type shape =
  | Dot
  | Circle of { x : int; y : int; r : int }
  | Rect of { x : int; y : int; w : int; h : int }
  | Counter of { mutable n : int; name : string }
  | Pair of shape * shape

type 'a boxed = Empty | Full of { value : 'a; tag : string }

let rec area = function
  | Dot -> 0
  | Circle { r; _ } -> 3 * r * r
  | Rect { w; h; _ } -> w * h
  | Counter c -> c.n
  | Pair (a, b) -> area a + area b

let where = function
  | Circle c -> show c.x ^ "," ^ show c.y
  | Rect { x; y = y'; _ } -> show x ^ "," ^ show y'
  | Dot | Counter _ | Pair _ -> "nowhere"

let moved dx = function
  | Circle c -> Circle { c with x = c.x + dx }
  | Rect r -> Rect { r with x = r.x + dx; w = r.w * 2 }
  | s -> s

let bump = function Counter c -> c.n <- c.n + 1 | _ -> ()

let () =
  let x = 1 and y = 2 in
  let p = { x; y } in
  let c = Circle { x = 10; y = 20; r = 2 } and r = Rect { h = 4; w = 3; y; x } in
  line (show (area c) ^ " " ^ show (area r) ^ " " ^ show (area (Pair (c, r))) ^ " " ^ show (p.x + p.y));
  line (where c ^ " " ^ where r ^ " " ^ where Dot);
  line (where (moved 5 c) ^ " " ^ where (moved 5 r) ^ " " ^ show (area (moved 5 r)));
  let k = Counter { n = 0; name = "k" } in
  bump k; bump k; bump c;
  line (show (area k) ^ (match k with Counter { name; n } -> " " ^ name ^ show n | _ -> ""));
  (* equal by their fields, as any value *)
  line (string_of_bool (c = Circle { r = 2; x = 10; y = 20 }) ^ " " ^ string_of_bool (c = moved 1 c));
  (match Full { value = 42; tag = "t" }, Full { value = "s"; tag = "u" }, Empty with
   | Full { value; tag }, Full b, Empty -> line (show value ^ tag ^ b.value ^ b.tag)
   | _ -> line "no")
