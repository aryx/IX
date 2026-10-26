(* Float.min and Float.max on every pair of: zeros of both signs,
 * numbers, infinities, nans of both signs; the result's bits, which
 * say which zero and which nan (OCaml's choices) *)

let () =
  let xs = [ 0.; -0.; 1.; -1.5; infinity; neg_infinity; nan; -.nan ] in
  List.iter (fun (x : float) ->
    List.iter (fun (y : float) ->
      Printf.printf "%Lx %Lx\n"
        (Int64.bits_of_float (Float.min x y))
        (Int64.bits_of_float (Float.max x y))) xs) xs
