(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-oberon's boot (plan_system_oberon.md, stage 2: the viewers and
 * the loop). On the serial line, its name and the disk's files; on
 * the screen, Oberon's two tracks and three viewers in them, as the
 * system opens: a log and System.Tool at the right, a text at the
 * left. Then Oberon's loop.
 *
 * The texts and their frames are the next stage's: a viewer's two
 * frames are here a few lines drawn (label, below), enough for the
 * viewers to be opened, dragged by their menu and typed in. *)

(* a line of text from the pen's place (x, the base line y); the pen's x after it *)
let draw_string (font : Fonts.t) x y mode s =
  let pen = ref x in
  String.iter (fun ch ->
    let c = Fonts.get font ch in
    Display.copy_pattern White c.pattern (!pen + c.x) (y + c.y) mode;
    pen := !pen + c.dx) s;
  !pen

(* A frame that shows lines, the first at its top: a menu's (inverse:
 * black on white) or a main frame's. In a main frame what is typed is
 * added to the last line (and, at a line's end, said on the serial
 * line: the tests read it there), and a key of the mouse held leaves
 * dots. *)
let label inverse (lines : string list) : Display.frame =
  let font = Fonts.default () in
  let lines = ref lines in
  let draw (f : Display.frame) y h =
    if h > 0 then begin
      Oberon.remove_marks f.x y f.w h;
      Display.repl_const (if inverse then Display.White else Display.Black) f.x y f.w h Replace;
      List.iteri (fun i line ->
        let base = y + h - ((i + 1) * font.height) - font.min_y in
        if base + font.min_y >= y then ignore (draw_string font (f.x + (if inverse then 3 else 8)) base (if inverse then Display.Invert else Display.Paint) line))
        !lines
    end
  in
  Display.frame (fun f m ->
    match m with
    | MenuViewers.Extend (_, y, h) | MenuViewers.Reduce (_, y, h) -> draw f y h
    | Oberon.Track (keys, x, y) ->
        if keys <> 0 && not inverse then begin Oberon.fade_mouse (); Display.repl_const White x y 2 2 Paint end;
        Oberon.draw_mouse_arrow x y
    | Oberon.Consume ch when not inverse ->
        (* (the character alone is drawn, at the last line's end: a
         * frame drawn whole at each key is too slow for the keys) *)
        let n = List.length !lines - 1 in
        let last = List.nth !lines n and before = List.filteri (fun i _ -> i < n) !lines in
        if ch = '\r' || ch = '\n' then begin
          Machine.print (Printf.sprintf "mini-oberon: typed %s.\n" last);
          lines := !lines @ [ "" ]
        end
        else begin
          lines := before @ [ last ^ String.make 1 ch ];
          let pen = ref (f.x + 8) in
          String.iter (fun c -> pen := !pen + (Fonts.get font c).dx) last;
          let pen = !pen in
          Oberon.remove_marks pen (f.y + f.h - ((n + 1) * font.height)) 16 font.height;
          ignore (draw_string font pen (f.y + f.h - ((n + 1) * font.height) - font.min_y) Display.Paint (String.make 1 ch))
        end
    | _ -> ())

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
  FileDir.init ();
  FileDir.enumerate (fun f -> Machine.print (Printf.sprintf "%6d %s\n" f.length f.name));
  Display.init ();
  let dw = Oberon.display_width and dh = Oberon.display_height in
  Oberon.open_display (dw / 8 * 5) (dw / 8 * 3) dh;
  let menu_h = (Fonts.default ()).height + 2 in
  let viewer name commands lines x y = MenuViewers.new_ (label true [ name ^ " | " ^ commands ]) (label false lines) menu_h x y in
  let tool = match Files.old "System.Tool" with Some f -> String.split_on_char '\r' (Bytes.sub_string f.data 0 f.length) | None -> [] in
  ignore (viewer "System.Log" "Edit.Locate Edit.Search System.Copy System.Grow System.Clear" [ "mini-oberon" ] Oberon.system_track dh);
  ignore (viewer "System.Tool" "System.Close System.Copy System.Grow Edit.Search Edit.Store" tool Oberon.system_track (dh * 2 / 3));
  let text = viewer "Welcome.Text" "System.Close System.Copy System.Grow Edit.Search Edit.Store"
      [ "The Oberon system, in OCaml, on the Raspberry Pi."; "";
        "A viewer's menu, dragged with the left key, moves its top;";
        "with the middle key too, the viewer goes where the mouse is.";
        "What is typed comes here:"; "" ] Oberon.user_track dh in
  Oberon.pass_focus (Some text);
  Usbhost.init ();
  Machine.uart_rx_enable ();
  Machine.timer_arm tick_us;
  Input.poll := devices;
  Machine.print "mini-oberon: drawn.\n";
  Oberon.loop ()
