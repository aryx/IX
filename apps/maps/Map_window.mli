(* Map_window: the map as a window, moved and zoomed.

     mouse, keys  --> where the window is: a zoom and a centre, whole pixels
                        |
                        | Tiles.in_view
                        v
                      the tiles it overlaps --> those missing --> Map_worker
                        |                                            |
                        v                                            |
                      the store of tiles  <------- what comes --------
                        |
                        v
                      a Bitmap each, enlarged from an ancestor until its own
                      comes; and the credit, which OSM's licence asks of us

   And a place found (Place), on Enter in the Find box (/, or a click on
   it): the worker asks, the window goes there and marks it, and the last
   ones are listed in the box, kept and not asked again. A click on the
   map marks a place there, by its numbers.

   And the forecast (Weather, Weather_panel), of the place marked or of the
   window's centre: w opens it and closes it, Escape too, it follows the
   place, and it is asked again only after a quarter of an hour.

   The store keeps a hundred tiles or so, in memory, the least recently
   shown going first: three screens' worth, what a drag back finds at
   once. A tile is 256 KB as pixels, so the store is 30 MB at most. *)

type model

(* what the window needs of the system *)
type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env >

(* [initial caps flags]: from the flags lat=, lon=, zoom= (the world, by
 * default), a word (a place to find), tiles= and places= (the servers,
 * OSM's by default), forecast= (Open-Meteo by default), cache= (a directory
 * or off; the user's by default), cache-size= (in megabytes), worker=wait
 * (the tests': Map_worker.Waited). The worker is started. *)
val initial : caps -> Playground.flags -> model

(* the words on the command line, without the flags' *)
val words_of : Playground.flags -> string list

(* mini-maps weather PLACE: the place, as the Find box finds it, and its
 * forecast as lines *)
val forecast_lines : caps -> Playground.flags -> string -> (string list, string) result

val update : Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
