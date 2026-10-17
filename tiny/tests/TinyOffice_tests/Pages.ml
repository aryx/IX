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

open TinyLibPlayground

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

let asked r =
  match r with
  | Continue -> ()
  | Save -> print_string "asks: save"; print_newline ()
  | Quit -> print_string "asks: quit"; print_newline ()

let keys o s =
  let last = ref Continue in
  String.iter (fun c -> last := key o (Char.code c)) s;
  asked !last

(* the mouse at (x, y), its buttons b; a click of a button at (x, y),
 * pressed, then let go; a drag, the mouse seen at its two ends and
 * between, or only at its two ends (a program busy drawing sees no
 * more) *)
let at o b x y = asked (mouse o x y b)
let click o b x y = at o b x y; at o 0 x y
let drag o b x y x' y' = at o b x y; at o b x' y'; at o 0 x' y'
let jump o b x y x' y' = at o b x y; at o 0 x' y'

let () =
  let o = create 320 200 "notes" "" in
  show "an empty page" o;
  click o 1 20 40;
  keys o "\015# A title\n\nSome *bold words* and plain ones, more than a line holds.";
  show "a click at 20 40, C-o, a heading and a paragraph typed: being edited" o;
  click o 1 300 150;
  show "a click elsewhere: the box shows its text filled" o;
  file "the page" o;
  drag o 4 30 50 130 70;
  show "the right button drags the box 100 right, 20 down" o;
  drag o 4 317 141 237 151;
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
  let page = "text 10 40 150 52 11\nhello there\ntext 100 50 120 52 3\ntop\n" in
  let o = create 320 200 "two" page in
  show "a page of two boxes, from its file" o;
  click o 1 110 54;
  show "a click where they overlap: the top one is edited, its cursor where the click was" o;
  keys o "\005!";
  click o 1 5 190;
  show "C-e, a ! typed, a click outside" o;
  click o 1 12 42;
  keys o "\005\024\019";
  show "the other edited: C-x C-s while editing asks to save" o;
  click o 1 5 190;
  click o 1 12 42;
  click o 1 5 190;
  at o 4 20 50; at o 0 20 50;
  keys o "\127";
  show "the right button selects a box, Backspace removes it" o;
  keys o "\031\031";
  show "C-_ twice: back to the edit of the !" o;
  file "now" o

let () =
  let o = create 400 220 "budget" "" in
  click o 1 10 40;
  keys o "\024t";
  show "C-x t: a sheet, where the last click was, its first cell chosen" o;
  keys o "Rent\nFood\nTotal\n";
  show "Rent, Food, Total typed, each with Enter: down a cell each" o;
  keys o "\128\128\128\128\131500\n300\n=b1+b2\n=sum(b1:b2)*2";
  show "up, right, to b1: 500, 300, =b1+b2, and =sum(b1:b2)*2 being typed (the formula bar)" o;
  keys o "\n\131\128\128\128\128=c1+1\n=a1+1\n=1/0\n=2+\n";
  show "Enter; to c1: a cycle, text in a sum, a division by 0, a syntax error" o;
  keys o "\130\128\128\128\128\128\n\127\127\1278\n";
  show "to b1, Enter brings back 500, three Backspace, 8: b3 and b4 again" o;
  file "the page" o;
  click o 1 175 78;
  show "a click in c2: chosen, its formula in the bar" o;
  keys o "\127";
  show "Backspace: c2 emptied" o;
  keys o "\007";
  show "C-g: no cell chosen" o

let () =
  let o = create 400 220 "diagram" "" in
  click o 1 10 40;
  keys o "\024d";
  show "C-x d: a drawing, where the last click was; the tool a box" o;
  click o 1 12 42;
  drag o 1 30 60 110 90;
  keys o "cpu";
  show "a box dragged from 30 60 to 110 90, cpu typed: its label" o;
  keys o "\t";
  drag o 1 110 75 190 130;
  keys o "\t\t";
  drag o 1 150 130 230 160;
  keys o "mem";
  show "Tab: an arrow, across then down; Tab twice: a box again, mem" o;
  keys o "\t\t";
  click o 1 40 190;
  keys o "a notes\127";
  show "Tab twice: text; a click, a notes typed, Backspace" o;
  keys o "\t";
  click o 1 250 80;
  show "Tab: a box; a click is no box (too small)" o;
  file "the page" o;
  keys o "\007";
  show "C-g: the drawing left" o

let () =
  let o = create 400 220 "menus" "" in
  click o 1 100 5;
  show "a click on Insert: its menu open" o;
  click o 1 110 40;
  show "a click on its Sheet: a sheet, where the last click was (none yet: 16 40)" o;
  drag o 1 60 5 60 22;
  show "Edit pressed, the mouse down to Undo, let go: the sheet undone" o;
  jump o 1 100 5 110 56;
  show "Insert pressed, let go on Drawing (nothing seen between): a drawing, and its Draw menu" o;
  click o 1 170 5;
  click o 1 170 38;
  show "Draw's Arrow: the tool an arrow, marked in the menu" o;
  click o 1 170 5;
  click o 1 300 150;
  show "Draw opened, a click outside: closed, and the page not clicked" o;
  click o 1 10 5;
  click o 1 10 22;
  show "File's Save" o

let () =
  let o = create 320 200 "moves" "text 40 60 150 52 5\nhello\n" in
  click o 1 60 80;
  show "a click in the box: edited, its tab above it, its corner" o;
  jump o 1 50 50 150 70;
  show "its tab pressed, let go 100 right, 20 down (nothing seen between): the box there" o;
  jump o 1 285 128 255 148;
  show "its corner pressed, let go 30 left, 20 down: 30 narrower, 20 taller" o;
  keys o "\031";
  show "C-_: the resize undone" o;
  file "the page" o
