(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Square.ml on the host, by OCaml, with no machine and no loop: a model
 * after some keys and frames (the game's own functions), its shapes
 * shown by TinyPlayground.ml, whose messages TinyCalls kept; then
 * TinyGraphics.ml draws them on TinyMemory's screen, written as
 * tiny-machine -screen writes it. The model's place is printed.
 * usage: Host.exe font1.bin out.ppm *)
let () =
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  let g = Square.game in
  let after keys m = List.fold_left (fun m k -> g.key k m) m keys in
  let rec frames n m = if n = 0 then m else frames (n - 1) (g.frame m) in
  (* right three times, down twice, a second and a half; up against the field's top *)
  let m = g.init 1 |> after [ 131; 131; 131; 129; 129 ] |> frames 45 |> after (List.init 20 (fun _ -> 128)) in
  Printf.printf "the square at %d, %d after %d frames\n" m.x m.y m.frames;
  TinyCalls.u_write 3 (TinyDraw.d_image TinyPlayground.picture 0 0 g.width g.height 0) |> ignore;
  TinyCalls.u_write 3 (TinyDraw.d_image TinyPlayground.ground 0 0 g.width g.height 0) |> ignore;
  TinyPlayground.show g [] (g.view m);
  (* twice the same random numbers from a seed *)
  let rec numbers n s = if n = 0 then [] else let s = TinyPlayground.random s in (s mod 7) :: numbers (n - 1) s in
  Printf.printf "random: %s\n" (String.concat " " (List.map string_of_int (numbers 12 1)));
  TinyGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyGraphics.r = TinyGraphics.rect 0 0 640 480; at = 0xf00000; repl = false } in
  let c = TinyGraphics.connect screen (TinyGraphics.font_mask 0x1000 (TinyGraphics.alloc 16384)) in
  TinyGraphics.messages c (Buffer.contents TinyCalls.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc -> output_string oc (TinyMemory.ppm ()))
