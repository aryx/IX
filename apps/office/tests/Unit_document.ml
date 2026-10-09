(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: the author's playground's appkits/tests/Unit_document.ml; Undo's and Saved's tests only (Document and Clipboard are not here), Undo.start's limit and record's name said (docs/plans/plan_office.md) *)

(* appkits/document: what every application shares -- the versions of
 * a document, and its bytes. *)

let t = Testo.create

(* --- Undo ------------------------------------------------------------ *)

let test_the_worked_example () =
  let h = Undo.start ~limit:100 "a" in
  let h = Undo.record ~name:None "b" h in
  let h = Undo.record ~name:None "c" h in
  Alcotest.(check string) "now" "c" (Undo.now h);
  let h = Undo.undo h in
  Alcotest.(check string) "one back" "b" (Undo.now h);
  let h = Undo.undo h in
  Alcotest.(check string) "and back to the start" "a" (Undo.now h);
  Alcotest.(check bool) "nothing behind it" false (Undo.can_undo h);
  Alcotest.(check int) "two ahead" 2 (Undo.redos h);
  (* a new edit makes the branch you did not take unreachable *)
  let h = Undo.record ~name:None "d" h in
  Alcotest.(check int) "no future left" 0 (Undo.redos h);
  Alcotest.(check string) "now" "d" (Undo.now h);
  Alcotest.(check string) "and one version behind" "a" (Undo.now (Undo.undo h))

let test_names_are_for_the_menu () =
  let h = Undo.start ~limit:100 [] in
  let h = Undo.record ~name:(Some "Add Circle") [ 1 ] h in
  let h = Undo.record ~name:(Some "Adjust Diameter") [ 2 ] h in
  Alcotest.(check (option string)) "what undo would take back" (Some "Adjust Diameter") (Undo.undo_name h);
  let h = Undo.undo h in
  Alcotest.(check (option string)) "and now the one before" (Some "Add Circle") (Undo.undo_name h);
  Alcotest.(check (option string)) "with the other to put back" (Some "Adjust Diameter") (Undo.redo_name h)

(* what changes the state but is not an edit: no new version *)
let test_amend () =
  let h = Undo.record ~name:None "ab" (Undo.start ~limit:100 "a") in
  let h = Undo.amend "abc" h in
  Alcotest.(check string) "the state now" "abc" (Undo.now h);
  Alcotest.(check int) "and still one version behind" 1 (Undo.undos h);
  Alcotest.(check string) "which is where undo goes, past the amendment" "a" (Undo.now (Undo.undo h))

let test_the_oldest_versions_are_forgotten () =
  let h = ref (Undo.start ~limit:3 0) in
  for i = 1 to 10 do
    h := Undo.record ~name:None i !h
  done;
  Alcotest.(check int) "only three versions kept" 3 (Undo.undos !h);
  let back = Undo.undo (Undo.undo (Undo.undo !h)) in
  Alcotest.(check int) "as far back as it goes" 7 (Undo.now back);
  Alcotest.(check bool) "and no further" false (Undo.can_undo back)

let test_undo_at_the_ends_does_nothing () =
  let h = Undo.start ~limit:100 "only" in
  Alcotest.(check string) "nothing to undo" "only" (Undo.now (Undo.undo h));
  Alcotest.(check string) "nothing to redo" "only" (Undo.now (Undo.redo h))

(* --- Saved ------------------------------------------------------------ *)

type point = { x : float; y : float; label : string }

let test_saved_round_trip () =
  let v = [ { x = 1.; y = 2.; label = "a" }; { x = -3.5; y = 0.; label = "b\nc" } ] in
  let s = Saved.to_string ~magic:"points 1" v in
  Alcotest.(check bool) "it says what it is" true (String.sub s 0 9 = "points 1\n");
  Alcotest.(check bool) "and reads back the same" true (Saved.of_string ~magic:"points 1" s = Some v)

(* the three ways a file is not what the program expects *)
let test_saved_refuses () =
  let s = Saved.to_string ~magic:"points 1" [ { x = 1.; y = 2.; label = "a" } ] in
  Alcotest.(check bool) "another kind" true ((Saved.of_string ~magic:"sheet 1" s : point list option) = None);
  Alcotest.(check bool) "another version" true ((Saved.of_string ~magic:"points 2" s : point list option) = None);
  Alcotest.(check bool) "cut short" true
    ((Saved.of_string ~magic:"points 1" (String.sub s 0 (String.length s - 3)) : point list option) = None);
  Alcotest.(check bool) "nothing at all" true ((Saved.of_string ~magic:"points 1" "" : point list option) = None)

let tests =
  [
    t "the worked example of a history" test_the_worked_example;
    t "an edit's name is for the menu" test_names_are_for_the_menu;
    t "amending is not a new version" test_amend;
    t "the oldest versions are forgotten" test_the_oldest_versions_are_forgotten;
    t "undo and redo at the ends do nothing" test_undo_at_the_ends_does_nothing;
    t "a value saved and read back" test_saved_round_trip;
    t "a file that is not the right one is refused" test_saved_refuses;
  ]
