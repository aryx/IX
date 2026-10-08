(* floats compared, negated, converted: by the processor's instructions and by the runtime's calls, the same *)
let show (b : bool) : string = if b then "T" else "F"
let rel (x : float) (y : float) : string =
  show (x < y) ^ show (x <= y) ^ show (x > y) ^ show (x >= y) ^ show (x = y) ^ show (x <> y)
let poly x y = show (x < y) ^ show (x <= y) ^ show (x > y) ^ show (x >= y) ^ show (x = y) ^ show (x <> y)
let () =
  let nan = 0. /. 0. and inf = 1. /. 0. in
  let vs = [ 0.; -0.; 1.; -1.; 1.5; 1e300; -1e300; inf; -.inf; nan; 4.9e-324 ] in
  List.iter (fun x -> List.iter (fun y -> print_string (rel x y); print_char ' ') vs; print_newline ()) vs;
  print_endline (poly 1 2 ^ poly "a" "b" ^ poly (1, 2.) (1, 3.) ^ poly [ 1.; 2. ] [ 1.; 2. ] ^ poly (Some 1.) None);
  List.iter (fun x -> Printf.printf "%g %g %g %g %g %g | " (-.x) (abs_float x) (x +. 1.5) (x -. 1.5) (x *. -2.) (x /. 3.)) vs;
  print_newline ();
  List.iter (fun x -> Printf.printf "%d " (int_of_float x)) [ 0.; 1.9; -1.9; 1e9; -1e9; 123456.789; 0.5; -0.5 ];
  print_newline ();
  List.iter (fun i -> Printf.printf "%g " (float i)) [ 0; 1; -1; 1073741823; -1073741824; 12345 ];
  print_newline ();
  (* many floats and blocks made: the heap filled, the collector run, nothing lost *)
  let acc = ref 0. and l = ref [] in
  for i = 1 to 300000 do
    acc := !acc +. (float i *. 0.5);
    if i mod 1000 = 0 then l := (i, float i, !acc) :: !l
  done;
  Printf.printf "%g %d\n" !acc (List.length !l);
  List.iter (fun (i, f, a) -> if float i <> f || a < f then print_string "BAD ") !l;
  let (i, f, a) = List.nth !l 150 in
  Printf.printf "%d %g %g\n" i f a
