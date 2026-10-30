(* Map_look: the letters of mini-maps' window, Hershey's, each at its place *)

(* [text color ~size x baseline s]: [s]'s letters from [x], and their width *)
val text : Playground.color -> size:float -> float -> float -> string -> Playground.shape * float

val width_of : string -> float

(* as much of [s] as fits in [room], and "..." if it does not *)
val cut : float -> string -> string
