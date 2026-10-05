(* expected: File "generator.ml", line 5, characters 38-46 *)
(* a type error in a [%list]'s generator, which the rewrite copies: its
 * place is the source's *)
let xs = [ 1; 2; 3 ]
let _ = [%list x + y || x <- xs; y <- "a list"; x < y]
