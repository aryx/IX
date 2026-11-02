(* each shape of control flow: a loop (a phi), a test, a match, a
 * handler (its slots in memory), a call in tail position *)
let triangle (n : int) : int =
  let r = ref 0 in
  for i = 1 to n do r := !r + i done;
  !r

let rec gcd (a : int) (b : int) : int = if b = 0 then a else gcd b (a mod b)

let rec length (xs : int list) (acc : int) : int =
  match xs with [] -> acc | _ :: rest -> length rest (acc + 1)

let safe_div (a : int) (b : int) : int = try a / b with Division_by_zero -> 0

let rec collatz (n : int) (steps : int) : int =
  if n = 1 then steps
  else if n mod 2 = 0 then collatz (n / 2) (steps + 1)
  else collatz ((3 * n) + 1) (steps + 1)

let () = print_int (triangle 10 + gcd 12 18 + length [ 1; 2 ] 0 + safe_div 1 0 + collatz 6 0)
