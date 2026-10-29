(* [@@zero_alloc] where it does not hold: the loop's float stays a
 * double (Unbox), but the result, a float returned, is boxed *)
let dot (a : float array) (b : float array) =
  let s = ref 0.0 in
  for i = 0 to Array.length a - 1 do s := !s +. a.(i) *. b.(i) done;
  !s [@@zero_alloc]

let () = print_float (dot [| 1.0; 2.0 |] [| 3.0; 4.0 |])
