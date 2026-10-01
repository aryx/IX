(* a constructor of a type not in scope, where no type is written: no
 * type to take it from (mini-ml reads only what is written; OCaml
 * would not find it either, k's type being unknown) *)
module M = struct type t = A | B end
let f k = match k with A -> 1 | B -> 2
let _ = f
