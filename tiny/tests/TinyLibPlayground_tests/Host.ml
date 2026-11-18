(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ../../TinyAppSquare.ml on the host, by OCaml, with no machine and no loop: a model
 * after some keys and frames (the game's own functions), its shapes
 * shown by TinyLibPlayground.ml, whose messages the stub kept (TinySystemTest); then
 * KGraphics.ml draws them on KRaw's screen, written as
 * tiny-machine -screen writes it. The model's place is printed.
 * usage: Host.exe font1.bin out.ppm *)
let () =
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 KRaw.mem 0x1000 (String.length font);
  let g = TinyAppSquare.game in
  let after keys m = List.fold_left (fun m k -> g.key k m) m keys in
  let rec frames n m = if n = 0 then m else frames (n - 1) (g.frame m) in
  (* right three times, down twice, a second and a half; up against the
   * field's top *)
  let m =
    g.init 1
    |> after TinyLibPlayground.[ Right; Right; Right; Down; Down ]
    |> frames 45
    |> after (List.init 20 (fun _ -> TinyLibPlayground.Up)) in
  Printf.printf "the square at %d, %d after %d frames\n" m.x m.y m.frames;
  TinyLibSystem.write TinyLibSystem.fd_draw
    (TinyLibDraw.d_image TinyLibPlayground.picture (0, 0, g.width, g.height) 0)
  |> ignore;
  TinyLibSystem.write TinyLibSystem.fd_draw
    (TinyLibDraw.d_image TinyLibPlayground.ground (0, 0, g.width, g.height) 0)
  |> ignore;
  (* the game's shapes, then ellipses and discs: a circle's box of 21,
   * one of 20 (its last column and row left out), a wide and a tall
   * one, and boxes of no width or height (nothing); then polygons: a
   * triangle; a star of five points in one stroke, its middle a hole;
   * an arrow, which is not convex; a rectangle's corners over that
   * rectangle in red, and under it, and two triangles that share a
   * square's diagonal over that square in red (no red is left: the
   * same pixels); polygons of no, one and two points (nothing) *)
  let star = [ 30, 0; 48, 55; 1, 21; 59, 21; 12, 55 ] in
  let shapes =
    TinyLibPlayground.
      [ Move (10, 180, Disc (0xf0, 21, 21));
        Move (10, 180, Ellipse (0, 21, 21));
        Move (40, 180, Disc (0x36, 20, 20));
        Move (70, 180, Ellipse (0, 101, 41));
        Move (190, 150, Disc (0xfc, 31, 81));
        Move (240, 180, Group [ Ellipse (0, 0, 10); Disc (0, 10, 0) ]);
        Move (10, 30, Polygon (0xf0, [ 30, 0; 60, 50; 0, 50 ]));
        Move (250, 25, Polygon (0x36, star));
        Move (240, 100, Polygon (0, [ 0, 10; 40, 10; 40, 0; 60, 15; 40, 30;
                                     40, 20; 0, 20 ]));
        Move (90, 70, Rect (0xf0, 30, 20));
        Move (90, 70, Polygon (255, [ 0, 0; 30, 0; 30, 20; 0, 20 ]));
        Move (90, 100, Polygon (0xf0, [ 0, 0; 30, 0; 30, 20; 0, 20 ]));
        Move (90, 100, Rect (255, 30, 20));
        Move (130, 80, Rect (0xf0, 30, 30));
        Move (130, 80, Polygon (255, [ 0, 0; 30, 0; 0, 30 ]));
        Move (130, 80, Polygon (0x36, [ 30, 0; 30, 30; 0, 30 ]));
        Move (90, 130, Group [ Polygon (0, []); Polygon (0, [ 5, 5 ]);
                                Polygon (0, [ 0, 0; 20, 0 ]) ]);
        (* Elm's triangle, pentagon, hexagon and octagon, a disc of
         * the same radius under the last one *)
        Move (20, 140, regular 3 0xf0 14);
        Move (56, 140, regular 5 0x36 14);
        Move (92, 140, regular 6 0xfc 14);
        Move (128, 140, Disc (0, 29, 29));
        Move (128, 140, regular 8 0xf0 14) ] in
  TinyLibPlayground.show g [] (g.view m @ shapes);
  (* twice the same random numbers from a seed *)
  let rec numbers n s =
    if n = 0 then []
    else let s = TinyLibPlayground.random s in (s mod 7) :: numbers (n - 1) s in
  Printf.printf "random: %s\n"
    (String.concat " " (List.map string_of_int (numbers 12 1)));
  KGraphics.arena 0xf4b000 0xb4000;
  let screen = { KGraphics.r = KGraphics.rect 0 0 640 480;
                 at = 0xf00000; repl = false } in
  let c =
    KGraphics.connect screen
      (KGraphics.font_mask 0x1000 (String.length font)
         (KGraphics.alloc 16384)) in
  KGraphics.messages c (Buffer.contents TinySystemTest.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc ->
    output_string oc (KRaw.ppm 640 480))
