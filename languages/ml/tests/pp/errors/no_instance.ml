(* expected: File "no_instance.ml", line 7, characters 15-26 *)
type 'a show = { show : 'a -> string } [@@class]

let show_int : int show = { show = string_of_int } [@@instance]
let a = show 1
(* no instance of show for float: said by OCaml, there *)
let b = show 1.5
