(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-maps (docs/plans/plan_maps.md): the arithmetic of the
 * map, with no network; frames.sh is its window's *)

let check_int = Alcotest.(check int)
let keys (l : Tiles.placed list) : string list = List.map (fun (p : Tiles.placed) -> Tiles.name p.key) l

let tests =
  Testo.categorize "maps"
    [
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

let () = Testo.interpret_argv ~project_name:"maps" (fun _env -> tests)
