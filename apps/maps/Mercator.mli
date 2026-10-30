(* Mercator: the Earth on a square, a latitude and a longitude to a pixel
   and back.

   Gerardus Mercator's world map of 1569 was made for sailors: a straight
   line on it keeps one compass bearing all the way, the loxodrome a ship
   can actually steer. To get that, a place's north-south distance must
   grow as fast as its east-west one does, and the meridians, which meet
   at the pole on the globe, stay parallel on the paper: at latitude phi
   everything is stretched by 1/cos phi, both ways. Adding up that
   stretch from the equator gives the height on the map:

       y = ln (tan (pi/4 + phi/2))

   Mercator drew it by hand; the formula came after him (Edward Wright's
   tables, 1599, and the logarithm, seen in them by Henry Bond around
   1645). It is why Greenland looks as large as Africa, which is fourteen
   times larger: at 72 degrees north the stretch is 3.2, and its area 10.

   The web's version (Google Maps, 2005; EPSG:3857) takes that y with the
   Earth a sphere, and cuts the map where it comes out square:

       x from -pi to pi, y from -pi to pi: the latitude where
       ln (tan (pi/4 + phi/2)) = pi, 85.0511 degrees

   which is why a web map stops short of the poles; y would go to
   infinity at 90. Keeping the map's shape was worth more than the two
   polar caps nobody asks directions to. Then the square is pixels, at a
   zoom z 256 * 2^z on a side, y growing downward as a screen's:

       longitude   -180 ............ 0 ............ 180
       x           0 .............. 128 ............ 256      (z = 0)

       latitude     85.05 .......... 0 ........... -85.05
       y            0 .............. 128 ............ 256

   Going back is the inverse function (the Gudermannian):

       phi = 2 atan (exp t) - pi/2,   t = pi (1 - 2 y / size)

   design:
   Only here are places floats. What the window keeps is whole pixels at
   the current zoom, so that a tile is drawn on whole pixels (the
   renderer's fast path), a drag moves it by exactly what the mouse did,
   and a frame is the same bytes on the two compilers (OCaml's arm64 and
   mini-ml round a*b+c differently).

   Reference: John P. Snyder, "Map Projections: A Working Manual" (USGS,
   1987), chapter 7; Mark Monmonier, "Rhumb Lines and Map Wars" (2004),
   the history, the quarrel over Greenland included. *)

(* where the map stops, north and south, in degrees *)
val max_latitude : float

(* a side of the whole world at zoom [z], in pixels: 256 * 2^z *)
val world_size : int -> int

(* [x_of_longitude z lon], [y_of_latitude z lat]: the pixel, from the
 * world's top left corner; a latitude beyond [max_latitude] is taken at it *)
val x_of_longitude : int -> float -> int
val y_of_latitude : int -> float -> int

(* and back *)
val longitude_of_x : int -> int -> float
val latitude_of_y : int -> int -> float
