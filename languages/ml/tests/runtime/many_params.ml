(* functions of more parameters than the machine's registers (arm's 8,
 * arm64's 15): the arguments past them on the value stack; of more than
 * 7, their unit's own curry functions (not tiny/: tiny-ml has fewer
 * registers) *)

let f10 a b c d e f g h i j = a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i + 10 * j

let f16 a b c d e f g h i j k l m n o p =
  a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i + 10 * j
  + 11 * k + 12 * l + 13 * m + 14 * n + 15 * o + 16 * p

(* in tail position: the callee's frame where the caller's was *)
let tail10 x = f10 x (x + 1) (x + 2) (x + 3) (x + 4) (x + 5) (x + 6) (x + 7) (x + 8) (x + 9)
let tail16 x = f16 x 2 3 4 5 6 7 8 9 10 11 12 13 14 15 x

(* the arguments' order reversed, in tail position: each read from the
 * frame before it is overwritten *)
let rec swap n a b c d e f g h i j =
  if n = 0 then f10 a b c d e f g h i j else swap (n - 1) j i h g f e d c b a

(* through a closure, called with all its arguments *)
let apply10 (g : int -> int -> int -> int -> int -> int -> int -> int -> int -> int -> int) x =
  g x 1 2 3 4 5 6 7 8 9
let apply16 g x = g x 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

(* over-applied: returns a function *)
(* (the sums nested to the right, or grouped: a left one of 9 variables
 * is an expression too deep for arm's registers, the stack machine's) *)
let make a b c d e f g h i j = fun k -> a + (b + (c + (d + (e + (f + (g + (h + (i + (j + k)))))))))

(* 20, partially applied in two steps *)
let f20 a b c d e f g h i j k l m n o p q r s t =
  (a - b + c - d + e) - (f - g + h - i + j) + (k - l + m - n + o) - (p - q + r - s + t)

(* allocates, and raises and catches *)
exception Found of int list
let alloc10 a b c d e f g h i j =
  let l = ref [] in
  for n = 1 to 1000 do l := [ a; b; c; d; e; f; g; h; i; j; n ] @ (if n mod 100 = 0 then !l else []) done;
  try if List.length !l > 0 then raise (Found !l) else 0
  with Found l -> List.fold_left (+) 0 l + a + j

(* recursive, not in tail position *)
let rec sum10 n a b c d e f g h i =
  if n = 0 then a + (b + (c + (d + (e + (f + (g + (h + i)))))))
  else n + sum10 (n - 1) b c d e f g h i a

let () =
  print_int (f10 1 2 3 4 5 6 7 8 9 10); print_newline ();
  print_int (f16 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16); print_newline ();
  print_int (tail10 1); print_newline ();
  print_int (tail16 100); print_newline ();
  print_int (swap 3 1 2 3 4 5 6 7 8 9 10); print_newline ();
  print_int (apply10 f10 1); print_newline ();
  print_int (apply16 f16 1); print_newline ();
  (* partially applied: 3 arguments, then 7 *)
  let p3 = f10 1 2 3 in
  print_int (p3 4 5 6 7 8 9 10); print_newline ();
  print_int (List.fold_left (+) 0 (List.map (fun x -> p3 x x x x x x x) [ 1; 2; 3 ])); print_newline ();
  let p7 = f16 1 2 3 4 5 6 7 in
  print_int (p7 8 9 10 11 12 13 14 15 16); print_newline ();
  let k = List.length [ 1; 2 ] in
  print_int (apply10 (fun a b c d e f g h i j -> k * a * j + f10 a b c d e f g h i j) 3); print_newline ();
  print_int (make 1 2 3 4 5 6 7 8 9 10 11); print_newline ();
  print_int ((make 1 2 3 4 5 6 7 8 9 10) 100); print_newline ();
  print_int (alloc10 1 2 3 4 5 6 7 8 9 10); print_newline ();
  print_int (sum10 100 1 2 3 4 5 6 7 8 9); print_newline ();
  let p12 = f20 1 2 3 4 5 6 7 8 9 10 11 12 in
  let p15 = p12 13 14 15 in
  print_int (p15 16 17 18 19 20 + p12 0 0 0 0 0 0 0 0); print_newline ()
