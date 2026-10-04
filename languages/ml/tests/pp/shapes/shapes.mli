(* mlpp's type t = [%mli] and [@@deriving show]: the .mli has the types, the
 * .ml takes them; show and show_shape come from the declarations *)

type point = { x : int; y : int }

(* a tree of shapes, the .ml's printer derived *)
type 'a shape =
  | Dot of point
  | Circle of point * int
  | Group of string * 'a shape list
  | Tagged of 'a * 'a shape option
[@@deriving show]

type t = Nothing | Shapes of int shape list [@@deriving show]

val area : 'a shape -> int
