(* Routing: from two places to a route: the extract, the search, the words.

     two places --> a box around them --> the extract --> Roads --> Route
                                          kept on disk

   One extract is kept, in the file roads of the cache's directory, its
   first line saying its box and when it was fetched. It serves any route
   whose two ends are in its box, for 30 days (roads change slowly, and
   Overpass asks for little: Roads.mli). The graph of the last one is kept
   in memory as well: making it is the slow part. *)

type t = {
  from : string;
  goal : string;
  points : (float * float) array; (* latitude, longitude, in the order driven *)
  millis : int;
  metres : int;
  settled : int; (* by A* *)
  nodes : int; (* in the extract *)
  steps : (string * int) list; (* the roads driven, their metres; "" for no name *)
}

(* [find caps ~base ~dir ~dijkstra a b]: the route, with [dir] the cache's
 * directory if there is one; with [dijkstra], how many nodes Dijkstra's
 * search settles too (the terminal's lesson); or what went wrong *)
val find :
  < Cap.network; Cap.open_in; Cap.open_out; .. > ->
  base:string ->
  dir:string option ->
  dijkstra:bool ->
  Place.t ->
  Place.t ->
  (t * int option, string) result

(* "28.4 km, 31 min" *)
val summary : t -> string

(* the route as lines, for a terminal; with Dijkstra's count if there is one *)
val lines : t -> int option -> string list

(* the route as a band on the map at zoom [z], the window's centre at
 * [cx], [cy], its size [fw] by [fh] (points closer than 3 pixels make one) *)
val shapes : t -> z:int -> cx:int -> cy:int -> float -> float -> Playground.shape list
