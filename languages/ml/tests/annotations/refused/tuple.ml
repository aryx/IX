(* [@@zero_alloc] where it does not hold: the pair returned is a block *)
let div_mod (a : int) b = (a / b, a mod b) [@@zero_alloc]

let () = let q, r = div_mod 7 2 in Printf.printf "%d %d\n" q r
