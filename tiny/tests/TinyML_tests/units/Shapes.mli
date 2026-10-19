(* Shapes, for Main: an .mli tiny-ml -c reads for its names' types *)
type shape = Square of int | Rect of int * int | Dot
type box = { name : string; shape : shape }
exception Empty of string
type 'a pair = 'a * 'a
val area : shape -> int
val scaled : int -> shape -> shape
val boxes : box list
val largest : box list -> box
val sides : shape -> int pair
