(* records: a class of fields, made in their order; read, set when
   mutable, copied by with, matched by their fields *)
type point = { x : int; y : int }
type account = { owner : string; mutable balance : int }

let move p dx = { p with x = p.x + dx }

let show p = print_string "("; print_int p.x; print_string ", "; print_int p.y; print_string ")"

let quadrant p =
  match p with
  | { x = 0; y = 0 } -> "origin"
  | { x; y } when x > 0 && y > 0 -> "first"
  | { x = _; y } -> if y < 0 then "below" else "elsewhere"

let deposit a n = a.balance <- a.balance + n

let () =
  let p = { y = 2; x = 1 } in
  show p; print_string " "; show (move p 10); print_newline ();
  print_endline (quadrant { x = 0; y = 0 } ^ " " ^ quadrant p ^ " " ^ quadrant { x = -1; y = -1 } ^ " " ^ quadrant { x = -1; y = 3 });
  let a = { owner = "ada"; balance = 10 } in
  deposit a 5;
  deposit a 27;
  print_endline (a.owner ^ " has " ^ string_of_int a.balance)
