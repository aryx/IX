(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-oberon's boot (plan_system_oberon.md, stage 1: the display and
 * the fonts; stage 2's start: the mouse and the keys). On the serial
 * line, its name and the disk's files; on the screen, System.Tool in
 * Oberon's font under a bar as a viewer's menu is, and Display's
 * patterns: what the viewers and the text frames will draw with. Then
 * a loop as Oberon's will be: the arrow follows the mouse, a key of
 * the mouse held leaves a trace, what is typed is drawn on a line (and
 * said on the serial line at its end, for the tests). *)

(* a line of text from the pen's place (x, the base line y); the pen's x after it *)
let draw_string (font : Fonts.t) x y s =
  let pen = ref x in
  String.iter (fun ch ->
    let c = Fonts.get font ch in
    Display.copy_pattern White c.pattern (!pen + c.x) (y + c.y) Paint;
    pen := !pen + c.dx) s;
  !pen

(* the arrow, its tip at the mouse (Oberon.FlipArrow): drawn by
 * inverting, so drawn again it is gone *)
let flip_arrow (x, y) = Display.copy_pattern White Display.arrow (min x (Display.width - 15)) (max y 14 - 14) Invert

(* a tick every 10 ms, at which the USB devices are asked; the serial
 * line's characters are typed ones too *)
let tick_us = 10000

let devices () =
  if Machine.timer_pending () then begin Machine.timer_arm tick_us; Usbhost.poll () end;
  let rec uart () = let c = Machine.uart_getc () in if c >= 0 then begin Input.typed (Char.chr c); uart () end in
  uart ()

let loop (font : Fonts.t) =
  let arrow = ref None in
  let pen = ref 22 and line = Buffer.create 80 in
  Machine.timer_arm tick_us;
  while true do
    Machine.wait_interrupt ();
    devices ();
    let keys, x, y = Input.mouse () in
    if !arrow <> Some (x, y) || keys <> 0 then begin
      Option.iter flip_arrow !arrow;
      if keys <> 0 then Display.repl_const White x y 2 2 Paint;
      flip_arrow (x, y);
      arrow := Some (x, y)
    end;
    while Input.available () > 0 do
      let ch = Input.read () in
      if ch = '\r' || ch = '\n' then begin
        Machine.print (Printf.sprintf "mini-oberon: typed %s.\n" (Buffer.contents line));
        Buffer.clear line
      end
      else begin
        Buffer.add_char line ch;
        Option.iter flip_arrow !arrow;
        pen := draw_string font !pen 150 (String.make 1 ch);
        Option.iter flip_arrow !arrow
      end
    done
  done

let () =
  Machine.print "mini-oberon\n";
  FileDir.init ();
  FileDir.enumerate (fun f -> Machine.print (Printf.sprintf "%6d %s\n" f.length f.name));
  Display.init ();
  let font = Fonts.default () in
  let top = Display.height - font.height in
  (* a menu's bar: its text, then the whole line inverted *)
  ignore (draw_string font 8 (top - font.min_y) "System.Tool | System.Close System.Copy System.Grow Edit.Search Edit.Store");
  Display.repl_const White 0 top Display.width font.height Invert;
  (* the text, a line under the other (a line's end is a CR) *)
  (match Files.old "System.Tool" with
   | None -> ()
   | Some f ->
       let text = Bytes.sub_string f.data 0 f.length in
       List.iteri (fun i line -> ignore (draw_string font 22 (top - ((i + 2) * font.height) - font.min_y) line))
         (String.split_on_char '\r' text));
  (* the other fonts, a line each *)
  List.iteri (fun i name ->
    let f = Fonts.this name in
    ignore (draw_string f 500 (top - 40 - (i * 30)) (name ^ ": The quick brown fox jumps over the lazy dog")))
    [ "Oberon8.Scn.Fnt"; "Oberon10i.Scn.Fnt"; "Oberon10b.Scn.Fnt"; "Oberon12.Scn.Fnt"; "Oberon12b.Scn.Fnt"; "Oberon16.Scn.Fnt" ];
  (* the patterns; a grey area; a block copied; a frame of lines and dots *)
  List.iteri (fun i p -> Display.copy_pattern White p (500 + (i * 30)) 300 Invert)
    [ Display.arrow; Display.star; Display.hook; Display.updown; Display.block; Display.cross ];
  Display.repl_const White 500 200 200 60 Replace;
  Display.repl_pattern White Display.grey 520 210 160 40;
  Display.copy_block 500 200 200 60 760 230;
  Display.repl_const White 20 20 400 1 Replace;
  Display.repl_const White 20 20 1 100 Replace;
  for i = 0 to 39 do Display.dot White (30 + (i * 8)) (30 + i) Paint done;
  Usbhost.init ();
  Machine.uart_rx_enable ();
  Machine.print "mini-oberon: drawn.\n";
  loop font
