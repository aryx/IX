(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyOffice's test (TinyOffice_test.sh): a page worked at with the
 * keys and the mouse, with no screen and no file, and after each scene
 * what it shows: each shape of the view (the ground, an object's, the
 * status line's) on a line, its rectangles and words after.
 * A page of 320 by 200 pixels. The same file is built by OCaml and by
 * tiny-ml for tiny-cpu: the same lines. A control key is its byte in a
 * string, as in TinyEditorScreen's test. *)
open TinyEditorScreen
open TinyOffice

open TinyLibDraw

(* a shape's leaves at their places: "rect colour x y w h", "words
 * colour x y |text|" *)
let rec leaves x y s acc =
  match s with
  | Move (dx, dy, s) -> leaves (x + dx) (y + dy) s acc
  | Group l -> List.fold_right (fun s acc -> leaves x y s acc) l acc
  | Rect (c, w, h) -> ("rect " ^ string_of_int c ^ " " ^ string_of_int x ^ " " ^ string_of_int y ^ " " ^ string_of_int w ^ " " ^ string_of_int h, w > 1 && h > 1) :: acc
  | Words (c, t) -> ("words " ^ string_of_int c ^ " " ^ string_of_int x ^ " " ^ string_of_int y ^ " |" ^ t ^ "|", true) :: acc

(* each shape of the view, its leaves after, without the frames' lines
 * (rectangles a pixel wide, the same each time) to keep it short *)
let show what o =
  print_string ("== " ^ what); print_newline ();
  List.iteri (fun i s ->
    print_string ("  shape " ^ string_of_int i); print_newline ();
    List.iter (fun (l, shown) -> if shown then (print_string ("    " ^ l); print_newline ())) (leaves 0 0 s [])) (view o)

let file what o = print_string ("== " ^ what ^ ": the file"); print_newline (); print_string (text o); print_string "--"; print_newline ()

let keys o s =
  let last = ref Continue in
  String.iter (fun c -> last := key o (Char.code c)) s;
  match !last with
  | Continue -> ()
  | Save -> print_string "asks: save"; print_newline ()
  | Quit -> print_string "asks: quit"; print_newline ()

(* a click of a button at (x, y): pressed, then let go *)
let click o b x y = mouse o x y b; mouse o x y 0
let drag o b x y x' y' = mouse o x y b; mouse o x' y' b; mouse o x' y' 0

let () =
  let o = create 320 200 "notes" "" in
  show "an empty page" o;
  click o 1 20 30;
  keys o "\015# A title\n\nSome *bold words* and plain ones, more than a line holds.";
  show "a click at 20 30, C-o, a heading and a paragraph typed: being edited" o;
  click o 1 300 150;
  show "a click elsewhere: the box shows its text filled" o;
  file "the page" o;
  drag o 4 30 40 130 60;
  show "the right button drags the box 100 right, 20 down" o;
  drag o 4 317 131 237 141;
  show "from its corner: 80 narrower, 10 taller" o;
  keys o "\031";
  show "C-_: the resize undone" o;
  keys o "\024\003";
  show "C-x C-c, not saved: refused" o;
  keys o "\024\019";
  saved o;
  show "C-x C-s, and the program says it wrote" o;
  keys o "\024\003"

let () =
  let page = "text 10 10 150 52 11\nhello there\ntext 100 20 120 52 3\ntop\n" in
  let o = create 320 200 "two" page in
  show "a page of two boxes, from its file" o;
  click o 1 110 24;
  show "a click where they overlap: the top one is edited, its cursor where the click was" o;
  keys o "\005!";
  click o 1 5 190;
  show "C-e, a ! typed, a click outside" o;
  click o 1 12 12;
  keys o "\005\024\019";
  show "the other edited: C-x C-s while editing asks to save" o;
  click o 1 5 190;
  click o 1 12 12;
  click o 1 5 190;
  mouse o 20 20 4; mouse o 20 20 0;
  keys o "\127";
  show "the right button selects a box, Backspace removes it" o;
  keys o "\031\031";
  show "C-_ twice: back to the edit of the !" o;
  file "now" o
