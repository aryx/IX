(* arrays: made, read, written, their length; of arrays (a row shared
 * as Array.make shares it), of records, sorted in place, compared;
 * a.(i) <- v's evaluation order; many, for the collector *)
type point = { x : int; mutable y : int }
let say s n = print_string s; n
let print_array a =
  for i = 0 to Array.length a - 1 do print_int a.(i); print_char ' ' done; print_newline ()
let sort a =
  let n = Array.length a in
  for i = 0 to n - 1 do
    for j = 0 to n - 2 - i do
      if a.(j) > a.(j + 1) then (let t = a.(j) in a.(j) <- a.(j + 1); a.(j + 1) <- t)
    done
  done
let sum a = let s = ref 0 in for i = 0 to Array.length a - 1 do s := !s + a.(i) done; !s
let () =
  let a = Array.make 5 0 in
  for i = 0 to 4 do a.(i) <- i * i done;
  print_array a;
  print_int (Array.length a); print_char ' '; print_int (Array.length (Array.make 0 'x')); print_newline ();
  let b = Array.make 6 0 in
  b.(0) <- 5; b.(1) <- 3; b.(2) <- 9; b.(3) <- 1; b.(4) <- 4; b.(5) <- 1;
  sort b; print_array b;
  let m = Array.make 2 (Array.make 3 0) in
  m.(0).(1) <- 7;
  print_array m.(0); print_array m.(1);
  let ps = Array.make 3 { x = 0; y = 0 } in
  for i = 0 to 2 do ps.(i) <- { x = i; y = 10 * i } done;
  ps.(1).y <- 99;
  for i = 0 to 2 do print_int ps.(i).x; print_char ','; print_int ps.(i).y; print_char ' ' done; print_newline ();
  let s = Array.make 2 "a" in s.(1) <- "b"; print_string (s.(0) ^ s.(1)); print_newline ();
  (* which runs first: the array, the index, the value *)
  (say "a " a).(say "i " 0) <- say "v " 42; print_newline ();
  ignore ((say "a " a).(say "i " 0)); print_newline ();
  print_string (if a = Array.make 5 0 then "equal" else "different"); print_char ' ';
  print_string (if Array.make 2 1 = Array.make 2 1 then "equal" else "different"); print_newline ();
  let total = ref 0 in
  for n = 1 to 300 do let c = Array.make n n in total := !total + sum c done;
  print_int !total; print_newline ()
