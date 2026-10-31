(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What the panel decides, without a screen: Taskbar. On the screen, it is
 * kernels/9pi/tests/win-panel.steps. *)

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

let () =
  Testo.interpret_argv ~project_name:"mini-desktop"
    (fun _ -> [ t "a window from what rio's wctl file says" test_wctl;
                t "which windows have a button, which is the menu" test_who;
                t "the buttons' places, with few windows and with many" test_layout;
                t "a label too long for its button" test_shorten;
                t "what a press asks of rio" test_press ])
