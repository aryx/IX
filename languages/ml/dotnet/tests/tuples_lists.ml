(* tuples, Stdlib.tuple`n<...> (Item1...), and lists, Stdlib.list`1
   (Nil, Cons): built, matched, given to generic functions, compared *)
let swap (a, b) = (b, a)
let divmod a b = (a / b, a mod b)
let third (_, _, c) = c

let rec length l = match l with [] -> 0 | _ :: r -> 1 + length r
let rec sum l = match l with [] -> 0 | x :: r -> x + sum r
let rec map f l = match l with [] -> [] | x :: r -> f x :: map f r
let rec rev_onto a b = match a with [] -> b | x :: r -> rev_onto r (x :: b)
let rev l = rev_onto l []

let rec join l =
  match l with
  | [] -> ""
  | [ x ] -> x
  | x :: r -> x ^ ", " ^ join r

let rec lookup k l =
  match l with
  | [] -> None
  | (k', v) :: r -> if k = k' then Some v else lookup k r

let yes b = print_string (if b then "T" else "F")

let () =
  let q, r = divmod 17 5 in
  print_int q; print_string " "; print_int r; print_newline ();
  let s, n = swap (1, "one") in
  print_endline (s ^ " " ^ string_of_int n);
  print_endline (third (1, 2.5, "third"));
  let l = [ 1; 2; 3; 4 ] in
  print_int (length l); print_string " "; print_int (sum l); print_newline ();
  print_endline (join (map (fun x -> string_of_int (x * x)) l));
  print_endline (join (rev [ "a"; "b"; "c" ]));
  let table = [ ("one", 1); ("two", 2); ("three", 3) ] in
  (match lookup "two" table with Some v -> print_int v | None -> print_string "none");
  (match lookup "four" table with Some v -> print_int v | None -> print_string " none");
  print_newline ();
  yes ([ 1; 2 ] = [ 1; 2 ]); yes ([ 1; 2 ] = [ 2; 1 ]); yes ((1, "a") = (1, "a")); yes (swap (1, 2) = (2, 1));
  yes (rev l = [ 4; 3; 2; 1 ]); yes ([] = map (fun x -> x + 1) []);
  print_newline ()
