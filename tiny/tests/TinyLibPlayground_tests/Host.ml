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
  TinyLibPlayground.show g [] (g.view m);
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
