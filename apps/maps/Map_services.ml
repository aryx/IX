(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Map_services.mli *)

module P = Playground

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env >

let default_places = "https://nominatim.openstreetmap.org"
let default_weather = "https://api.open-meteo.com"
let default_roads = "https://overpass-api.de"

let places_base_of (flags : P.flags) : string =
  match List.assoc_opt "places" flags with Some b -> b | None -> default_places

let forecast_of (caps : < Cap.network; Cap.open_in; .. >) (base : string) (lat : float) (lon : float) : (Weather.t, string) result =
  match Map_http.get caps ~more:[] (Weather.url base lat lon) with
  | Error why -> Error why
  | Ok r when r.status <> 200 -> Error (Printf.sprintf "%d %s" r.status r.reason)
  | Ok r -> ( try Ok (Weather.of_json r.body) with Failure why -> Error why)

(* cache=DIR, or the user's; cache=off, none *)
let cache_dir (caps : caps) (flags : P.flags) : string option =
  let env (name : string) : string option =
    match CapSys.getenv caps name with "" -> None | v -> Some v | exception Not_found -> None
  in
  match (List.assoc_opt "cache" flags, env "XDG_CACHE_HOME", env "HOME", env "home") with
  | Some "off", _, _, _ -> None
  | Some dir, _, _, _ -> Some dir
  | None, Some cache, _, _ -> Some (Filename.concat cache "mini-maps")
  | None, None, Some home, _ | None, None, None, Some home -> Some (Filename.concat (Filename.concat home ".cache") "mini-maps")
  | None, None, None, None -> None

(* the last places: a file beside the cache's tiles *)
let places_file (caps : caps) (flags : P.flags) : Fpath.t option =
  Option.map (fun (dir : string) -> Fpath.v (Filename.concat dir "places")) (cache_dir caps flags)

let known_places (caps : caps) (flags : P.flags) : (string * Place.t) list =
  match Option.bind (places_file caps flags) (fun (f : Fpath.t) -> FS.read_opt caps f) with
  | None -> []
  | Some lines -> List.filter_map Place.of_line (String.split_on_char '\n' lines)

let save_places (caps : caps) (flags : P.flags) (l : (string * Place.t) list) : unit =
  let lines = String.concat "" (List.map (fun (e : string * Place.t) -> Place.to_line e ^ "\n") l) in
  match places_file caps flags with
  | None -> ()
  | Some f -> ( try FS.write caps f lines with Sys_error _ | Unix.Unix_error _ -> ())

let words_of (flags : P.flags) : string list =
  List.filter_map (fun ((k, v) : string * string) -> if v = "" && k <> "window" then Some k else None) flags

let roads_base_of (flags : P.flags) : string =
  match List.assoc_opt "roads" flags with Some b -> b | None -> default_roads

let weather_base_of (flags : P.flags) : string =
  (* (forecast=, weather being the terminal's command word, a flag too) *)
  match List.assoc_opt "forecast" flags with Some b -> b | None -> default_weather

let place_asked = ref 0.

(* the terminal's: a place from the last ones or asked of the service *)
let place_of (caps : caps) (flags : P.flags) (query : string) : (Place.t, string) result =
  let known = known_places caps flags in
  match List.assoc_opt (Place.normal query) known with
  | Some p -> Ok p
  | None -> (
      let base = places_base_of flags in
      (* (a route asks two, a second apart: the service's rule) *)
      let wait = !place_asked +. 1. -. Unix.gettimeofday () in
      if wait > 0. then Unix.sleepf wait;
      place_asked := Unix.gettimeofday ();
      match Map_http.get caps ~more:[] (Place.search_url base query) with
      | Error why -> Error why
      | Ok r when r.status <> 200 -> Error (Printf.sprintf "%d %s" r.status r.reason)
      | Ok r -> (
          match Place.of_json r.body with
          | p :: _ ->
              save_places caps flags ((Place.normal query, p) :: known);
              Ok p
          | [] -> Error (Printf.sprintf "no place called %s" query)
          | exception Failure why -> Error why))

let forecast_lines (caps : caps) (flags : P.flags) (query : string) : (string list, string) result =
  match place_of caps flags query with
  | Error why -> Error why
  | Ok p -> Result.map (Weather.lines p.name) (forecast_of caps (weather_base_of flags) p.lat p.lon)

let route_lines (caps : caps) (flags : P.flags) (from : string) (goal : string) : (string list, string) result =
  match place_of caps flags from with
  | Error why -> Error why
  | Ok a -> (
      match place_of caps flags goal with
      | Error why -> Error why
      | Ok b ->
          Result.map
            (fun ((r, plain) : Routing.t * int option) -> Routing.lines r plain)
            (Routing.find caps ~base:(roads_base_of flags) ~dir:(cache_dir caps flags) ~dijkstra:true a b))
