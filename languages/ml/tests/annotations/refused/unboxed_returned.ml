(* [@@unboxed_float] where it does not hold: the sum, returned, leaves
 * the function as a block *)
let total (a : float array) =
  let s = ref 0.0 [@@unboxed_float] in
  for i = 0 to Array.length a - 1 do s := !s +. a.(i) done;
  !s

let () = print_float (total [| 1.0; 2.0 |])
