(* closures: a function value a System.Func, a lambda a class of the
   variables it captures, a partial application a Func of the arguments
   given, a call of a function value its Invoke, an argument at a time *)
let apply (f : int -> int) x = f x
let compose (f : int -> int) (g : int -> int) x = f (g x)
let twice (f : int -> int) x = f (f x)
let add x y = x + y
let inc = add 1

let make_adder start = fun step -> start + step
let greet (prefix : string) = fun name -> prefix ^ name

let show n = print_int n; print_newline ()

let () =
  show (apply (fun x -> x * 2) 21);
  show (inc 41);
  show (compose inc (add 10) 5);
  let k = 3 in
  let times_k x = x * k in
  show (twice times_k 2);
  let from10 = make_adder 10 in
  show (from10 5);
  let rec fact n = if n = 0 then 1 else n * fact (n - 1) in
  show (fact 10);
  let plus = add in
  show (plus 2 3);
  print_endline (greet "hello, " "world");
  let say = fun () -> print_string "said " in
  say (); say (); print_newline ();
  let adder = fun x y -> x + y in
  show (adder 3 4);
  let sign = function 0 -> "zero" | n when n > 0 -> "positive" | _ -> "negative" in
  print_endline (sign 0 ^ " " ^ sign 7 ^ " " ^ sign (-2));
  let counter = make_adder 100 in
  show (apply counter (apply (add 5) 1))
