(* Map_http: what mini-maps asks of a server, always saying who is asking:
 * OSM's services and Open-Meteo all want a User-Agent of the program's
 * own, and may block a stock one. One connection kept open, a host being
 * asked many times in a row (Keep_alive). *)

(* [get caps ~more url]: the answer, whatever its status; [more]: other
 * headers to say. Only the worker calls it. *)
val get : < Cap.network; Cap.open_in; .. > -> more:Http.header list -> string -> (Http.response, string) result
