(* [@@tailrec] where it does not hold: a call inside a try returns to
 * the handler's frame before the function's *)
let rec find l x = match l with [] -> raise Not_found | y :: t -> (try if y = x then 0 else 1 + find t x with Not_found -> -1) [@@tailrec]

let () = print_int (find [ 1; 2 ] 2)
