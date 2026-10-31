(* tail calls: a call in tail position after IL's tail. prefix, the
   callee's frame in the caller's place, so that a loop written as a
   tail recursion runs in one frame (a hundred thousand turns:
   mini-dotnet stops at ten thousand frames, Microsoft's stack has no
   room for so many) *)
let rec count n acc = if n = 0 then acc else count (n - 1) (acc + 1)

let rec even n = if n = 0 then true else odd (n - 1)
and odd n = if n = 0 then false else even (n - 1)

let rec build n acc = if n = 0 then acc else build (n - 1) (n :: acc)
let rec sum l acc = match l with [] -> acc | x :: r -> sum r (acc + x)

let rec repeat (step : int -> int) n acc = if n = 0 then acc else repeat step (n - 1) (step acc)

let () =
  print_int (count 100_000 0); print_newline ();
  print_string (if even 100_001 then "even" else "odd"); print_newline ();
  print_int (sum (build 100_000 []) 0); print_newline ();
  print_int (repeat (fun x -> x + 3) 100_000 0); print_newline ();
  let rec go n acc = if n = 0 then acc else go (n - 1) (acc + 2) in
  print_int (go 100_000 0); print_newline ()
