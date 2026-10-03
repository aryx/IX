(* mlpp's deriving against ppx_deriving's (derive.out is what its show prints
 * for this file: dune's (preprocess (pps ppx_deriving.show)))): every shape of
 * type, and a value long enough for lines to break *)
type loc = { file : string; line : int } [@@deriving show]
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving show]
type e = Int of int | Str of string | Pair of e * e | L of e list | O of e option | R of { a : int; b : bool } | F of float | C of char | At of loc * e
and d = e array * (int * string) [@@deriving show]
let () =
  print_endline (show_loc { file = "a.ml"; line = 3 });
  print_endline (show_tree (fun fmt x -> Format.pp_print_int fmt x) (Node (Leaf, 1, Node (Leaf, 2, Leaf))));
  print_endline (show_e (At ({ file = "x"; line = 1 }, Pair (L [ Int 1; Str "a\n"; O None; O (Some (F 1.5)) ], R { a = 1; b = true }))));
  print_endline (show_d ([| C 'x'; Int (-3) |], (1, "s")));
  print_endline (show_e (L (List.init 30 (fun i -> Int i))))
