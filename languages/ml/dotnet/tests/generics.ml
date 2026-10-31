(* polymorphic functions: generic methods (!!0...), each call naming its
   instantiation (a MethodSpec): id at an int is id<long>, at a string
   id<string>; = on a type variable the value's own Equals *)
type point = { x : int; y : int }

let id x = x
let twice f x = f (f x)
let compose f g x = f (g x)
let const x _ = x
let rec repeat f n x = if n = 0 then x else repeat f (n - 1) (f x)
let same a b = a = b
let pick c a b = if c then a else b
let pair_same a b c = same a b && same b c

let yes b = print_string (if b then "T" else "F")

let () =
  print_int (id 5); print_endline (id " five");
  print_int (twice (fun x -> x * 3) 2); print_newline ();
  print_endline (twice (fun s -> s ^ "!") "hey");
  print_int (compose (fun x -> x + 1) (fun x -> x * 10) 4); print_newline ();
  print_endline (compose (fun n -> string_of_int n) (fun s -> String.length s) "seven");
  print_endline (const "kept" 42);
  print_int (repeat (fun x -> x * 2) 10 1); print_newline ();
  yes (same 3 3); yes (same "a" "b"); yes (same { x = 1; y = 2 } { x = 1; y = 2 });
  yes (pair_same 4 4 4); yes (pair_same "a" "a" "b");
  print_newline ();
  let p = pick false { x = 1; y = 1 } { x = 9; y = 8 } in
  print_int (p.x + p.y); print_newline ()
