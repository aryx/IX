(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-oberon's boot (plan_system_oberon.md, stage 1: the display and
 * the fonts). On the serial line, its name and the disk's files; on
 * the screen, System.Tool in Oberon's font under a bar as a viewer's
 * menu is, and Display's patterns: what the viewers and the text
 * frames will draw with. *)

(* a line of text from the pen's place (x, the base line y); the pen's x after it *)
let draw_string (font : Fonts.t) x y s =
  let pen = ref x in
  String.iter (fun ch ->
    let c = Fonts.get font ch in
    Display.copy_pattern White c.pattern (!pen + c.x) (y + c.y) Paint;
    pen := !pen + c.dx) s;
  !pen

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
  Machine.print "mini-oberon: drawn.\n";
  Machine.halt ()
