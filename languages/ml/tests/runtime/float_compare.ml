(* floats compared where the type checker sees them (the processor's
 * comparison, Lower's floats) and through a polymorphic function (the
 * runtime's), the same answers: numbers, infinities, zeros, nan *)

let poly_rel a b = [ a = b; a <> b; a < b; a <= b; a > b; a >= b ]

let () =
  let xs = [ 0.; -0.; 1.; -1.5; 2.25; infinity; neg_infinity; nan ] in
  List.iter (fun (a : float) ->
    List.iter (fun (b : float) ->
      let typed = [ a = b; a <> b; a < b; a <= b; a > b; a >= b ] in
      List.iter (fun t -> print_char (if t then 't' else 'f')) typed;
      print_char (if typed = poly_rel a b then ' ' else '!')) xs;
    print_newline ()) xs
