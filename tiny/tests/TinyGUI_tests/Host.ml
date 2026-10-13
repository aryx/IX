(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyGUI.ml and TinyCalculator.ml on the host, by OCaml, with no
 * machine and no loop: the calculator's arithmetic by keys given to
 * TinyGUI's key; its buttons by a mouse given to TinyGUI's mouse, at
 * the boxes TinyGUI's laid says; what is drawn after a press (how many
 * bytes of messages: one button's); then the picture, a button held,
 * by TinyGraphics.ml, written as tiny-machine -screen writes it.
 * usage: Host.exe font1.bin out.ppm *)
open TinyCalculator

let g = calculator
let text (m : model) = (if m.op = ' ' then "" else Printf.sprintf "%d %c | " m.kept m.op) ^ if m.wrong then "error" else string_of_int m.shown
let typed s = String.fold_left (fun m c -> TinyGUI.key g m (Char.code c)) g.init s

(* the middle of the button that sends a message *)
let middle m msg =
  let ((x, y, w, h), _) = List.find (fun (_, sent) -> sent = msg) (snd (TinyGUI.laid g m TinyGUI.up)) in
  x + (w / 2), y + (h / 2)

(* a click: the mouse there with its button down, then up *)
let click (m, ms) msg =
  let x, y = middle m msg in
  let m, ms = TinyGUI.mouse g m ms x y 1 in
  TinyGUI.mouse g m ms x y 0

let written () = Buffer.length TinyCalls.drawn

let () =
  List.iter (fun s -> Printf.printf "keys %-16s %s\n" s (text (typed s)))
    [ "12*3="; "12*3=+6"; "2+3*4="; "7-9="; "9/2="; "7/0="; "7/0=5"; "7/0=c5"; "5+*3="; "5="; "999999999+1="; "99999*99999="; "31622*31622="; "1234567890" ];
  let w, h = TinyGUI.size (g.view g.init) in
  Printf.printf "the widgets ask for %d by %d\n" w h;
  let state = List.fold_left click (g.init, TinyGUI.up) [ Digit 4; Digit 2; Op '-'; Digit 2; Equals ] in
  Printf.printf "clicks 4 2 - 2 =     %s\n" (text (fst state));
  (* a press taken back: down in a button, up outside it; down outside, up in it *)
  let x, y = middle g.init (Digit 7) in
  let m, ms = TinyGUI.mouse g g.init TinyGUI.up x y 1 in
  let m, ms = TinyGUI.mouse g m ms 0 0 1 in
  let m, ms = TinyGUI.mouse g m ms 0 0 0 in
  Printf.printf "down in 7, up outside: %s, the mouse up: %b\n" (text m) (ms == TinyGUI.up);
  let m, ms = TinyGUI.mouse g m ms 0 0 1 in
  let m, ms = TinyGUI.mouse g m ms x y 1 in
  let m, ms = TinyGUI.mouse g m ms x y 0 in
  Printf.printf "down outside, up in 7: %s\n" (text m);
  (* a mouse that moves with its button up is the same mouse *)
  Printf.printf "moved, the button up: the same mouse %b\n" (snd (TinyGUI.mouse g m ms 50 50 0) == ms);
  (* the picture: 36 + 6 shown, then 7 held; what the press draws *)
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  let m = typed "12*3=+6" in
  let shown = fst (TinyGUI.laid g m TinyGUI.up) in
  TinyGUI.redraw [] shown;
  let all = written () in
  let m, ms = TinyGUI.mouse g m TinyGUI.up x y 1 in
  let held = fst (TinyGUI.laid g m ms) in
  TinyGUI.redraw shown held;
  Printf.printf "%d shapes; a press draws %d of them, %d bytes of messages for %d\n" (List.length shown)
    (List.length (List.filter Fun.id (List.map2 ( <> ) shown held))) (written () - all) all;
  TinyGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyGraphics.r = TinyGraphics.rect 0 0 640 480; at = 0xf00000; repl = false } in
  let c = TinyGraphics.connect screen (TinyGraphics.font_mask 0x1000 (TinyGraphics.alloc 16384)) in
  TinyGraphics.messages c (Buffer.contents TinyCalls.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc -> output_string oc (TinyMemory.ppm ()))
