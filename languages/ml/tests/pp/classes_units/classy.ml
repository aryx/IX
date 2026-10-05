type 'a show = [%mli] [@@class]

let show_int : int show = { show = string_of_int } [@@instance]

let rec show_list [%using: 'a show] : 'a list show =
  { show = (function [] -> "[]" | x :: xs -> show x ^ " :: " ^ show xs) }
[@@instance]

let print [%using: 'a show] (x : 'a) = print_endline (show x)
