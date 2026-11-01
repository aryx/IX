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
  Alcotest.(check int) "start, two tasks, the clock" 4 (List.length parts);
  let widths = List.map (fun (_, r) -> Rectangle.dx r) parts in
  Alcotest.(check (list int)) "at their widths" [ 64; 160; 160; 40 ] widths;
  let many = List.init 50 (fun i -> win i "x") in
  let parts = Taskbar.layout r many 40 in
  let last_task = List.nth parts 50 and clock = List.nth parts 51 in
  let _, (x0, _, _, _) = (), nums (snd clock) in
  let _, (_, _, x1, _) = (), nums (snd last_task) in
  Alcotest.(check bool) "many: narrower, none under the clock" true (x1 <= x0);
  (match Taskbar.at (Taskbar.layout r [ win 7 "a" ] 40) (Point.v 100 750) with
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
  "rio"; "panel"; "startmenu"; "desk"; "ps"; "free";     (* the desktop, or printing a state *)
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

let test_icons_there () =
  List.iter (fun (e : Apps.entry) ->
      let f = "windows/desktop/icons/" ^ e.icon ^ ".txt" in
      if not (Sys.file_exists f) then Alcotest.fail (e.name ^ ": no " ^ f)
      else match Icon.parse (read f) with
        | Some i -> Alcotest.(check (pair int int)) f (16, 16) (i.w, i.h)
        | None -> Alcotest.fail (f ^ ": not an icon"))
    (table ())

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
                t "each program's icon exists and is 16 by 16" test_icons_there ])
