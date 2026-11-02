(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What the panel and the start menu decide, without a screen: Taskbar, Apps,
 * Icon, and the table of programs against the Makefile's lists of what is
 * on the card. On the screen, it is kernels/9pi/tests/win-panel.steps and
 * win-menu.steps. From the root of the repository. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())

let win ?(current = false) ?(hidden = false) ?(layer = "") id label : Taskbar.window =
  { id; label; current; hidden; layer }

let lines = Alcotest.(list string)

let test_wctl () =
  let w = Taskbar.window_of 3 "files" "          0           0         300         200 current visible " in
  (match w with
   | Some w ->
       Alcotest.(check bool) "current" true w.current;
       Alcotest.(check bool) "visible" false w.hidden;
       Alcotest.(check string) "normal" "" w.layer
   | None -> Alcotest.fail "not read");
  (match Taskbar.window_of 4 "panel" "0 728 1024 768 notcurrent hidden panel " with
   | Some w ->
       Alcotest.(check bool) "not current" false w.current;
       Alcotest.(check bool) "hidden" true w.hidden;
       Alcotest.(check string) "its layer" "panel" w.layer
   | None -> Alcotest.fail "not read");
  Alcotest.(check bool) "too short" true (Taskbar.window_of 1 "x" "1 2 3" = None)

let test_who () =
  let ws = [ win 1 "desk" ~layer:"desk"; win 2 "panel" ~layer:"panel"; win 3 "files"; win 4 "startmenu" ~layer:"popup" ~hidden:true ] in
  Alcotest.(check (list int)) "only the normal ones have a button" [ 3 ] (List.map (fun (w : Taskbar.window) -> w.id) (Taskbar.tasks ws));
  Alcotest.(check (option int)) "the menu is the popup by that label" (Some 4) (Option.map (fun (w : Taskbar.window) -> w.id) (Taskbar.menu ws))

let nums (r : Rectangle.t) = (r.min.x, r.min.y, r.max.x, r.max.y)

let test_layout () =
  let r = Rectangle.v 0 740 1000 768 in
  let parts = Taskbar.layout r [ win 1 "a"; win 2 "b" ] 40 in
  Alcotest.(check int) "start, the overview, two tasks, the clock" 5 (List.length parts);
  let widths = List.map (fun (_, r) -> Rectangle.dx r) parts in
  Alcotest.(check (list int)) "at their widths" [ 64; 28; 160; 160; 40 ] widths;
  let many = List.init 50 (fun i -> win i "x") in
  let parts = Taskbar.layout r many 40 in
  let last_task = List.nth parts 51 and clock = List.nth parts 52 in
  let _, (x0, _, _, _) = (), nums (snd clock) in
  let _, (_, _, x1, _) = (), nums (snd last_task) in
  Alcotest.(check bool) "many: narrower, none under the clock" true (x1 <= x0);
  (match Taskbar.at (Taskbar.layout r [ win 7 "a" ] 40) (Point.v 150 750) with
   | Some (Taskbar.Task w) -> Alcotest.(check int) "a point on a button" 7 w.id
   | _ -> Alcotest.fail "no task there");
  Alcotest.(check bool) "a point in the gap" true (Taskbar.at (Taskbar.layout r [] 40) (Point.v 500 750) = None)

let test_shorten () =
  let w = String.length in
  Alcotest.(check string) "it fits" "files" (Taskbar.shorten w 8 "files");
  Alcotest.(check string) "it does not" "a lo..." (Taskbar.shorten w 7 "a long label");
  Alcotest.(check string) "no room at all" "" (Taskbar.shorten w 2 "a long label")

let test_press () =
  let a = win 1 "a" ~current:true and b = win 2 "b" and h = win 3 "h" ~hidden:true in
  let ws = [ a; b; h ] in
  let line_of what part expected = Alcotest.check lines what expected (fst (Taskbar.press ws part)) in
  line_of "the one with the keyboard: hidden" (Taskbar.Task a) [ "hide -id 1" ];
  line_of "another: to the front" (Taskbar.Task b) [ "current -id 2" ];
  line_of "a hidden one: back" (Taskbar.Task h) [ "unhide -id 3" ];
  line_of "no menu: the start button does nothing" Taskbar.Start [];
  line_of "the overview: expose, in a popup" Taskbar.Overview [ "new -popup -max -label expose expose" ];
  let _, after = Taskbar.press ws (Taskbar.Task b) in
  Alcotest.(check (list bool)) "the button changes at once" [ false; true; false ] (List.map (fun (w : Taskbar.window) -> w.current) after);
  let closed = win 9 "startmenu" ~layer:"popup" ~hidden:true in
  let opened = { closed with hidden = false } in
  Alcotest.check lines "start shows the menu" [ "unhide -id 9" ] (fst (Taskbar.press [ a; closed ] Taskbar.Start));
  Alcotest.check lines "and hides it" [ "hide -id 9" ] (fst (Taskbar.press [ a; opened ] Taskbar.Start));
  Alcotest.check lines "another button: the menu goes first" [ "hide -id 9"; "hide -id 1" ] (fst (Taskbar.press [ a; opened ] (Taskbar.Task a)));
  Alcotest.check lines "the clock too" [ "hide -id 9" ] (fst (Taskbar.press [ a; opened ] Taskbar.Clock))

