(* recursion, ints, a unit's function called by its toplevel *)
let rec fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

let () =
  print_int (fib 20);
  print_newline ()
