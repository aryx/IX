(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* mini-office's menu bar under a platform with a window, which gives a
 * program several updates and then one view (the ticks due since its
 * last frame): File clicked opens its menu, and the updates that
 * follow, with no view between them, leave it open. It closed at once
 * (docs/plans/bugs/ix.md): the Gui's frame, opened by the first update
 * and closed by a view only, kept that update's mouse for the others. *)

let t = Testo.create

let test_a_menu_stays_open (caps : File_menu.caps) () =
  let c = Playground.initial_computer in
  let b = Office_edit.menu_box 0 in
  (* an update at its own time, the mouse on File *)
  let update (n : int) ~(down : bool) ~(click : bool) (m : Office_model.model) : Office_model.model =
    Office_update.update caps
      { c with time = Playground.Time (Time.millis_to_posix (n * 16)); mouse = { c.mouse with mx = b.x; my = b.y; mdown = down; mclick = click } }
      m
  in
  (* (what a view leaves: the frame closed) *)
  ignore (Gui.draw ());
  let m = { Office_model.initial with start = false } in
  let m = update 1 ~down:false ~click:false m in
  let m = update 2 ~down:true ~click:false m in
  Alcotest.(check bool) "pressed: not open yet" false (Gui.modal ());
  let m = update 3 ~down:false ~click:true m in
  Alcotest.(check bool) "released on File: its menu is open" true (Gui.modal ());
  let m = update 4 ~down:false ~click:false m in
  let m = update 5 ~down:false ~click:false m in
  Alcotest.(check bool) "and stays open through the updates that follow" true (Gui.modal ());
  ignore (Office_view.view c m);
  let _ = update 6 ~down:false ~click:false m in
  Alcotest.(check bool) "and after a view" true (Gui.modal ())

let tests (caps : File_menu.caps) = [ t "a menu clicked stays open, several updates a view" (test_a_menu_stays_open caps) ]