let read file = In_channel.with_open_bin file In_channel.input_all
let table () = Apps.parse (read "windows/desktop/apps.table")

let test_table_form () =
  let es = Apps.parse "# a comment\n\n games | Doom | face | max | doom -x\napps|Files|folder|640x480|files /usr/pad\n" in
  Alcotest.(check int) "two entries" 2 (List.length es);
  (match es with
   | [ d; f ] ->
       Alcotest.(check string) "its first word" "doom" (Apps.program d);
       Alcotest.(check bool) "all the screen" true (d.size = Apps.Max);
       Alcotest.(check bool) "a size" true (f.size = Apps.Size (640, 480));
       Alcotest.(check string) "opened whole" "new -max -label Doom doom -x" (Apps.open_line d);
       Alcotest.(check string) "opened at its size" "new -at c 640 480 -label Files files /usr/pad" (Apps.open_line f)
   | _ -> Alcotest.fail "not two");
  let label = Apps.open_line (List.hd (Apps.parse "net|Virtua Racing|x|max|virtua")) in
  Alcotest.(check string) "a label is one word" "new -max -label Virtua-Racing virtua" label;
  let bad text = match Apps.parse text with
    | _ -> Alcotest.fail ("not refused: " ^ text)
    | exception Failure _ -> () in
  bad "games|Doom|face|max";
  bad "nothing|Doom|face|max|doom";
  bad "games|Doom|face|big|doom"

let test_menu_shape () =
  let es = Apps.parse "top|T|x|max|t\ngames|A|x|max|a\ngames|B|x|max|b\ngames|C|x|max|c\ngames|D|x|max|d\ngames|E|x|max|e\n" in
  let names = List.map (function Apps.Run e -> e.Apps.name | Apps.Group (_, n) -> n | Apps.Exit -> "Exit") (Apps.left es) in
  Alcotest.(check (list string)) "top, the groups that have programs, Exit" [ "T"; "Games"; "Exit" ] names;
  Alcotest.(check int) "a group's programs" 5 (List.length (Apps.right es "games"));
  let w, h = Apps.size_of es in
  Alcotest.(check int) "both columns" (Apps.left_w + Apps.right_w) w;
  Alcotest.(check int) "as high as the longest" ((5 * Apps.row_h) + 8) h;
  Alcotest.(check int) "a row" 2 (Apps.row_at 100 (100 + (2 * Apps.row_h) + 1));
  Alcotest.(check int) "above the rows" (-1) (Apps.row_at 100 99)

(* what the Makefile says is on the card: name=$(IX9)/..., by CARD_x *)
let card () =
  let lines = String.split_on_char '\n' (read "kernels/9pi/Makefile") in
  let words l = List.filter (fun w -> w <> "") (String.split_on_char ' ' l) in
  let rec go group acc = function
    | [] -> acc
    | l :: more ->
        let g = match words l with
          | w :: "=" :: _ when String.length w > 5 && String.sub w 0 5 = "CARD_" -> String.sub w 5 (String.length w - 5)
          | _ -> group in
        let names = List.filter_map (fun w ->
            match String.index_opt w '=' with
            | Some i when i + 6 < String.length w && String.sub w i 6 = "=$(IX9" -> Some (String.sub w 0 i)
            | _ -> None) (words l) in
        go g (List.map (fun n -> (n, g)) names @ acc) more in
  go "" [] lines

(* on the card, of the groups people open, and not listed: for a reason *)
let left_out = [
  "rio"; "panel"; "startmenu"; "desk"; "expose"; "ps"; "free"; (* the desktop, or printing a state *)
  "open"; "play";                                        (* they want a file: from files *)
  "scheme"; "pascal"; "prolog"; "dotnet"; "tiger";       (* languages, from a terminal *)
  "lynx"; "curl"; "timesync";                            (* the same *)
  "hello"; "hellokbd"; "tone" ]

