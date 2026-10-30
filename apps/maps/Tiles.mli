(* Tiles: the map cut in squares of 256 pixels, at every zoom.

   A map of the world at street level would be a picture of a billion
   pixels on a side; nobody can send one, and nobody looks at more than a
   window of it. So it is cut in a pyramid, each level four times the
   one above:

       z = 0     1 tile: the world
       z = 1     2 x 2
       z = 2     4 x 4
       ...
       z = 19    2^19 x 2^19: 275 billion tiles, a house about 30 pixels

     a tile's address is z/x/y, x from the left and y from the top, and
     its four children at z + 1 are (2x, 2y), (2x+1, 2y), (2x, 2y+1),
     (2x+1, 2y+1):

       +-------+         +---+---+
       | 1/0/0 |   -->   |2/0/0 2/1/0|
       |       |         |2/0/1 2/1/1|
       +-------+         +---+---+

   A window needs the tiles it overlaps and no others, some twenty at
   most on a large screen, whatever the zoom: that is the whole idea. The
   tiles are plain files, so that any web server or cache in between
   can serve them, and a program with a PNG reader can draw them.

   And what to show of a tile that has not come yet: its ancestor is
   usually there, a quarter of it (a sixteenth...) enlarged. It is coarse
   for the moment it takes, the map never blank where it was just seen.

   cs-history:
   Keyhole's EarthViewer (2001, Google Earth in 2005) streamed its
   pictures this way; MapQuest and every web map before 2005 sent one
   picture per request, the page reloaded at each click on an arrow.
   Google Maps (February 2005; Lars and Jens Rasmussen's Where 2
   Technologies) put tiles of 256 pixels side by side in a page and moved
   them with JavaScript, which is what made people say "Ajax". Quadkeys
   and the pyramid are older: image pyramids from Burt and Adelson's
   Laplacian pyramid (1983), mipmaps from Lance Williams (1983), which
   are the same structure for textures. OpenStreetMap (Steve Coast, 2004)
   gave the world's streets as data anyone may use, and z/x/y became the
   convention of everyone's tiles but Google's own.

   modern:
   Vector tiles (Mapbox's, 2014; Google's since 2013): the same pyramid,
   of streets and labels as shapes drawn by the client, so that a map
   turns and scales smoothly and is much smaller. Here they are pictures,
   which ask only a PNG reader.

   Reference: "Slippy map tilenames" on the OpenStreetMap wiki, the
   arithmetic; Burt and Adelson, "The Laplacian Pyramid as a Compact Image
   Code" (IEEE Trans. Communications, 1983). *)

val size : int

(* a tile's address *)
type key = { z : int; x : int; y : int }

(* "4/8/5" *)
val name : key -> string

(* [url base key]: "base/4/8/5.png" *)
val url : string -> key -> string

(* the highest zoom asked of a server: OSM's *)
val max_zoom : int

(* a tile of the window, and its left and top on the window *)
type placed = { key : key; left : int; top : int }

(* [in_view z cx cy w h]: the tiles a window of [w] by [h] overlaps, its
 * centre at pixel ([cx], [cy]) of the world at zoom [z], the nearest to
 * the centre first (what the eye is on is fetched first). East and west
 * wrap round, so a key may be there twice at low zoom; north and south
 * of the map there is nothing. *)
val in_view : int -> int -> int -> int -> int -> placed list

(* the same centre at another zoom, [dz] levels from [z], the world's
 * pixel that is [px], [py] from the centre of the window staying where
 * it is: (cx, cy) at z to (cx', cy') at z + dz *)
val rezoomed : dz:int -> px:int -> py:int -> int -> int -> int * int

(* [centred z cx cy h]: the centre kept on the map: east and west wrapped
 * round; north and south, the window's edge not past the world's, and the
 * world in the middle when it is smaller than the window *)
val centred : int -> int -> int -> int -> int * int

(* [ancestor key n]: the tile [n] levels above that contains [key] *)
val ancestor : key -> int -> key

(* [enlarged parent key n]: the part of [parent], [n] levels above [key],
 * that [key] covers, at the size of a tile, each pixel 2^n by 2^n *)
val enlarged : Rgba_image.t -> key -> int -> Rgba_image.t
