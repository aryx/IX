(* expected-pp: two_instances.ml:5: show_hex [@@instance]: Two_instances.show_int is already Two_instances.show's at int *)
type 'a show = { show : 'a -> string } [@@class]

let show_int : int show = { show = string_of_int } [@@instance]
let show_hex : int show = { show = Printf.sprintf "%x" } [@@instance]
