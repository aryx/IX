(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyAppOrrery.ml on the host, by OCaml, with no machine: dates, the
 * planets' places, and the model after keys and frames, printed; then
 * a model's picture, by TinyLibPlayground.ml and KGraphics.ml, written
 * as tiny-machine -screen writes it.
 * usage: Host.exe font1.bin out.ppm *)
open TinyAppOrrery

module P = TinyLibPlayground
let sin = P.sin
let cos = P.cos

let () =
  (* the dates: the first day, a leap day (2000 is a leap year, being
   * a multiple of 400), a year later, the end of 2099 *)
  List.iter (fun d -> Printf.printf "day %d: %s\n" d (date d))
    [ 0; 59; 366; 36524 ];
  (* the sine and the cosine at the quarters and around them (a quarter
   * is 1024: the table's last step, read alone), then at every angle
   * of a turn, how far the point (cos, sin) is from the circle *)
  List.iter (fun a -> Printf.printf "angle %d: sin %d, cos %d\n" a (sin a) (cos a))
    [ 0; 1; 1023; 1024; 1025; 2048; 3072; 4095; 4096; -1 ];
  let worst = ref 0. in
  for a = 0 to 4095 do
    let r = Float.sqrt (float_of_int ((sin a * sin a) + (cos a * cos a))) in
    worst := Float.max !worst (Float.abs (r -. 1024.))
  done;
  Printf.printf "every angle: at most %.1f off a circle of 1024\n" !worst;
  (* each planet's place on the first day, after a quarter of its
   * period, and after a whole period (back where it was) *)
  List.iter (fun (p : planet) ->
      let show d = let (x, y) = place p d in Printf.sprintf "%d,%d" x y in
      Printf.printf "%s: %s, %s, %s\n" p.name (show 0) (show (p.period / 4))
        (show p.period))
    planets;
  (* the keys: faster twice, a frame, paused, a frame, slower, back to
   * 2000 *)
  let g = game in
  let say s (m : model) =
    Printf.printf "%s: day %d (%s), %d a frame%s\n" s m.days (date m.days)
      m.speed (if m.paused then ", paused" else "") in
  let m = g.init 1 in
  say "start" m;
  let m = g.key P.Up (g.key P.Up m) in
  let m = g.frame m in
  say "up twice, a frame" m;
  let m = g.frame (g.key (P.Char ' ') m) in
  say "space, a frame" m;
  let m = g.frame (g.key (P.Char ' ') (g.key P.Down m)) in
  say "down, space, a frame" m;
  let m = g.key (P.Char 'r') m in
  say "r" m;
  let m = g.key P.Down (g.key P.Down (g.key P.Down m)) in
  say "down three times (one a frame at the least)" m;
  (* the picture on 2001-09-14, day 622, and its ground drawn once:
   * the ground of the next frame is the very same value *)
  let m = { m with days = 622 } in
  Printf.printf "the ground the same value at the next frame: %b\n"
    (List.hd (g.view m) == List.hd (g.view (g.frame m)));
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 KRaw.mem 0x1000 (String.length font);
  TinyLibSystem.write TinyLibSystem.fd_draw
    (TinyLibDraw.d_image P.picture (0, 0, g.width, g.height) 0
     ^ TinyLibDraw.d_image P.ground (0, 0, g.width, g.height) 0);
  P.show g [] (g.view m);
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
