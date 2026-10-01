(* another unit's functions, their labels from its .mli *)

let () =
  print_int (Geo.area ~h:2 ~w:1); print_newline ();
  print_int (Geo.scale ~by:3 14); print_newline ();
  print_string (String.concat " " (List.map (fun size -> Geo.describe ~size ~name:"s") [ 1; 2 ])); print_newline ();
  print_int (Geo.(area ~h:5 ~w:(scale 2 ~by:2))); print_newline ()
