(* [@@unboxed_float] where it does not hold: the running sum, printed at
 * each turn, is boxed for print_float's call *)
let show (a : float array) =
  let s = ref 0.0 [@@unboxed_float] in
  for i = 0 to Array.length a - 1 do
    s := !s +. a.(i);
    print_float !s
  done

let () = show [| 1.0; 2.0 |]
