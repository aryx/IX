(* expected: File "no_dictionary.ml", line 6, characters 21-32 *)
type 'a show = { show : 'a -> string } [@@class]

let show_int : int show = { show = string_of_int } [@@instance]
(* no constraint is inferred: a function that needs a dictionary says so *)
let twice x = show x ^ show x
