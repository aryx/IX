(* min and max inlined (Lower's min_max) on ints and floats, against
 * a polymorphic call's answers: the order of ties, -0., nan, and the
 * arguments' effects in OCaml's order (the last first) *)

let poly_min a b = min a b
let poly_max a b = max a b

let () =
  let is = [ 0; 1; -1; 1_000_000; -1_000_000 ] in
  List.iter (fun (a : int) -> List.iter (fun (b : int) ->
    Printf.printf "%d %d %b %b %d %d\n" (min a b) (max a b) (min a b = poly_min a b) (max a b = poly_max a b)
      (Int.min a b) (Int.max a b)) is) is;
  let fs = [ 0.; -0.; 1.5; -2.; infinity; nan ] in
  List.iter (fun (a : float) -> List.iter (fun (b : float) ->
    Printf.printf "%h %h %h %h\n" (min a b) (max a b) (poly_min a b) (poly_max a b)) fs) fs;
  let trace = ref [] in
  let f (x : int) = trace := x :: !trace; x in
  ignore (min (f 1) (f 2) + max (f 3) (f 4));
  List.iter (fun x -> print_int x; print_char ' ') (List.rev !trace); print_newline ()
