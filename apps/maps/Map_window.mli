(* Map_window: the map as a window, moved and zoomed.

     mouse, keys  --> where the window is: a zoom and a centre, whole pixels
                        |
                        | Tiles.in_view
                        v
                      the tiles it overlaps --> those missing --> Tile_worker
                        |                                            |
                        v                                            |
                      the store of tiles  <------- what comes --------
                        |
                        v
                      a Bitmap each, enlarged from an ancestor until its own
                      comes; and the credit, which OSM's licence asks of us

   The store keeps a hundred tiles or so, in memory, the least recently
   shown going first: three screens' worth, what a drag back finds at
   once. A tile is 256 KB as pixels, so the store is 30 MB at most. *)

type model

(* what the window needs of the system *)
type caps = < Cap.network; Cap.open_in >

(* [initial caps flags]: from the flags lat=, lon=, zoom= (the world, by
 * default), tiles= (the server, OSM's by default), worker=wait (the
 * tests': Tile_worker.Waited). The worker is started. *)
val initial : caps -> Playground.flags -> model

val update : Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
