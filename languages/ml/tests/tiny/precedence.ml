(* a prefix operator binds tighter than a field: !r.x is (!r).x *)
type point = { mutable x : int; y : int }
let r = ref { x = 1; y = 2 }
let () =
  print_int !r.x; print_int !r.y;
  (!r).x <- 10;
  print_int (!r.x + !r.y);
  print_newline ()
