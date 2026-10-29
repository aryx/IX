(* [@@zero_alloc] where it does not hold: pow allocates nothing, but it
 * is not marked, and recursive it is not inlined (a small function
 * would be, then its call gone and nothing to check) *)
let rec pow (x : int) n = if n = 0 then 1 else x * pow x (n - 1)

let cube (x : int) = pow x 3 [@@zero_alloc]

let () = print_int (cube 3)
