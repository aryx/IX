(* the program: Geometry's and Counter's values, functions, types,
   constructors and exception, from another unit *)
let () =
  print_endline "main: starts";
  Counter.add (Geometry.Circle 2);
  Counter.add (Geometry.Rect (3, 4));
  Counter.add Geometry.unit_square;
  print_int !Counter.total;
  print_newline ();
  let t = Geometry.label (Geometry.Rect (2, 5)) in
  print_endline (t.Geometry.tag ^ " " ^ string_of_int (Geometry.area t.Geometry.item));
  (match t.Geometry.item with Geometry.Rect (w, _) -> print_int w | Geometry.Circle _ -> print_string "?");
  print_newline ();
  (try Counter.add (Geometry.Circle 0) with Geometry.Degenerate what -> print_endline ("degenerate " ^ what));
  print_int !Counter.total;
  print_newline ()
