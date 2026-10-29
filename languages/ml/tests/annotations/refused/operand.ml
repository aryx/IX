(* [@tailcall] where it does not hold: the call's result is added to *)
let f x = x + 1

let g x = (f [@tailcall]) x + 1

let () = print_int (g 1)
