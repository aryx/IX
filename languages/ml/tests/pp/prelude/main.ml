(* lib_core/commons/Prelude: Haskell's classes by mlpp's. (Prelude's
 * files here are links to it: this directory is a program of pp.sh's
 * and run.sh's, and for dune a program using the library.) *)
open Prelude

type point = { x : int; y : int }

(* a type of the program's: its instances, in its unit *)
let show_point : point show = { show = (fun p -> "{ x = " ^ show p.x ^ "; y = " ^ show p.y ^ " }") } [@@instance]
let eq_point : point eq = { equal = (fun p q -> p.x == q.x && p.y == q.y) } [@@instance]
let ord_point : point ord = { compare = (fun p q -> compare (p.x, p.y) (q.x, q.y)) } [@@instance]

(* Haskell's (Show a, Ord a) => [a] -> String *)
let describe [%using: 'a show] [%using: 'a ord] (xs : 'a list) =
  show (List.length xs) ^ " of " ^ show xs ^ ", sorted " ^ show (sort xs) ^ ", the largest " ^ show (maximum xs)

let () =
  let p = { x = 1; y = 2 } and q = { x = 0; y = 5 } in
  print_endline (show (3, "three", [ 3.5 ]));
  print_endline (show [ Some (-1); None; Some 2 ]);
  print_endline (show [| 'a'; '\n' |]);
  print_endline (show (Some (Some ()), 7L));
  print_endline (describe [ 3; 1; 2 ]);
  print_endline (describe [ "b"; "a" ]);
  print_endline (describe [ p; q ]);
  print_endline (describe [ [ p ]; []; [ q; p ] ]);
  print_endline (show [ p == p; p != q; [ p ] /= [ p ]; (1, "a") == (1, "a"); Some 1.5 == None ]);
  print_endline (show (compare [ 1; 2 ] [ 1; 3 ], compare (Some "a") None, minimum [ (2, 'a'); (1, 'z') ]))
