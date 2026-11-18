(* matches that cover every case, which tiny-ml must accept: or-patterns
 * inside a constructor, a constructor of several arguments matched by
 * _, records with fields not named, guards before the case that covers
 * what they leave, literals with a catch-all, tuples of booleans, the
 * exceptions of a function, a let of a tuple and of () *)
type t = A | B of int | C of int * int
type r = { x : int; y : t }
let f v = match v with A -> 0 | B n -> n | C (a, _) -> a
let g o = match o with Some (A | B _) -> 1 | Some (C _) -> 2 | None -> 3
let h l = match l with [] -> 0 | [ _ ] -> 1 | _ :: _ :: _ -> 2
let i p = match p with (true, _) -> 1 | (false, true) -> 2 | (_, false) -> 3
let j r = match r with { y = A; _ } -> 0 | { y = B _ | C _; x } -> x
let k n = match n with 0 -> "zero" | 1 -> "one" | _ -> "many"
let m o = match o with Some x when x > 0 -> x | Some _ -> 0 | None -> -1
let n = function Not_found -> 1 | _ -> 2
let (a, b) = (10, 20)
let p n = print_int n; print_char ' '
let () =
  p (f (B 3)); p (f (C (4, 5))); p (g (Some A)); p (g (Some (C (1, 1)))); p (g None);
  p (h []); p (h [ 1; 2 ]); p (i (false, true)); p (i (true, false));
  p (j { x = 4; y = C (1, 2) }); p (m (Some 2)); p (m (Some (-2))); p (n Exit);
  p (a + b);
  print_string (k 1); print_newline ()
