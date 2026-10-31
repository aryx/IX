(* Map_services: what the flags say of the services and the cache, and the
   terminal's commands, which ask the same services as the window. *)

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env >

(* the words on the command line, without the flags' *)
val words_of : Playground.flags -> string list

(* the services' addresses: places=, forecast=, roads=, or the real ones *)
val places_base_of : Playground.flags -> string
val weather_base_of : Playground.flags -> string
val roads_base_of : Playground.flags -> string

(* the cache's directory: cache=DIR, or the user's; cache=off, none *)
val cache_dir : caps -> Playground.flags -> string option

(* the last places, by what was typed: the file places of the cache's
 * directory *)
val known_places : caps -> Playground.flags -> (string * Place.t) list
val save_places : caps -> Playground.flags -> (string * Place.t) list -> unit

(* [forecast_of caps base lat lon] *)
val forecast_of : < Cap.network; Cap.open_in; .. > -> string -> float -> float -> (Weather.t, string) result

(* mini-maps weather PLACE: the place, as the Find box finds it, and its
 * forecast as lines *)
val forecast_lines : caps -> Playground.flags -> string -> (string list, string) result

(* mini-maps route A to B: the way between them as lines *)
val route_lines : caps -> Playground.flags -> string -> string -> (string list, string) result
