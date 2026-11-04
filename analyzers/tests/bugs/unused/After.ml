(* 70b6b2bf: the timeout kept; and reads OCaml counts too: by arithmetic
 * only, in a closure, given back to the function itself *)
let ask (address : string) (port : int) (packet : string) (seconds : float) : string =
  if seconds > 0. then address ^ string_of_int port ^ packet else ""

let inc (n : int) : int = n + 1
let adder (k : int) : int -> int = fun x -> x + k
let rec count (x : int) (n : int) : int = if n = 0 then 0 else 1 + count x (n - 1)

let () =
  print_string (ask "h" 1 "p" 2.);
  print_int (inc 1 + adder 2 3 + count 0 3)
