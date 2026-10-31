(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-maps (docs/plans/plan_maps.md): the arithmetic of the
 * map, with no network; frames.sh is its window's *)

let check_int = Alcotest.(check int)
let keys (l : Tiles.placed list) : string list = List.map (fun (p : Tiles.placed) -> Tiles.name p.key) l

let cache_tests (caps : < Cap.open_in; Cap.open_out; .. >) =
  let lifetime (headers : Http.header list) : float option = Tile_cache.lifetime ~now:1000. headers in
  let check = Alcotest.(check (option (float 0.))) in
  [
    Testo.create "Tile_cache: how long an answer is good" (fun () ->
        check "max-age" (Some 1060.) (lifetime [ ("Cache-Control", "public, max-age=60") ]);
        check "less what a proxy used" (Some 1050.) (lifetime [ ("cache-control", "max-age=60"); ("Age", "10") ]);
        check "Expires, the old way" (Some 86400.) (lifetime [ ("Expires", "Fri, 02 Jan 1970 00:00:00 GMT") ]);
        check "max-age first" (Some 1060.) (lifetime [ ("Expires", "Fri, 02 Jan 1970 00:00:00 GMT"); ("Cache-Control", "max-age=60") ]);
        check "no-cache: asked each time" (Some 0.) (lifetime [ ("Cache-Control", "no-cache, max-age=60") ]);
        check "no-store: not kept" None (lifetime [ ("Cache-Control", "no-store") ]);
        check "nothing said: asked each time" (Some 0.) (lifetime []));
    Testo.create "Tile_cache: the least recently used goes first, across runs" (fun () ->
        let dir = Filename.temp_file "tile_cache" "" in
        Sys.remove dir;
        let entry : Tile_cache.entry = { bytes = String.make 400 'x'; expires = 5.; etag = Some "\"t\"" } in
        let opened () : Tile_cache.t =
          match Tile_cache.create caps ~dir ~limit:1000 with Some c -> c | None -> Alcotest.fail "no cache"
        in
        let c = opened () in
        Tile_cache.put c "1/0/0" entry;
        Tile_cache.put c "1/0/1" entry;
        (match Tile_cache.find c "1/0/0" with
        | Some e ->
            Alcotest.(check string) "its bytes" entry.bytes e.bytes;
            Alcotest.(check (option string)) "its version" entry.etag e.etag;
            Alcotest.(check (float 0.)) "until when" 5. e.expires
        | None -> Alcotest.fail "not kept");
        Tile_cache.put c "1/1/0" entry;
        Alcotest.(check bool) "the one not used since is gone" true (Tile_cache.find c "1/0/1" = None);
        Alcotest.(check bool) "the one used stays" true (Tile_cache.find c "1/0/0" <> None);
        check_int "two left" 2 (fst (Tile_cache.size c));
        (* (the uses, saved at the last trim) *)
        check_int "the index read again" 2 (fst (Tile_cache.size (opened ())));
        ignore (Sys.command ("rm -rf " ^ Filename.quote dir)));
  ]

let forecast_text = {|{"current":{"time":"2026-10-30T20:30","temperature_2m":-0.4,"weather_code":61,"wind_speed_10m":12.7},
  "hourly":{"time":["2026-10-30T20:00","2026-10-30T21:00"],"temperature_2m":[10.5,9]},
  "daily":{"time":["2026-10-31"],"weather_code":[95],"temperature_2m_max":[15.8],"temperature_2m_min":[5],"precipitation_sum":[2.25]}}|}

(* a grid of [n] by [n] streets, one in [every] a faster road, as Overpass
 * says it: ids past 2^31, as OSM's are *)
let grid_text (n : int) (every : int) : string =
  let id (x : int) (y : int) : int = 5_000_000_000 + (x * n) + y in
  let node (x : int) (y : int) : string =
    Printf.sprintf {|{"type":"node","id":%d,"lat":%f,"lon":%f}|} (id x y)
      (47. +. (float_of_int y *. 0.001))
      (0.7 +. (float_of_int x *. 0.001))
  in
  let way (i : int) (a : int) (b : int) : string =
    Printf.sprintf {|{"type":"way","id":%d,"nodes":[%d,%d],"tags":{"highway":"%s"}}|} i a b
      (if i mod every = 0 then "primary" else "residential")
  in
  let all = List.init n (fun (x : int) -> x) in
  let each (f : int -> int -> string option) : string list =
    List.concat_map (fun (x : int) -> List.filter_map (f x) all) all
  in
  let elements =
    each (fun (x : int) (y : int) -> Some (node x y))
    @ each (fun (x : int) (y : int) ->
          if x + 1 < n then Some (way ((x * n) + y) (id x y) (id (x + 1) y)) else None)
    @ each (fun (x : int) (y : int) ->
          if y + 1 < n then Some (way ((n * n) + (x * n) + y) (id x y) (id x (y + 1))) else None)
  in
  Printf.sprintf {|{"elements":[%s]}|} (String.concat "," elements)

let route_tests =
  [
    Testo.create "Json: an integer too big for the machine's int stays a number" (fun () ->
        Alcotest.(check (float 0.)) "OSM's ids" 11197711196.
          (Json.float (Json.of_text "11197711196"));
        Alcotest.(check (float 0.)) "past 63 bits" 1e20
          (Json.float (Json.of_text "100000000000000000000")));
    Testo.create "Roads: a way's directions, and what is not a car's" (fun () ->
        let g = Roads.of_json {|{"elements":[
          {"type":"node","id":1,"lat":47,"lon":0.7},
          {"type":"node","id":2,"lat":47,"lon":0.71},
          {"type":"node","id":3,"lat":47,"lon":0.72},
          {"type":"node","id":4,"lat":47,"lon":0.73},
          {"type":"way","id":1,"nodes":[1,2],"tags":{"highway":"residential"}},
          {"type":"way","id":2,"nodes":[2,3],"tags":{"highway":"residential","oneway":"yes"}},
          {"type":"way","id":3,"nodes":[3,4],"tags":{"highway":"motorway"}},
          {"type":"way","id":4,"nodes":[4,1],"tags":{"highway":"footway"}}]}|} in
        check_int "both ways, one, a motorway's one, none" 4 (Array.length g.target);
        Alcotest.(check (float 0.1)) "the fastest: 110 km/h" (110. /. 3.6) g.top_speed);
    Testo.create "Roads: a long box does without the residential streets" (fun () ->
        let asks (box : float * float * float * float) : bool =
          let u = Roads.url "http://x" box in
          let word = "residential" in
          let rec has (i : int) : bool =
            i + String.length word <= String.length u
            && (String.sub u i (String.length word) = word || has (i + 1))
          in
          has 0
        in
        Alcotest.(check bool) "a town" true (asks (47.3, 0.6, 47.38, 0.68));
        Alcotest.(check bool) "a long way" false (asks (47.3, 0.6, 47.4, 1.0)));
    Testo.create "Roads: what is not an answer" (fun () ->
        Alcotest.check_raises "no JSON" (Failure "unexpected 'x' at 0") (fun () ->
            ignore (Roads.of_json "x")));
    Testo.create "Route: A* costs what Dijkstra costs, settling fewer" (fun () ->
        let g = Roads.of_json (grid_text 30 5) in
        check_int "its nodes" 900 (Array.length g.lat);
        let pairs = [ (0, 899); (14, 800); (435, 3); (29, 870); (100, 101) ] in
        List.iter
          (fun ((a, b) : int * int) ->
            match (Route.search g ~guess:true a b, Route.search g ~guess:false a b) with
            | Some astar, Some plain ->
                check_int "the same cost" plain.millis astar.millis;
                Alcotest.(check bool) "no more nodes" true (astar.settled <= plain.settled);
                (* (the path is one, from a to b, costing what it says) *)
                let sum = List.fold_left (fun (s : int) (e : int) -> s + g.millis.(e)) 0 astar.edges in
                check_int "its edges' cost" astar.millis sum;
                check_int "it starts there" a g.origin.(List.hd astar.edges);
                check_int "it ends there" b g.target.(List.hd (List.rev astar.edges))
            | _ -> Alcotest.fail "no way in a grid")
          pairs);
    Testo.create "Route: from a node to itself, and to one unreachable" (fun () ->
        let g = Roads.of_json {|{"elements":[
          {"type":"node","id":1,"lat":47,"lon":0.7},
          {"type":"node","id":2,"lat":47,"lon":0.71},
          {"type":"way","id":1,"nodes":[1,2],"tags":{"highway":"primary","oneway":"yes"}}]}|} in
        (match Route.search g ~guess:true 0 0 with
        | Some r -> check_int "no time at all" 0 r.millis
        | None -> Alcotest.fail "a node reaches itself");
        Alcotest.(check bool) "against the one-way" true (Route.search g ~guess:true 1 0 = None));
    Testo.create "Roads: the nearest node, on the largest piece" (fun () ->
        let g = Roads.of_json {|{"elements":[
          {"type":"node","id":1,"lat":47,"lon":0.7},
          {"type":"node","id":2,"lat":47,"lon":0.71},
          {"type":"node","id":3,"lat":47,"lon":0.72},
          {"type":"node","id":4,"lat":47.5,"lon":0.7},
          {"type":"node","id":5,"lat":47.5,"lon":0.71},
          {"type":"way","id":1,"nodes":[1,2,3],"tags":{"highway":"primary"}},
          {"type":"way","id":2,"nodes":[4,5],"tags":{"highway":"primary"}}]}|} in
        match Roads.nearest g 47.5 0.7 with
        | Some (n, far) ->
            check_int "the big piece's" 0 n;
            Alcotest.(check bool) "far away" true (far > 50_000.)
        | None -> Alcotest.fail "no node");
  ]

let tests =
  Testo.categorize "maps"
    [
      Testo.create "Weather: Open-Meteo's columns" (fun () ->
          let f = Weather.of_json forecast_text in
          Alcotest.(check (float 0.)) "now" (-0.4) f.temperature;
          check_int "its hours" 2 (List.length f.hours);
          Alcotest.(check (float 0.)) "an integer in a column of floats" 9. (snd (List.nth f.hours 1));
          (match f.days with
          | [ d ] -> Alcotest.(check (float 0.)) "a day's low" 5. d.low
          | _ -> Alcotest.fail "one day expected"));
      Testo.create "Weather: what is no forecast" (fun () ->
          let fails (s : string) : bool = match Weather.of_json s with _ -> false | exception Failure _ -> true in
          Alcotest.(check bool) "an error page" true (fails "<html>");
          Alcotest.(check bool) "the service's error" true (fails {|{"error":true,"reason":"bad"}|});
          Alcotest.(check bool) "columns that differ" true
            (fails {|{"current":{"time":"t","temperature_2m":1,"weather_code":0,"wind_speed_10m":1},"hourly":{"time":["a"],"temperature_2m":[]},"daily":{"time":[],"weather_code":[],"temperature_2m_max":[],"temperature_2m_min":[],"precipitation_sum":[]}}|}));
      Testo.create "Weather: the WMO's codes" (fun () ->
          let kind = Alcotest.testable (fun fmt (_ : Weather.kind) -> Format.pp_print_string fmt "kind") ( = ) in
          Alcotest.check kind "clear" Weather.Clear (Weather.kind 0);
          Alcotest.check kind "fog" Weather.Fog (Weather.kind 48);
          Alcotest.check kind "showers are rain" Weather.Rain (Weather.kind 81);
          Alcotest.check kind "snow showers are snow" Weather.Snow (Weather.kind 85);
          Alcotest.check kind "a thunderstorm" Weather.Storm (Weather.kind 99);
          Alcotest.check kind "a code unknown: clouds" Weather.Overcast (Weather.kind 42);
          Alcotest.(check string) "its words" "code 42" (Weather.words 42));
      Testo.create "Weather: days and degrees, as said" (fun () ->
          Alcotest.(check string) "a Saturday" "Sat 31" (Weather.day_name "2026-10-31");
          Alcotest.(check string) "no minus zero" "0\xc2\xb0" (Weather.degrees (-0.4));
          Alcotest.(check string) "rounded" "-2\xc2\xb0" (Weather.degrees (-1.6));
          Alcotest.(check (list string)) "the terminal's lines"
            [ "Tours"; "2026-10-30T20:30: 0\xc2\xb0, slight rain, wind 13 km/h";
              "Sat 31  5\xc2\xb0 to 16\xc2\xb0, thunderstorm, 2.2 mm";
              "Weather data by Open-Meteo.com (CC BY 4.0)" ]
            (Weather.lines "Tours" (Weather.of_json forecast_text)));
      Testo.create "Json: floats, and what stays an integer" (fun () ->
          let j = Json.of_text {|{"a": 3, "b": -1.5, "c": 2e3, "d": 1.5E-1, "e": [0.5, 7]}|} in
          check_int "an integer stays" 3 (Json.int (Json.member "a" j));
          Alcotest.(check (float 0.)) "a fraction" (-1.5) (Json.float (Json.member "b" j));
          Alcotest.(check (float 0.)) "an exponent" 2000. (Json.float (Json.member "c" j));
          Alcotest.(check (float 1e-12)) "and negative" 0.15 (Json.float (Json.member "d" j));
          Alcotest.(check (float 0.)) "an integer read as a float" 3. (Json.float (Json.member "a" j));
          Alcotest.(check string) "written back" {|[1.5,2]|} (Json.to_text (Json.List [ Json.Float 1.5; Json.Int 2 ])));
      Testo.create "Place: Nominatim's answer, numbers as strings" (fun () ->
          match
            Place.of_json
              {|[{"lat":"47.39","lon":"0.68","display_name":"Tours, France","boundingbox":["47.34","47.44","0.65","0.74"]}]|}
          with
          | [ p ] ->
              Alcotest.(check string) "the name" "Tours, France" p.name;
              Alcotest.(check (float 0.)) "the latitude" 47.39 p.lat;
              check_int "a town: as near as its box fits" 12 (Place.zoom_for ~at_most:14 p 800 600)
          | _ -> Alcotest.fail "one place expected");
      Testo.create "Place: nothing found, and what is no answer" (fun () ->
          check_int "none" 0 (List.length (Place.of_json "[]"));
          Alcotest.check_raises "not JSON" (Failure "unexpected '<' at 0") (fun () -> ignore (Place.of_json "<html>")));
      Testo.create "Place: a line of the file and back" (fun () ->
          let p : Place.t = { name = "Tours, France"; lat = 47.39; lon = 0.68; box = Some (47.34, 47.44, 0.65, 0.74) } in
          (match Place.of_line (Place.to_line ("tours", p)) with
          | Some (q, back) ->
              Alcotest.(check string) "the query" "tours" q;
              Alcotest.(check bool) "the place" true (back = p)
          | None -> Alcotest.fail "not read back");
          Alcotest.(check bool) "not a line" true (Place.of_line "junk" = None);
          Alcotest.(check string) "a query compared" "tours" (Place.normal "  Tours "));
      Testo.create "Mercator: known places at zoom 0" (fun () ->
          check_int "the equator" 128 (Mercator.y_of_latitude 0 0.);
          check_int "the prime meridian" 128 (Mercator.x_of_longitude 0 0.);
          check_int "the map's top" 0 (Mercator.y_of_latitude 0 Mercator.max_latitude);
          check_int "past the top, the top" 0 (Mercator.y_of_latitude 0 89.9);
          check_int "the date line" 0 (Mercator.x_of_longitude 0 (-180.)));
      Testo.create "Mercator: the OSM wiki's tile for Tours' longitude and latitude" (fun () ->
          (* (the formula of "Slippy map tilenames", at zoom 12) *)
          check_int "x" 2055 (Mercator.x_of_longitude 12 0.69 / 256);
          check_int "y" 1434 (Mercator.y_of_latitude 12 47.39 / 256));
      Testo.create "Mercator: a pixel to a place and back" (fun () ->
          let z = 12 in
          List.iter
            (fun ((x, y) : int * int) ->
              check_int "x" x (Mercator.x_of_longitude z (Mercator.longitude_of_x z x +. 1e-9));
              check_int "y" y (Mercator.y_of_latitude z (Mercator.latitude_of_y z y -. 1e-9)))
            [ (526000, 380000); (0, 1000); (1048575, 1048000) ]);
      Testo.create "Tiles: a window's tiles, the nearest first" (fun () ->
          Alcotest.(check (list string)) "the world's one, a window inside it" [ "0/0/0" ]
            (keys (Tiles.in_view 0 128 128 100 100));
          Alcotest.(check (list string)) "four at the corner of four" [ "1/0/0"; "1/0/1"; "1/1/0"; "1/1/1" ]
            (List.sort compare (keys (Tiles.in_view 1 256 256 100 100)));
          (match Tiles.in_view 2 256 256 256 256 with
          | p :: _ ->
              check_int "the tile at the centre, its left" 128 p.left;
              check_int "its top" 128 p.top;
              Alcotest.(check string) "and its name" "2/1/1" (Tiles.name p.key)
          | [] -> Alcotest.fail "no tile"));
      Testo.create "Tiles: east and west wrap, north and south end" (fun () ->
          Alcotest.(check (list string)) "left of the world, the other side" [ "1/0/0"; "1/0/1"; "1/1/0"; "1/1/1" ]
            (List.sort compare (keys (Tiles.in_view 1 0 256 100 100)));
          let above = Tiles.in_view 1 256 (-1000) 100 100 in
          check_int "nothing above the map" 0 (List.length above);
          Alcotest.(check (pair int int)) "the centre wrapped" (10, 256) (Tiles.centred 1 522 256 100);
          Alcotest.(check (pair int int)) "kept on the map" (10, 50) (Tiles.centred 1 10 (-20) 100);
          Alcotest.(check (pair int int)) "a world smaller than the window, in the middle" (10, 128) (Tiles.centred 0 10 7 800));
      Testo.create "Tiles: zooming about a point keeps it where it is" (fun () ->
          let cx, cy = Tiles.rezoomed ~dz:1 ~px:50 ~py:(-30) 300 200 in
          check_int "the point's x, doubled" ((300 + 50) * 2) (cx + 50);
          check_int "its y" ((200 - 30) * 2) (cy - 30);
          let bx, by = Tiles.rezoomed ~dz:(-1) ~px:50 ~py:(-30) cx cy in
          Alcotest.(check (pair int int)) "and back" (300, 200) (bx, by));
      Testo.create "Tiles: an ancestor and the part of it enlarged" (fun () ->
          Alcotest.(check string) "two levels up" "2/2/1" (Tiles.name (Tiles.ancestor { z = 4; x = 11; y = 7 } 2));
          let parent = Rgba_image.create ~width:256 ~height:256 in
          (* the parent's pixel (128, 0), the top left of the child (1, 0) *)
          Bytes.set parent.rgba (4 * 128) 'A';
          let child = Tiles.enlarged parent { z = 1; x = 1; y = 0 } 1 in
          Alcotest.(check char) "the pixel, 2 by 2" 'A' (Bytes.get child.rgba 4);
          Alcotest.(check char) "and no further" '\000' (Bytes.get child.rgba 8));
    ]

let () =
  Cap.main (fun caps ->
      Testo.interpret_argv ~project_name:"maps" (fun _env ->
          tests @ Testo.categorize "maps" (route_tests @ cache_tests caps)))
