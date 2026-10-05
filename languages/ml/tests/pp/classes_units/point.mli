(* a type, and its instance of another unit's class, in the type's unit *)
type t = { x : int; y : int }

val show_point : t Classy.show [@@instance]
val origin : t
