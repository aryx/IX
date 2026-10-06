(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-oberon's boot (plan_system_oberon.md, stage 3: the texts and
 * their frames). On the serial line, its name and the disk's files; on
 * the screen, Oberon's two tracks and three viewers in them, as the
 * system opens: a log and System.Tool at the right, a text at the
 * left. Then Oberon's loop. *)

(* a tick every 10 ms, at which the USB devices are asked; the serial
 * line's characters are typed ones too *)
let tick_us = 10000

let devices () =
  Machine.wait_interrupt ();
  if Machine.timer_pending () then begin Machine.timer_arm tick_us; Usbhost.poll () end;
  let rec uart () = let c = Machine.uart_getc () in if c >= 0 then begin Input.typed (Char.chr c); uart () end in
  uart ()

let () =
  Machine.print "mini-oberon\n";
  FileDir.enumerate (fun f -> Machine.print (Printf.sprintf "%6d %s\n" f.length f.name));
  Display.init ();
  let dw = Oberon.display_width and dh = Oberon.display_height in
  Oberon.open_display (dw / 8 * 5) (dw / 8 * 3) dh;
  let viewer name commands text x y =
    MenuViewers.new_ (TextFrames.new_menu name commands) (TextFrames.new_text text 0) TextFrames.menu_h x y in
  let log = TextFrames.text "" in
  ignore (viewer "System.Log" "Edit.Locate Edit.Search System.Copy System.Grow System.Clear" log Oberon.system_track dh);
  let w = Texts.open_writer () in
  Texts.write_string w "mini-oberon"; Texts.write_ln w;
  Texts.append log w.buf;
  ignore (viewer "System.Tool" "System.Close System.Copy System.Grow Edit.Search Edit.Store" (TextFrames.text "System.Tool")
            Oberon.system_track (dh * 2 / 3));
  ignore (viewer "Welcome.Text" "System.Close System.Copy System.Grow Edit.Search Edit.Store" (TextFrames.text "Welcome.Text")
            Oberon.user_track dh);
  Usbhost.init ();
  Machine.uart_rx_enable ();
  Machine.timer_arm tick_us;
  Input.poll := devices;
  Machine.print "mini-oberon: drawn.\n";
  Oberon.loop ()
