(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* The five parts, each saved and read back: what a part writes, its
 * own load reads as the same part (saved again, the same text). The
 * text's looks are the case to watch: its load reads a look's line
 * by hand here, where the playground's is Scanf's. *)

let t = Testo.create

(* a part saved, read by [load], saved again *)
let again (load : string -> Component.part) (p : Component.part) : string = (load (p.save ())).save ()
let same name (load : string -> Component.part) (p : Component.part) = Alcotest.(check string) name (p.save ()) (again load p)

let rich () =
  let r = Rich.of_string ~style:Style.plain "The quick brown fox\njumps" in
  let r = Rich.restyle Style.toggle_bold (Rich.select ~anchor:4 ~caret:9 r) in
  let r = Rich.restyle (fun (s : Style.t) -> { s with size = s.size *. 1.25; italic = true }) (Rich.select ~anchor:16 ~caret:22 r) in
  Rich.restyle Style.toggle_strike (Rich.select ~anchor:22 ~caret:25 r)

let test_text () =
  let p = Part_text.make (rich ()) in
  (* five looks: plain, bold, plain, bigger and italic, struck *)
  Alcotest.(check string) "its looks, then its characters"
    "5\n4 0000 16\n5 1000 16\n7 0000 16\n6 0100 20\n3 0001 16\nThe quick brown fox\njumps" (p.save ());
  same "read back" Part_text.load p;
  same "an empty text" Part_text.load (Part_text.make (Rich.of_string ~style:Style.plain ""));
  (* a command of its menu is a new part *)
  let bold = (Part_text.make (Rich.select ~anchor:0 ~caret:3 (Rich.of_string ~style:Style.plain "abc"))).command "Bold" in
  Alcotest.(check string) "Bold" "1\n3 1000 16\nabc" (bold.save ())

let test_sheet () =
  let sheet = Sheet.set (0, 1) "=A1*2" (Sheet.set (0, 0) "21" Sheet.empty) in
  same "a sheet" Part_sheet.load (Part_sheet.make ~cols:3 ~rows:5 sheet)

let test_picture () =
  let b = Bitmap.create ~width:40 ~height:30 in
  Paint.frame_oval b Pattern.solid (2, 2) (30, 25);
  Seed_fill.fill b Pattern.grey 15 12;
  same "a picture" Part_picture.load (Part_picture.make b)

let test_drawing () =
  let style : Figure.style = { fill = Some 0.5; pen = 1. } in
  let d, _ = Drawing.add (Figure.Rect (Figure.box (0., 0.) (10., 20.), style)) Drawing.empty in
  let d, _ = Drawing.add (Figure.Text (Figure.box (30., 5.) (90., 25.), "words", 12.)) d in
  let p = Part_drawing.make ~max_height:220. d in
  same "a drawing" Part_drawing.load p;
  (* its bytes are Marshal's: what is not a drawing is kept whole, a placeholder *)
  let other = Part_drawing.load "not a drawing" in
  Alcotest.(check string) "what it cannot read is kept" "not a drawing" (other.save ());
  Alcotest.(check string) "under its kind" Part_drawing.kind other.kind

let test_chart () =
  same "a chart" Part_chart.load (Part_chart.make [ ("north", 12.5); ("south", 3.); ("east", 0.) ])

(* the registry: a kind this program does not know passes through unchanged *)
let test_registry () =
  let registry : Component.registry = [ (Part_text.kind, Part_text.load); (Part_chart.kind, Part_chart.load) ] in
  let p = Component.load registry ~kind:"hologram" "bytes\nof another program" in
  Alcotest.(check (pair string string)) "kept whole" ("hologram", "bytes\nof another program") (p.kind, p.save ());
  let p = Component.load registry ~kind:Part_text.kind "1\n2 0000 16\nhi" in
  Alcotest.(check string) "a kind it knows" "1\n2 0000 16\nhi" (p.save ())

let tests =
  [
    t "the text part saved and read back, look by look" test_text;
    t "the sheet part saved and read back" test_sheet;
    t "the picture part saved and read back" test_picture;
    t "the drawing part saved and read back" test_drawing;
    t "the chart part saved and read back" test_chart;
    t "a kind nobody knows is kept whole" test_registry;
  ]
