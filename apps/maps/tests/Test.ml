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

let tests =
  Testo.categorize "maps"
    [
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
          tests @ Testo.categorize "maps" (cache_tests caps)))
