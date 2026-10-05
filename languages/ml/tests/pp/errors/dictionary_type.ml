(* expected: File "dictionary_type.ml", line 8, characters 18-23 *)
type 'a show = { show : 'a -> string } [@@class]

let show_int : int show = { show = string_of_int } [@@instance]
let show_string : string show = { show = (fun s -> s) } [@@instance]
let print [%using: 'a show] (x : 'a) = print_endline (show x)
(* an error after a dictionary, on its line: OCaml's, at its place in the source *)
let () = print 1; print "a" 2
