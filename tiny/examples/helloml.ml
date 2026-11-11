(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* helloml: tiny-ml's compiler and runtime tried on tiny-kernel, in
 * /examples (hello.c is C's). A variant and its recursive functions, a
 * closure, an exception caught, strings and lists of TinyLibCore; and
 * enough lists made and dropped that ../runtime/ml.c's collector runs.
 * The Buildfile beside it builds it (tiny-ml, then the link with the C
 * runtime, mlsys.c and /lib/ml's library):
 *
 *     cd /examples; build helloml; ./helloml
 *     trace ./helloml        its writes
 *     debug ./helloml        b insert, c, bt (an ML frame's slots), q
 *)

(* a binary search tree of integers *)
type tree = Leaf | Node of tree * int * tree

let rec insert t x =
  match t with
  | Leaf -> Node (Leaf, x, Leaf)
  | Node (l, y, r) ->
      if x < y then Node (insert l x, y, r) else Node (l, y, insert r x)

(* its numbers in order: the right subtree first, so that each is put
 * in front of the bigger ones *)
let rec elements t acc =
  match t with
  | Leaf -> acc
  | Node (l, x, r) -> elements l (x :: elements r acc)

exception Found of int

(* the first number over n, by an exception out of the walk *)
let first_over n l =
  try
    List.iter (fun x -> if x > n then raise (Found x)) l;
    None
  with Found x -> Some x

(* [1; ...; n], and a closure that adds k *)
let rec upto n acc = if n = 0 then acc else upto (n - 1) (n :: acc)
let adder k = fun x -> x + k

let () =
  let t = List.fold_left insert Leaf [ 5; 3; 8; 1; 4; 9; 2; 7 ] in
  let sorted = elements t [] in
  print_string ("sorted: " ^ String.concat " " (List.map string_of_int sorted)
                ^ "\n");
  (match first_over 5 sorted with
   | Some x -> print_string ("the first over 5: " ^ string_of_int x ^ "\n")
   | None -> print_string "none over 5\n");
  (* 2,000 lists of 100, each dropped: 200,000 cells, more than the
   * heap's half, so the collector copies what lives *)
  let kept = ref [] and cells = ref 0 in
  for i = 1 to 2000 do
    let l = List.map (adder i) (upto 100 []) in
    cells := !cells + List.length l;
    if i = 2000 then kept := l
  done;
  print_string
    (Printf.sprintf "%d cells made, the last list from %d to %d\n" !cells
       (List.hd !kept) (List.nth !kept 99))
