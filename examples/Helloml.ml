(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* helloml: mini-ml's compiler and runtime tried on mini-9pi, in
 * /src/examples (hello.c is C's). A variant and its recursive
 * functions, a closure, an exception caught, strings and lists of the
 * standard library (lib_core); and enough lists made and dropped that
 * the runtime's collector runs (languages/ml/runtime/gc.c). The mkfile
 * beside it builds it (ml, then the link with the standard library,
 * the runtime and the C library):
 *
 *     cd /src/examples; mk; ../_mk/5-plan9/examples/helloml
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

(* a closure that adds k *)
let adder k = fun x -> x + k

let main (caps : < Cap.stdout; .. >) : Exit.t =
  let t = List.fold_left insert Leaf [ 5; 3; 8; 1; 4; 9; 2; 7 ] in
  let sorted = elements t [] in
  Console.print caps
    (Printf.sprintf "sorted: %s\n"
       (String.concat " " (List.map string_of_int sorted)));
  (match first_over 5 sorted with
   | Some x -> Console.print caps (Printf.sprintf "the first over 5: %d\n" x)
   | None -> Console.print caps "none over 5\n");
  (* 20,000 lists of 100, each dropped: 2,000,000 cells, 48 MB on a
   * machine of 64 bits, more than the heap starts with *)
  let kept = ref [] and cells = ref 0 in
  for i = 1 to 20000 do
    let l = List.map (adder i) (List.init 100 (fun j -> j + 1)) in
    cells := !cells + List.length l;
    if i = 20000 then kept := l
  done;
  Console.print caps
    (Printf.sprintf "%d cells made, the last list from %d to %d\n" !cells
       (List.hd !kept) (List.nth !kept 99));
  Exit.OK

(* A program of ix's starts with Cap.main, which gives its capabilities
 * (lib_core/system/Cap.mli): what main may do is in the type of its
 * first parameter, here printing and nothing else. *)
let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
