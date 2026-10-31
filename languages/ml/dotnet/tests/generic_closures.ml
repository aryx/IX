(* closures inside polymorphic functions: classes generic in the
   function's type variables, made at its method's (closure`2<!!0,
   !!1>); polymorphic functions given fewer arguments: their classes
   generic too, made at what the use gives (map_1`2<long, string>) *)
let rec map f l = match l with [] -> [] | x :: r -> f x :: map f r

let map_local f l =
  let rec go l = match l with [] -> [] | x :: r -> f x :: go r in
  go l

let pairs x l = map (fun y -> (x, y)) l

let rec fold f acc l = match l with [] -> acc | x :: r -> fold f (f acc x) r

let filter p l =
  let keep acc x = if p x then x :: acc else acc in
  let rec rev acc l = match l with [] -> acc | x :: r -> rev (x :: acc) r in
  rev [] (fold keep [] l)

let twice f x = f (f x)
let adder n = fun x -> x + n
let nested x = let outer y = let inner z = (x, y, z) in inner in outer

let add3 = map (fun x -> x + 3)
let shout = map (fun s -> s ^ "!")
let inc_twice = twice (fun x -> x + 1)

let rec join l = match l with [] -> "" | [ x ] -> x | x :: r -> x ^ " " ^ join r
let show l = join (map_local string_of_int l)

let () =
  print_endline (show (add3 [ 1; 2; 3 ]));
  print_endline (join (shout [ "a"; "b" ]));
  print_endline (show (filter (fun x -> x mod 2 = 0) [ 1; 2; 3; 4; 5; 6 ]));
  print_int (fold (fun a b -> a + b) 0 [ 1; 2; 3; 4 ]); print_newline ();
  print_endline (fold (fun a b -> a ^ b) "" [ "x"; "y"; "z" ]);
  print_endline (join (map (fun (n, s) -> string_of_int n ^ s) (pairs 7 [ "a"; "b" ])));
  print_int (inc_twice 40); print_newline ();
  print_int (twice (adder 5) 0); print_newline ();
  let a, b, c = nested "x" 1 true in
  print_endline (a ^ string_of_int b ^ (if c then "T" else "F"))
