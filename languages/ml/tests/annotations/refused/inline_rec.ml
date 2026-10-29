(* [@inline] where it cannot hold: a recursive function is never
 * copied into its callers *)
let[@inline] rec fact (n : int) = if n = 0 then 1 else n * fact (n - 1)

let () = print_int (fact 5)
