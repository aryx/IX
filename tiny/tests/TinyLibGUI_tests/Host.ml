(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibGUI.ml and TinyAppCalculator.ml on the host, by OCaml, with no
 * machine and no loop: the calculator's arithmetic by keys given to
 * TinyLibGUI's key; its buttons by a mouse given to TinyLibGUI's mouse, at
 * the boxes TinyLibGUI's laid says; TinyAppTemperature.ml's two fields by
 * clicks and keys; what is drawn after a press (how many bytes of
 * messages: four edges'); then the picture, a button held and a field
 * with its caret, by TinyKernelGraphics.ml, written as tiny-machine -screen
 * writes it.
 * usage: Host.exe font1.bin out.ppm *)
open TinyAppCalculator

let g = calculator
let text (m : model) =
  (if m.op = ' ' then "" else Printf.sprintf "%d %c | " m.kept m.op)
  ^ if m.wrong then "error" else string_of_int m.shown
let boxes g m = snd (TinyLibGUI.laid g m)
let typed s =
  String.fold_left (fun m c ->
      TinyLibGUI.key g (boxes g m) m TinyLibGUI.up (Char.code c))
    g.init s

(* the middle of the button that sends a message *)
let middle m msg =
  let ((x, y, w, h), _) =
    List.find (fun (_, a) ->
        match a with TinyLibGUI.Send sent -> sent = msg | _ -> false)
      (boxes g m) in
  x + (w / 2), y + (h / 2)

(* a click: the mouse there with its button down, then up *)
let click (m, ms) msg =
  let x, y = middle m msg in
  let m, ms = TinyLibGUI.mouse g (boxes g m) m ms x y 1 in
  TinyLibGUI.mouse g (boxes g m) m ms x y 0

let written () = Buffer.length TinyCalls.drawn

(* the converter: a click in a field (0: Celsius, 2: Fahrenheit), keys
 * (< a backspace), the two texts after *)
let convert script =
  let t = TinyAppTemperature.temperature in
  let step (m, ms) c =
    let b = boxes t m in
    if c = 'C' || c = 'F' then begin
      let ((x, y, _, _), _) = List.nth b (if c = 'C' then 0 else 1) in
      let m, ms = TinyLibGUI.mouse t b m ms (x + 2) (y + 2) 1 in
      TinyLibGUI.mouse t b m ms (x + 2) (y + 2) 0
    end
    else TinyLibGUI.key t b m ms (if c = '<' then 8 else Char.code c), ms in
  let (m : TinyAppTemperature.model), ms =
    String.fold_left step (t.init, TinyLibGUI.up) script in
  Printf.printf "temp %-18s [%s] Celsius = [%s] Fahrenheit, %d over\n"
    script m.c m.f (List.length (TinyLibGUI.over (boxes t m) ms))

let () =
  List.iter (fun s -> Printf.printf "keys %-16s %s\n" s (text (typed s)))
    [ "12*3="; "12*3=+6"; "2+3*4="; "7-9="; "9/2="; "7/0="; "7/0=5";
      "7/0=c5"; "5+*3="; "5="; "999999999+1="; "99999*99999=";
      "31622*31622="; "1234567890" ];
  let w, h = TinyLibGUI.size (g.view g.init) in
  Printf.printf "the widgets ask for %d by %d\n" w h;
  let state =
    List.fold_left click (g.init, TinyLibGUI.up)
      [ Digit 4; Digit 2; Op '-'; Digit 2; Equals ] in
  Printf.printf "clicks 4 2 - 2 =     %s\n" (text (fst state));
  (* a press taken back: down in a button, up outside it; down outside, up in it *)
  let b = boxes g g.init in
  let x, y = middle g.init (Digit 7) in
  let m, ms = TinyLibGUI.mouse g b g.init TinyLibGUI.up x y 1 in
  Printf.printf "down in 7: %d over\n" (List.length (TinyLibGUI.over b ms));
  let m, ms = TinyLibGUI.mouse g b m ms 0 0 1 in
  Printf.printf "and out of it: %d over\n" (List.length (TinyLibGUI.over b ms));
  let m, ms = TinyLibGUI.mouse g b m ms 0 0 0 in
  Printf.printf "down in 7, up outside: %s\n" (text m);
  let m, ms = TinyLibGUI.mouse g b m ms 0 0 1 in
  let m, ms = TinyLibGUI.mouse g b m ms x y 1 in
  let m, ms = TinyLibGUI.mouse g b m ms x y 0 in
  Printf.printf "down outside, up in 7: %s\n" (text m);
  (* a mouse that moves with its button up is the same mouse *)
  Printf.printf "moved, the button up: the same mouse %b\n"
    (snd (TinyLibGUI.mouse g b m ms 50 50 0) == ms);
  (* the converter: keys with no field clicked go nowhere; a field's text and
   * the other's answer *)
  List.iter convert
    [ "12"; "C1"; "C10"; "C10x"; "C10x<"; "C100"; "C-40"; "C-"; "F32"; "F212";
      "F34"; "F0"; "C100F<<<-40"; "C1234567"; "Cq" ];
  (* the picture: 36 + 6 shown, then 7 held; what the press draws *)
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  let m = typed "12*3=+6" in
  let shown, b = TinyLibGUI.laid g m in
  TinyLibGUI.redraw [] [] shown [];
  let all = written () in
  let _, ms = TinyLibGUI.mouse g b m TinyLibGUI.up x y 1 in
  TinyLibGUI.redraw shown [] shown (TinyLibGUI.over b ms);
  Printf.printf
    "%d shapes; a press draws none of them: %d bytes of messages for %d\n"
    (List.length shown) (written () - all) all;
  (* under it, the converter, the Fahrenheit field with the keys *)
  let t = TinyAppTemperature.temperature in
  let tm = { TinyAppTemperature.c = "100"; f = "212" } in
  let shapes, tb = TinyLibGUI.laid t tm in
  let down = List.map (fun s -> TinyLibPlayground.Move (0, 200, s)) in
  let (fx, fy, _, _), _ = List.nth tb 1 in
  let over = TinyLibGUI.over tb { TinyLibGUI.up with fx; fy } in
  TinyLibGUI.redraw [] [] (down shapes)
    (List.map (fun (box, s) -> box, TinyLibPlayground.Move (0, 200, s)) over);
  TinyKernelGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyKernelGraphics.r = TinyKernelGraphics.rect 0 0 640 480;
                 at = 0xf00000; repl = false } in
  let c =
    TinyKernelGraphics.connect screen
      (TinyKernelGraphics.font_mask 0x1000 (TinyKernelGraphics.alloc 16384)) in
  TinyKernelGraphics.messages c (Buffer.contents TinyCalls.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc ->
    output_string oc (TinyMemory.ppm ()))
