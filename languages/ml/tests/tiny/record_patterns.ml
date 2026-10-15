(* record patterns and punning: { view; update; n = m } as a value and
 * as a pattern, in a let, a function's parameter and a match; some
 * fields left out with _; nested, with constants that can fail, with
 * an alias; two records sharing a label, told apart by an annotation *)
type app = { view : int -> string; update : int -> int; name : string }
type point = { x : int; y : int }
type seg = { a : point; b : point; label : string }
type pixel = { x2 : int; color : int }
type tagged = { name : string; id : int }

let make name =
  let view n = name ^ "=" ^ string_of_int n in
  let update n = n + 1 in
  { view; update; name }

let run { view; update; name = _ } n = view (update (update n))

let describe p =
  match p with
  | { x = 0; y = 0 } -> "origin"
  | { x = 0; _ } -> "on the y axis"
  | { y = 0; x } -> "on the x axis at " ^ string_of_int x
  | { x; y } -> string_of_int x ^ "," ^ string_of_int y

let length { a = { x = x1; y = y1 }; b = { x = x2; y = y2 }; _ } =
  abs (x2 - x1) + abs (y2 - y1)

let first_label = function
  | [] -> "none"
  | { label; _ } :: _ -> label

let id_of (t : tagged) = match t with { name = "root"; _ } -> 0 | { id; _ } -> id

let () =
  let app = make "count" in
  print_string (run app 1); print_newline ();
  let { view = v; name; _ } = app in
  print_string (v 7); print_char ' '; print_string name; print_newline ();
  List.iter (fun p -> print_string (describe p); print_newline ())
    [ { x = 0; y = 0 }; { x = 0; y = 5 }; { x = 3; y = 0 }; { x = 2; y = 4 } ];
  let s = { a = { x = 1; y = 2 }; b = { x = 4; y = 6 }; label = "s" } in
  print_int (length s); print_char ' '; print_string (first_label [ s ]); print_newline ();
  (match s with { a = { x = 1; _ } as p; _ } -> print_int p.y | _ -> print_int (-1));
  print_newline ();
  let { x2; color } = { x2 = 9; color = 255 } in
  print_int (x2 + color); print_newline ();
  print_int (id_of { name = "root"; id = 7 }); print_char ' ';
  print_int (id_of { name = "sh"; id = 7 }); print_newline ()
