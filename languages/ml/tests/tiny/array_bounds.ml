(* an array read out of its bounds: a fatal error, as ocamlopt's *)
let () =
  let a = Array.make 3 0 in
  print_string "before"; print_newline ();
  print_int a.(3); print_newline ()
