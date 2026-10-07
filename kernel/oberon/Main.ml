(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-oberon's boot (plan_system_oberon.md). The modules before this
 * one have started, as Oberon's do, each by its own body: the disk
 * read (FileDir), the display black (Display) and cut in two tracks
 * (Oberon), the log and System.Tool opened (System). Here: on the
 * serial line, its name and the disk's files; a text in the user's
 * track; the devices; then Oberon's loop. *)

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
  ignore (MenuViewers.new_ (TextFrames.new_menu "Welcome.Text" System.standard_menu)
            (TextFrames.new_text (TextFrames.text "Welcome.Text") 0) TextFrames.menu_h Oberon.user_track Oberon.display_height);
  Usbhost.init (fun code -> Input.typed (Char.chr (code land 255))) Input.moved;
  Machine.uart_rx_enable ();
  Machine.timer_arm tick_us;
  Input.poll := devices;
  Machine.print "mini-oberon: drawn.\n";
  Oberon.loop ()
