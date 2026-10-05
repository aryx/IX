(* a class and its instances at the predefined types, in its unit; the
 * methods' and the instances' declarations, for the units using them *)
type 'a show = { show : 'a -> string } [@@class]

val show_int : int show [@@instance]
val show_list : [%using: 'a show] -> 'a list show [@@instance]
val print : [%using: 'a show] -> 'a -> unit
