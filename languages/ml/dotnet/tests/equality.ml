(* = on records and variants: their contents compared (each class its
   Equals, structural, F#'s), recursively; == the same object *)
type point = { x : int; y : int; label : string }
type expr = Num of int | Add of expr * expr | Neg of expr | Var of string

let yes b = print_string (if b then "T" else "F")

let () =
  let p = { x = 1; y = 2; label = "a" } in
  let q = { x = 1; y = 2; label = "a" } in
  let r = { p with label = "b" } in
  yes (p = q); yes (p = r); yes (p <> r); yes (p == q); yes (p == p);
  print_newline ();
  let e1 = Add (Num 1, Neg (Var "x")) in
  let e2 = Add (Num 1, Neg (Var "x")) in
  let e3 = Add (Num 1, Neg (Var "y")) in
  yes (e1 = e2); yes (e1 = e3); yes (Num 3 = Num 3); yes (Num 3 = Var "3"); yes (e1 <> e3);
  print_newline ()

(* a constant constructor is one value, == of two true (as OCaml's
 * immediate; Hashtbl.replace counts on it) *)
type bucket = Empty | Cons of int * bucket
let keep (b : bucket) : bucket = match b with Empty -> Empty | Cons _ -> b
let () =
  let e = Empty in
  print_string (if keep e == e && Empty == Empty then "Empty == Empty\n" else "Empty != Empty\n");
  print_string (if (None : int option) == None && ([] : string list) == [] then "None == None\n" else "None != None\n")
