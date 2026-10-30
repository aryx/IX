(* Place: a name to a place on the Earth, asked of Nominatim.

   Geocoding: a street map is a database of names and shapes, so a place's
   name can be looked up in it, and the answer is a latitude, a longitude
   and the box the place fills:

     GET /search?q=tours&format=jsonv2&limit=1
     [ { "lat": "47.39", "lon": "0.68", "display_name": "Tours, ...",
         "boundingbox": ["47.34", "47.44", "0.65", "0.74"] } ]

   (numbers as strings, the way the service gives them; and south, north,
   west, east, in that order, which is nobody's first guess.) The box is
   what says how far to zoom: a town and a country are not looked at from
   the same height.

   The service is run by OSM's volunteers and says what it asks: one
   request a second at most, none as the user types (a search is on Enter,
   never an autocomplete), an answer kept rather than asked again, and a
   User-Agent of our own. So the window keeps the last places, and a name
   already found is not asked again; they are in the file places of the
   cache's directory.

   cs-history:
   Nominatim ("by name", in Latin) is Brian Quinion's, for OpenStreetMap,
   from 2008 or so. Geocoding is much older: the US Census Bureau's DIME
   files (1967) gave each stretch of street its range of house numbers, to
   place the census's addresses on a map; TIGER (1989) put the whole
   country in, which is what the first web maps and, imported in 2007,
   OSM's American streets stood on.

   Reference: https://nominatim.org/release-docs/latest/api/Search/ and
   https://operations.osmfoundation.org/policies/nominatim/. *)

type t = {
  name : string; (* the name the service gives, the long one *)
  lat : float;
  lon : float;
  box : (float * float * float * float) option; (* south, north, west, east *)
}

(* [search_url base query] *)
val search_url : string -> string -> string

(* the places in the service's answer, the best first; Failure if it is not
 * such an answer *)
val of_json : string -> t list

(* the highest zoom (at most [at_most]) at which the place's box fits a
 * window of [w] by [h], [at_most] without a box *)
val zoom_for : at_most:int -> t -> int -> int -> int

(* a query and its place as a line of the file, and back; None for a line
 * that is not one *)
val to_line : string * t -> string
val of_line : string -> (string * t) option

(* the query as it is compared: "  Tours " is "tours" *)
val normal : string -> string
