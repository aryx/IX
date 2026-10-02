(* an array read out of its bounds: OCaml's Invalid_argument, here not caught
 * (ocaml-light's ocamlopt on arm64 stops with a fatal error instead) *)
let () =
  let a = Array.make 3 0 in
  print_string "before"; print_newline ();
  print_int a.(3); print_newline ()
