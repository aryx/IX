(* x |> f: f x, the operator at the comparisons' level, to the left *)
let add n x = x + n
let () = print_int (20 |> add 1 |> add 21); print_newline ()
let () = print_int ([ 1; 2; 3 ] |> List.map (add 1) |> List.filter (fun x -> x > 2) |> List.length); print_newline ()
let () = print_int (1 + 2 |> add 3); print_newline ()
