(* mlpp's classes (plan_ml_bootstrap.md, "Type classes"): a class, a
 * record type; an instance, a value of it; [%using: ...], a dictionary
 * the calls don't write *)
type 'a show = { show : 'a -> string } [@@class]
type 'a eq = { equal : 'a -> 'a -> bool } [@@class]

let show_int : int show = { show = string_of_int } [@@instance]
let show_bool : bool show = { show = string_of_bool } [@@instance]
let show_string : string show = { show = (fun s -> "\"" ^ s ^ "\"") } [@@instance]

(* an instance with a dictionary of its own; rec: show, at 'a list, is itself *)
let rec show_list [%using: 'a show] : 'a list show =
  { show = (function [] -> "[]" | x :: xs -> show x ^ " :: " ^ show xs) }
[@@instance]

let show_option [%using: 'a show] : 'a option show =
  { show = (function None -> "None" | Some x -> "Some " ^ show x) }
[@@instance]

let show_pair [%using: 'a show] [%using: 'b show] : ('a * 'b) show =
  { show = (fun (a, b) -> "(" ^ show a ^ ", " ^ show b ^ ")") }
[@@instance]

(* a type of this unit *)
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec show_tree [%using: 'a show] : 'a tree show =
  { show = (function Leaf -> "." | Node (l, x, r) -> "(" ^ show l ^ " " ^ show x ^ " " ^ show r ^ ")") }
[@@instance]

(* an abbreviation: its type's instance *)
type name = string

(* functions with a constraint *)
let print [%using: 'a show] (x : 'a) = print_endline (show x)
let print_all [%using: 'a show] (xs : 'a list) = print xs; List.iter print xs
let shows [%using: 'a show] (xs : 'a list) = String.concat ", " (List.map show xs)

(* the dictionary named, and used as the record it is *)
let twice (d : [%using: 'a show]) (x : 'a) = d.show x ^ d.show x

(* a function calling itself *)
let rec lines [%using: 'a show] (xs : 'a list) = match xs with [] -> "" | x :: rest -> show x ^ "\n" ^ lines rest

(* two classes; an operator of a class *)
let eq_int : int eq = { equal = (fun (a : int) b -> a = b) } [@@instance]
let eq_string : string eq = { equal = (fun (a : string) b -> a = b) } [@@instance]

let rec eq_list [%using: 'a eq] : 'a list eq =
  { equal = (fun xs ys -> match xs, ys with [], [] -> true | x :: xs, y :: ys -> equal x y && equal xs ys | _ -> false) }
[@@instance]

let ( == ) (d : [%using: 'a eq]) (a : 'a) (b : 'a) = d.equal a b
let ( /= ) [%using: 'a eq] (a : 'a) (b : 'a) = not (a == b)
let member [%using: 'a eq] (x : 'a) (xs : 'a list) = List.exists (fun y -> x == y) xs
let describe [%using: 'a show] [%using: 'a eq] (a : 'a) (b : 'a) = show a ^ (if a == b then " = " else " <> ") ^ show b

let () =
  print 3;
  print true;
  print [ 1; 2 ];
  print [ ("a", Some 1); ("b", None) ];
  print (Node (Node (Leaf, 1, Leaf), 2, Leaf));
  print_all [ [ "x" ]; [] ];
  print_endline (shows [ 1; 2; 3 ]);
  print_endline (twice 4);
  print_string (lines [ true; false ]);
  let n : name = "ix" in
  print n;
  print (1 == 1 && [ 1; 2 ] /= [ 1; 3 ]);
  print (member "b" [ "a"; "b" ], member [ 1 ] [ []; [ 2 ] ]);
  print_endline (describe [ 1 ] [ 1 ]);
  print_endline (String.concat " " (List.map show [ 1 == 2; 2 == 2 ]))