let test_table_and_card () =
  let on_card = card () and es = table () in
  Alcotest.(check bool) "the Makefile was understood" true (List.mem_assoc "doom" on_card);
  List.iter (fun (e : Apps.entry) ->
      let p = Apps.program e in
      (* (rc is in the kernel's image; settings comes with its program) *)
      if p <> "rc" && p <> "settings" then
        match List.assoc_opt p on_card with
        | None -> Alcotest.fail (e.name ^ ": " ^ p ^ " is not on the card")
        | Some g ->
            if e.group <> "top" && e.group <> "system" && g <> e.group then
              Alcotest.fail (Printf.sprintf "%s: its group is %s, in /progs it is %s" e.name e.group g))
    es;
  let listed = List.map Apps.program es in
  List.iter (fun (p, g) ->
      if List.mem g [ "system"; "apps"; "devtools"; "games"; "net"; "examples" ]
         && not (List.mem p listed) && not (List.mem p left_out) then
        Alcotest.fail (p ^ ", on the card's " ^ g ^ ": not in apps.table, nor in the list of those left out"))
    on_card

let test_icon () =
  (match Icon.parse "# x\na 112233\n.a\na.\n" with
   | Some i ->
       Alcotest.(check int) "wide" 2 i.w;
       Alcotest.(check int) "high" 2 i.h;
       Alcotest.(check string) "a, b, g, r; none is all zeros"
         "\000\000\000\000\255\x33\x22\x11\255\x33\x22\x11\000\000\000\000" i.pixels
   | None -> Alcotest.fail "no icon");
  Alcotest.(check bool) "rows of two widths" true (Icon.parse "a 112233\n.a\na\n" = None);
  Alcotest.(check bool) "a colour not named" true (Icon.parse "a 112233\n.b\n" = None);
  Alcotest.(check bool) "nothing" true (Icon.parse "# x\n" = None)

let desk_table () = Apps.parse (read "windows/desktop/desk.table")

let test_icons_there () =
  List.iter (fun (e : Apps.entry) ->
      let f = "windows/desktop/icons/" ^ e.icon ^ ".txt" in
      if not (Sys.file_exists f) then Alcotest.fail (e.name ^ ": no " ^ f)
      else match Icon.parse (read f) with
        | Some i -> Alcotest.(check (pair int int)) f (16, 16) (i.w, i.h)
        | None -> Alcotest.fail (f ^ ": not an icon"))
    (table () @ desk_table ())

let test_desk () =
  let on_card = card () in
  List.iter (fun (e : Apps.entry) ->
      let p = Apps.program e in
      if p <> "rc" && not (List.mem_assoc p on_card) then Alcotest.fail (e.name ^ ": " ^ p ^ " is not on the card"))
    (desk_table ());
  let screen = (0, 0, 1000, 700) in
  Alcotest.(check (list int)) "the first, near the corner" [ 8; 8; 96; 72 ]
    (let (a, b, c, d) = Apps.desk_cell screen 0 in [ a; b; c; d ]);
  Alcotest.(check int) "the next, below it" 72 (let (_, y, _, _) = Apps.desk_cell screen 1 in y);
  let per = (700 - 8) / 64 in
  Alcotest.(check int) "past the bottom: the next column" 96 (let (x, _, _, _) = Apps.desk_cell screen per in x);
  Alcotest.(check bool) "a double click" true (Apps.double_click 1000 1300);
  Alcotest.(check bool) "too slow" false (Apps.double_click 1000 1600);
  Alcotest.(check bool) "the mouse's clock went back" false (Apps.double_click 1000 900);
  match Icon.parse "a 112233\n.a\n" with
  | Some i ->
      let d = Icon.doubled i in
      Alcotest.(check (pair int int)) "doubled" (4, 2) (d.w, d.h);
      Alcotest.(check string) "each pixel four"
        (String.make 8 '\000' ^ "\255\x33\x22\x11\255\x33\x22\x11" ^ String.make 8 '\000' ^ "\255\x33\x22\x11\255\x33\x22\x11")
        d.pixels
  | None -> Alcotest.fail "no icon"

let test_prefs () =
  let p = Prefs.parse "wallpaper=picture /usr/pad/lib/sea.jpg\nclock=12\nedge=top\nswap=yes\nvolume=70\nnonsense=1\n" in
  Alcotest.(check bool) "a picture" true (p.wallpaper = Prefs.Picture "/usr/pad/lib/sea.jpg");
  Alcotest.(check string) "12 hours" "12" p.clock;
  Alcotest.(check string) "on top" "top" p.edge;
  Alcotest.(check bool) "swapped" true p.swap;
  Alcotest.(check bool) "not said: the default" false p.accelerated;
  Alcotest.(check (option int)) "the volume" (Some 70) p.volume;
  Alcotest.(check bool) "printed and read again" true (Prefs.parse (Prefs.print p) = p);
  Alcotest.(check bool) "nothing: the defaults" true (Prefs.parse "" = Prefs.default);
  Alcotest.(check bool) "a colour" true ((Prefs.parse "wallpaper=colour 6a4a7a").wallpaper = Prefs.Colour 0x6a4a7a);
  Alcotest.(check bool) "a bad one: the default" true ((Prefs.parse "clock=25\nvolume=400\n") = Prefs.default);
  Alcotest.(check string) "24 hours" "09:05" (Prefs.clock_text Prefs.default 9 5);
  Alcotest.(check string) "12: the afternoon" "1:05 pm" (Prefs.clock_text p 13 5);
  Alcotest.(check string) "12: midnight" "12:00 am" (Prefs.clock_text p 0 0);
  Alcotest.(check string) "none" "" (Prefs.clock_text { p with clock = "off" } 9 5);
  Alcotest.(check (list string)) "the mouse's lines" [ "buttonmap 321"; "linear" ] (Prefs.mouse_lines p)

let test_tiles () =
  let area = Rectangle.v 0 0 1000 700 in
  Alcotest.(check int) "none" 0 (List.length (Tiles.layout area []));
  let one = Tiles.layout area [ (1600, 1200) ] in
  (match one with
   | [ (cell, thumb, k) ] ->
       Alcotest.(check int) "one: all the area" 1000 (Rectangle.dx cell);
       Alcotest.(check int) "shrunk, a whole factor" 2 k;
       Alcotest.(check (pair int int)) "its shape kept" (800, 600) (Rectangle.dx thumb, Rectangle.dy thumb)
   | _ -> Alcotest.fail "not one");
  let five = Tiles.layout area (List.init 5 (fun _ -> (640, 480))) in
  let cells = List.map (fun (c, _, _) -> c) five in
  Alcotest.(check int) "five: three columns" 333 (Rectangle.dx (List.hd cells));
  Alcotest.(check int) "two rows" 350 (Rectangle.dy (List.hd cells));
  List.iter (fun ((c : Rectangle.t), (t : Rectangle.t), _) ->
      Alcotest.(check bool) "a thumbnail inside its cell, room for its name" true
        (t.min.x >= c.min.x && t.max.x <= c.max.x && t.min.y >= c.min.y && t.max.y + Tiles.label_h <= c.max.y)) five;
  let tiny = Tiles.layout area [ (10, 10) ] in
  Alcotest.(check bool) "a small window: not enlarged" true (match tiny with [ (_, _, k) ] -> k = 1 | _ -> false)

let test_paper () =
  (match Paper.bands 3 0x608090 with
   | [ a; _; c ] ->
       Alcotest.(check int) "the colour at the top" 0x608090 a;
       Alcotest.(check int) "a third of it at the bottom" 0x202b30 c
   | _ -> Alcotest.fail "not 3");
  (* a picture of 2 by 1, a red pixel and a blue one, made 2 by 2: the screen
   * is taller, so its width is cut, half each side: the left half of each *)
  let rgba = Bytes.of_string "\255\000\000\255\000\000\255\255" in
  let out = Paper.cover 2 1 rgba 2 2 in
  Alcotest.(check int) "four pixels" 16 (String.length out);
  Alcotest.(check string) "a pixel is b, g, r" "\000\000\255" (String.sub out 0 3);
  let wide = Paper.cover 2 1 rgba 4 2 in
  Alcotest.(check string) "the same shape: both pixels, twice" "\000\000\255" (String.sub wide 0 3);
  Alcotest.(check string) "and the blue at the right" "\255\000\000" (String.sub wide 12 3)

let () =
  Testo.interpret_argv ~project_name:"mini-desktop"
    (fun _ -> [ t "a window from what rio's wctl file says" test_wctl;
                t "which windows have a button, which is the menu" test_who;
                t "the buttons' places, with few windows and with many" test_layout;
                t "a label too long for its button" test_shorten;
                t "what a press asks of rio" test_press;
                t "the table's form, and what opens a program" test_table_form;
                t "the menu's columns and size" test_menu_shape;
                t "apps.table against what the Makefile puts on the card" test_table_and_card;
                t "an icon from its text" test_icon;
                t "each program's icon exists and is 16 by 16" test_icons_there;
                t "the desk: its table, its places, a double click, an icon doubled" test_desk;
                t "the settings' file: read, written, the clock's forms, the mouse's lines" test_prefs;
                t "the wallpaper: a colour's bands, a picture covering the screen" test_paper;
                t "expose's grid: cells, a whole factor, the windows' shapes kept" test_tiles ])
