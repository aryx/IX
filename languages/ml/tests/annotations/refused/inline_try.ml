(* [@inline] where it cannot hold: a handler is never copied into the
 * callers (its frame is the function's) *)
let[@inline] first (l : int list) = try List.hd l with Failure _ -> 0

let () = print_int (first [ 4 ])
