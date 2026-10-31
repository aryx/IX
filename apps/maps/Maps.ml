(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-maps: a map moved and zoomed, fetched from the internet
 * (docs/plans/plan_maps.md): the program, the window being Map_window.
 *
 *   mini-maps                       the world
 *   mini-maps tours                 a place, found
 *   mini-maps lat=47.39 lon=0.69    a place, by its numbers
 *   mini-maps weather tours         the forecast as lines, for a terminal
 *   mini-maps route tours to amboise  the way between them, as lines
 *
 * Dragging moves the map, as do the arrows; the wheel, a double click,
 * + and - zoom it; / finds a place, a click marks one; w, its forecast;
 * r, a route from it to the next one marked.
 *
 * The licences. This code is LGPL; what it shows is not ours, and nothing
 * of it is in this repository (the tests' tiles and roads are made here):
 *  - the places (Nominatim), the roads (Overpass), what the tiles are drawn
 *    from: OSM's data, under the ODbL. It must be credited, and said to be
 *    under that licence; a database made from it and given to others stays
 *    under it. (OSM's page gives no licence for the tiles as pictures; its
 *    tile policy says how they may be used.)
 *  - the forecast (Open-Meteo): CC BY 4.0, to be credited. Its free service
 *    is for non-commercial use only; a product would pay for it.
 * The servers have rules of their own, apart from the licences: a real
 * User-Agent, answers kept, one request a second at most for Nominatim. They
 * are run for people and small programs, on donations for OSM's: a program
 * with many users must use tiles=, places=, roads= and forecast= to go
 * elsewhere. (Read 2026-10-31: openstreetmap.org/copyright,
 * operations.osmfoundation.org/policies, open-meteo.com/en/terms.) *)

(* the words before and after "to" *)
let rec split_at_to (before : string list) (l : string list) : (string * string) option =
  match l with
  | [] -> None
  | "to" :: after when before <> [] && after <> [] ->
      Some (String.concat " " (List.rev before), String.concat " " after)
  | w :: rest -> split_at_to (w :: before) rest

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch @@ fun () ->
      Logging.setup caps ~name:"mini-maps";
      let flags = Playground_platform.flags caps in
      let wcaps = (caps :> Map_window.caps) in
      match Map_services.words_of flags with
      | "weather" :: place ->
          if place = [] then (Console.eprint caps "usage: mini-maps weather PLACE\n"; Exit.Err "usage")
          else (
            match Map_services.forecast_lines wcaps flags (String.concat " " place) with
            | Ok lines -> List.iter (fun (l : string) -> Console.print caps (l ^ "\n")) lines; Exit.OK
            | Error why -> Exit.Err why)
      | "route" :: words -> (
          match split_at_to [] words with
          | None -> Console.eprint caps "usage: mini-maps route PLACE to PLACE\n"; Exit.Err "usage"
          | Some (from, goal) -> (
              match Map_services.route_lines wcaps flags from goal with
              | Ok lines -> List.iter (fun (l : string) -> Console.print caps (l ^ "\n")) lines; Exit.OK
              | Error why -> Exit.Err why))
      | _ ->
      (* heap=modest: tiles are kept, tens of megabytes (mini-netscape's);
       * the screen as large as the window *)
      let flags = ("heap", "modest") :: (if List.mem_assoc "window" flags then flags else ("window", "") :: flags) in
      Playground_platform.run_app caps flags
        (Playground.game Map_window.view Map_window.update (Map_window.initial wcaps flags));
      Exit.OK)
