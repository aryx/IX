(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibGUI.mli *)

open TinyLibDraw
open TinyCalls
open TinyLibPlayground

(* a text; a text in a box, at its right; a field typed in, and the
 * message of another text; a button and the message it sends; widgets
 * side by side, the same width each; widgets one under the other *)
type 'msg widget =
  | Label of string
  | Field of string
  | Input of string * (string -> 'msg)
  | Button of string * 'msg
  | Row of 'msg widget list
  | Col of 'msg widget list

(* a program: its first model, the model as widgets, the model after a
 * message, a key's messages *)
type ('m, 'msg) gui = { init : 'm; view : 'm -> 'msg widget; update : 'msg -> 'm -> 'm; key : int -> 'msg list }

(* what a box does with the mouse or the keys: a button's message; a
 * field's text, and the message of another one *)
type 'msg action = Send of 'msg | Edit of string * (string -> 'msg)

(* what is kept under the model: where the mouse's button went down
 * (px -1: it is up), where the mouse is, where its button last went
 * down (the field there has the keys) *)
type mouse = { px : int; py : int; x : int; y : int; fx : int; fy : int }

let up = { px = -1; py = -1; x = -1; y = -1; fx = -1; fy = -1 }

(*****************************************************************************)
(* The layout *)
(*****************************************************************************)

(* between two widgets, and around them all; the greys *)
let gap = 4
let edge = 8
let face = 0xcc
let light = 0xff
let dark = 0x66
let black = 0
let selected = 3          (* the palette's blue: an open menu, its item *)

(* The size a widget asks for, from its leaves up: a text's (8 by 16 a
 * character) and its margins, a field typed in ten characters at
 * least; a row as many times its widest widget; a column its widest
 * widget, the heights added *)
let rec size widget =
  match widget with
  | Label s -> (8 * String.length s) + 8, 24
  | Field s -> (8 * String.length s) + 8, 24
  | Input (s, _) -> (8 * max 10 (String.length s + 1)) + 8, 24
  | Button (s, _) -> (8 * String.length s) + 24, 28
  | Row l -> let (w, h) = widest l in (List.length l * (w + gap)) - gap, h
  | Col l -> fst (widest l), List.fold_left (fun h c -> h + snd (size c) + gap) (-gap) l

and widest l = List.fold_left (fun (w, h) c -> let (cw, ch) = size c in max w cw, max h ch) (0, 0) l

let inside x y (x0, y0, w, h) = x >= x0 && y >= y0 && x < x0 + w && y < y0 + h

(* a text in a white box, tx from its left *)
let boxed x y w h tx s = Move (x, y, Group [ Rect (dark, w, h); Move (1, 1, Rect (light, w - 2, h - 2)); Move (tx, 4, Words (black, s)) ])

(* The place a widget is given, from the root down: a shape for each
 * text, field and button there (its first rectangle is all its box),
 * and the boxes that answer the mouse or the keys, each with what it
 * does. A row shares its width, a column gives all of it and each
 * widget the height it asked for. A button has two edges lit and two
 * in the shade. The mouse is not asked: [over] has what it changes.
 * (old: the mouse given, a button held another shape: every widget
 * made, placed and compared at a press, 340,000 instructions of
 * tiny-machine's where 160,000 now) *)
let rec place x y w h widget =
  match widget with
  | Label s -> [ Move (x, y, Group [ Rect (face, w, h); Move (4, 4, Words (black, s)) ]) ], []
  | Field s -> [ boxed x y w h (w - 4 - (8 * String.length s)) s ], []
  | Input (s, f) -> [ boxed x y w h 4 s ], [ (x, y, w, h), Edit (s, f) ]
  | Button (s, msg) ->
      let words = Move ((w - (8 * String.length s)) / 2, (h - 16) / 2, Words (black, s)) in
      [ Move (x, y, Group [ Rect (dark, w, h); Rect (light, w - 2, h - 2); Move (2, 2, Rect (face, w - 4, h - 4)); words ]) ], [ (x, y, w, h), Send msg ]
  | Row l -> let cw = (w + gap) / List.length l in each (fun _ -> cw - gap, h) (fun (cw, _) -> cw + gap, 0) x y l
  | Col l -> each (fun c -> w, snd (size c)) (fun (_, ch) -> 0, ch + gap) x y l

(* a list's widgets one after the other: the size each is given, how
 * far the next one is *)
and each given next x y l =
  match l with
  | [] -> [], []
  | c :: rest ->
      let (w, h) = given c in
      let (shapes, boxes) = place x y w h c in
      let (dx, dy) = next (w, h) in
      let (shapes', boxes') = each given next (x + dx) (y + dy) rest in
      shapes @ shapes', boxes @ boxes'

(* a model's widgets, at the size they ask for *)
let laid (g : ('m, 'msg) gui) model = let v = g.view model in let (w, h) = size v in place edge edge w h v

(* What the mouse alone changes, drawn over the widgets, each with the
 * box it is in: the button held (the mouse went down in it and is
 * still in it), its edges the other way round; the caret of the field
 * that has the keys, after its text *)
let over boxes m =
  List.concat (List.map (fun ((x, y, w, h), action) ->
    let box = x, y, w, h in
    match action with
    | Send _ ->
        if inside m.px m.py box && inside m.x m.y box then
          [ box, Move (x, y, Group [ Rect (dark, w - 2, 2); Rect (dark, 2, h - 2); Move (0, h - 2, Rect (light, w, 2)); Move (w - 2, 0, Rect (light, 2, h)) ]) ]
        else []
    | Edit (s, _) -> if inside m.fx m.fy box then [ box, Move (x + 4 + (8 * String.length s), y + 4, Rect (black, 2, 16)) ] else []) boxes)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* The shapes of two lists that are not, at their place, in the other:
 * those of the first, those of the second (one pass: a comparison of
 * two shapes that are equal is the dear one, some 2,500 instructions) *)
let rec differ shown now =
  match shown, now with
  | was :: a, s :: b -> let (olds, news) = differ a b in if was = s then olds, news else was :: olds, s :: news
  | olds, news -> olds, news

(* On the window, what is to draw after the shapes shown and what was
 * over them: a shape that had something over it counts as gone; the
 * boxes of those that are no longer are given back to the ground,
 * then the new ones drawn, then what is over them now. A button
 * pressed is its four edges, whatever the widgets. (old: every shape
 * at each picture, through the playground's show: some eighty
 * messages a click, and a click shorter than them was lost) *)
let redraw shown was now is =
  let at (x, y, w, h) s = match s with Move (sx, sy, Group (Rect (_, sw, sh) :: _)) -> sx = x && sy = y && sw = w && sh = h | _ -> false in
  let shown = List.map (fun s -> if List.exists (fun (box, _) -> at box s) was then Group [] else s) shown in
  let blank s = match s with Move (x, y, Group (Rect (_, w, h) :: _)) -> Move (x, y, Rect (face, w, h)) | s -> s in
  let (olds, news) = differ shown now in
  List.iter (fun s -> draw 0 0 0 (blank s)) olds;
  List.iter (draw 0 0 0) news;
  List.iter (fun (_, s) -> draw 0 0 0 s) is;
  flush ()

(*****************************************************************************)
(* The mouse, the keys *)
(*****************************************************************************)

(* The mouse at (x, y), its buttons b, over these boxes: the model and
 * the mouse after. The left button down: where it went down is kept.
 * Up again: the button it went down in, if the mouse is still in it,
 * sends its message (so a press is taken back by leaving the button).
 * A mouse that moves with its button up is the same mouse, the same
 * value. *)
let mouse (g : ('m, 'msg) gui) boxes model m x y b =
  if b land 1 = 1 then model, (if m.px < 0 then { px = x; py = y; x = x; y = y; fx = x; fy = y } else { px = m.px; py = m.py; x = x; y = y; fx = m.fx; fy = m.fy })
  else if m.px < 0 then model, m
  else
    List.fold_left (fun model (box, action) ->
      match action with Send msg when inside m.px m.py box && inside x y box -> g.update msg model | _ -> model) model boxes,
    { px = -1; py = -1; x = x; y = y; fx = m.fx; fy = m.fy }

(* the fields that have the keys (one, or none): where the mouse's
 * button last went down *)
let editing boxes m = List.filter (fun (box, action) -> match action with Edit _ -> inside m.fx m.fy box | Send _ -> false) boxes

(* A key: the field that has the keys sends its text with the
 * character more, or one less at a backspace; with no such field, the
 * program's messages for the key, one after the other *)
let key (g : ('m, 'msg) gui) boxes model m k =
  match editing boxes m with
  | (_, Edit (s, f)) :: _ ->
      if k = 8 || k = 127 then (if s = "" then model else g.update (f (String.sub s 0 (String.length s - 1))) model)
      else if k >= 32 && k < 127 then g.update (f (s ^ String.make 1 (Char.chr k))) model
      else model
  | _ -> List.fold_left (fun model msg -> g.update msg model) model (g.key k)

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* The program, until an Escape, a q that no field takes, or the keys'
 * end: what changed drawn (the widgets when the model's are other
 * ones, what is over them when the mouse changed it), then the keys or
 * the mouse waited for, whichever is first. The widgets are made and
 * placed when the model is another one, and after each key that makes
 * it so: the next key is the new field's. *)
let run (g : ('m, 'msg) gui) =
  let fds = Array.make 2 0 in
  fds.(1) <- 4;
  let rec loop model m view shown was =
    let (now, boxes) = view in
    let is = over boxes m in
    if now != shown || is <> was then redraw shown was now is;
    if u_ready fds 2 0 = 0 then begin
      let s = u_read 0 16 in
      if s = "" then exit 0;
      let rec typed i model view =
        if i >= String.length s then loop model m view now is
        else begin
          (match editing (snd view) m with [] -> if s.[i] = 'q' then exit 0 | _ -> ());
          if s.[i] = '\027' then exit 0;
          let model' = key g (snd view) model m (Char.code s.[i]) in
          typed (i + 1) model' (if model' != model then laid g model' else view)
        end
      in
      typed 0 model view
    end
    else begin
      let s = u_read 4 12 in
      if String.length s < 12 then exit 0;
      let (model', m') = mouse g boxes model m (int16 s 0) (int16 s 4) (int16 s 8) in
      loop model' m' (if model' != model then laid g model' else view) now is
    end
  in
  draw 0 0 0 (Rect (face, 640, 480));
  loop g.init up (laid g g.init) [] []

(*****************************************************************************)
(* Pull-down menus *)
(*****************************************************************************)

(* A bar of menus is a list, each menu a title and its items, each item
 * a text and the message it sends. What is kept under the model, as
 * for the mouse of the widgets: the menu open (-1 none), the item under
 * the mouse in it (-1 none), the buttons as last seen. *)
type menu_state = { mutable opened : int; mutable item : int; mutable held : int }
type 'msg menu_answer = Ignored | Taken | Picked of 'msg

let menu_closed () = { opened = -1; item = -1; held = 0 }
let bar_height = 18

let title_width t = (8 * String.length t) + 16
let rec nth_menu menus i = match menus with m :: rest -> if i = 0 then m else nth_menu rest (i - 1) | [] -> ("", [])
let rec title_x menus i = match menus with (t, _) :: rest -> if i = 0 then 0 else title_width t + title_x rest (i - 1) | [] -> 0
let rec title_at menus x i at =
  match menus with
  | (t, _) :: rest -> if x >= at && x < at + title_width t then i else title_at rest x (i + 1) (at + title_width t)
  | [] -> -1
let list_width items = 16 + (8 * List.fold_left (fun m (s, _) -> max m (String.length s)) 0 items)

(* the item of the open menu under (x, y), or -1 *)
let item_at menus st x y =
  if st.opened < 0 then -1
  else begin
    let (_, items) = nth_menu menus st.opened and x0 = title_x menus st.opened in
    let n = List.length items in
    if x >= x0 && x < x0 + list_width items && y >= bar_height && y < bar_height + (16 * n) + 4 then min (n - 1) ((y - bar_height - 2) / 16) else -1
  end

(* The mouse at (x, y), its buttons b: whether the menus take it, and
 * the message of an item chosen. A press on a title opens its menu;
 * the button held, the mouse goes along the titles and down the
 * items; let go on an item, it is chosen. Let go on the title, the
 * menu stays open, for a click on an item (a click elsewhere closes
 * it). The mouse is a place, not its history (a press and a let go far
 * apart may be all that is seen), so what counts is where the mouse
 * is when the button goes up. *)
let menu_mouse menus st x y b =
  let pressed = b land 1 <> 0 && st.held land 1 = 0 and released = b land 1 = 0 && st.held land 1 <> 0 in
  st.held <- b;
  let title = if y < bar_height then title_at menus x 0 0 else -1 and item = item_at menus st x y in
  if st.opened < 0 then (if pressed && y < bar_height then (st.opened <- title; st.item <- -1; Taken) else Ignored)
  else if title >= 0 && b land 1 <> 0 then begin
    (if pressed && title = st.opened then st.opened <- -1 else if title <> st.opened then (st.opened <- title; st.item <- -1));
    Taken
  end
  else if released && item >= 0 then begin
    let rec nth l i = match l with (_, msg) :: rest -> if i = 0 then msg else nth rest (i - 1) | [] -> failwith "menu" in
    let (_, items) = nth_menu menus st.opened in
    st.opened <- -1; st.item <- -1;
    Picked (nth items item)
  end
  else if (released && y >= bar_height) || (pressed && item < 0) then (st.opened <- -1; st.item <- -1; Taken)
  else (st.item <- item; Taken)

(* The bar, the width of the window, and the open menu under its title,
 * the item under the mouse in white on blue; two groups, so that a
 * menu opening does not redraw the bar *)
let menu_view width menus st =
  let rec titles l i x =
    match l with
    | (t, _) :: rest ->
        (if i = st.opened then [ Move (x, 0, Rect (selected, title_width t, bar_height - 1)); Move (x + 8, 1, Words (light, t)) ]
         else [ Move (x + 8, 1, Words (black, t)) ]) @ titles rest (i + 1) (x + title_width t)
    | [] -> [] in
  let rec rows l k w =
    match l with
    | (s, _) :: rest ->
        (if k = st.item then [ Move (1, 2 + (16 * k), Rect (selected, w - 2, 16)); Move (8, 2 + (16 * k), Words (light, s)) ]
         else [ Move (8, 2 + (16 * k), Words (black, s)) ]) @ rows rest (k + 1) w
    | [] -> [] in
  let opened =
    if st.opened < 0 then []
    else begin
      let (_, items) = nth_menu menus st.opened in
      let w = list_width items and h = (16 * List.length items) + 4 in
      [ Move (title_x menus st.opened, bar_height, Group (Rect (black, w, h) :: Move (1, 1, Rect (light, w - 2, h - 2)) :: rows items 0 w)) ]
    end in
  [ Group (Rect (face, width, bar_height - 1) :: Move (0, bar_height - 1, Rect (dark, width, 1)) :: titles menus 0 0); Group opened ]

(*****************************************************************************)
(* A program that draws its whole window *)
(*****************************************************************************)

(* Below the widgets: a program that makes its picture itself (emacs,
 * the office). Its first model, given its window's size; its picture,
 * as shapes; a key, and the next model, or None to end; the mouse at
 * (x, y) with its buttons, and the next model, or None *)
type 'm canvas = { first : int -> int -> 'm; picture : 'm -> shape list; typed : int -> 'm -> 'm option; moved : int -> int -> int -> 'm -> 'm option }

(* The window's size in pixels: an ENQ printed (ASCII's enquiry, 5),
 * which tiny-windows answers in the window's mouse box as a mouse at
 * (width, height) with the buttons -1; on the console no one answers in
 * half a second, and the screen is 640 by 480 *)
let window_size () =
  ignore (u_write 1 "\005");
  let fds = Array.make 1 4 and until = u_ticks () + 200 in
  let rec answer () =
    if u_ready fds 1 until <> 4 then 640, 480
    else (let s = u_read 4 12 in if String.length s = 12 && int16 s 8 = -1 then int16 s 0, int16 s 4 else answer ()) in
  answer ()

(* a shape's leaves, each a rectangle or words at its place in the
 * window, in their order, on acc *)
let rec leaves x y s acc =
  match s with
  | Move (dx, dy, s) -> leaves (x + dx) (y + dy) s acc
  | Group l -> List.fold_right (fun s acc -> leaves x y s acc) l acc
  | leaf -> (x, y, leaf) :: acc

let box (x, y, leaf) =
  match leaf with
  | Rect (_, w, h) -> x, y, x + w, y + h
  | Words (c, s) -> x, y, x + (char_width c * String.length s) + overhang c, y + char_height c
  | _ -> x, y, x, y

let meets (x0, y0, x1, y1) (a0, b0, a1, b1) = x0 < a1 && a0 < x1 && y0 < b1 && b0 < y1

(* the characters two texts begin with *)
let rec common a b i = if i < String.length a && i < String.length b && a.[i] = b.[i] then common a b (i + 1) else i

(* a rectangle to erase, once (a cursor's cell and its character are
 * two leaves at one place) *)
let once r erased = if List.mem r erased then erased else r :: erased

(* the characters two texts of the same length end with, from i down *)
let rec common_end a b i = if i > 0 && a.[i - 1] = b.[i - 1] then common_end a b (i - 1) else i

(* Two shapes' leaves compared at each place: the rectangles where an
 * old leaf is to be erased, on erased; each new leaf with what of it
 * is to be drawn, on marked: (-1, 0) all of it, (0, 0) nothing (unless
 * an erasing uncovers it), (p, q) its words from the p-th character up
 * to the q-th. Of words of the same colour at the same place, only the
 * characters between what they begin with and, of the same length,
 * what they end with: typing at a line's end draws a character, and a
 * mode line's column number one or two (emacs.ml's comparison, before) *)
let rec compare_leaves olds news erased marked =
  match olds, news with
  | o :: os, n :: ns ->
      let erased, mark =
        if o = n then erased, (0, 0)
        else
          match o, n with
          | (x, y, Words (c, s)), (x', y', Words (c', s')) when x = x' && y = y' && c = c' && c < 256 ->
              let p = common s s' 0 and m = String.length s and m' = String.length s' in
              let q = if m = m' then common_end s s' m else max m m' in
              (if min q m > p then once (x + (8 * p), y, x + (8 * min q m), y + 16) erased else erased),
              (if min q m' > p then (p, min q m') else (0, 0))
          | _ -> once (box o) erased, (-1, 0) in
      compare_leaves os ns erased ((n, mark) :: marked)
  | o :: os, [] -> compare_leaves os [] (once (box o) erased) marked
  | [], n :: ns -> compare_leaves [] ns erased ((n, (-1, 0)) :: marked)
  | [], [] -> erased, marked

(* spans of characters, (from, up to), as few: those that meet made one *)
let spans (l : (int * int) list) : (int * int) list =
  let add acc (i, j) =
    let meet = List.filter (fun (a, b) -> a <= j && i <= b) acc and apart = List.filter (fun (a, b) -> not (a <= j && i <= b)) acc in
    List.fold_left (fun (i, j) (a, b) -> min i a, max j b) (i, j) meet :: apart in
  List.filter (fun (i, j) -> j > i) (List.fold_left add [] l)

(* a leaf drawn: all of it, or its words from the p-th character up to
 * the q-th; and where an erasing uncovered it, there only: a rectangle
 * (the ground meets every erasing, and drawn whole it would wipe what
 * is on it), the characters in the columns it met *)
let paint erased (l, mark) =
  let (x, y, leaf) = l and (p, q) = mark in
  if p = -1 then draw 0 x y leaf
  else
    match leaf with
    | Rect (c, _, _) ->
        let (x0, y0, x1, y1) = box l in
        List.iter (fun r ->
          let (a0, b0, a1, b1) = r in
          if meets (x0, y0, x1, y1) r then draw 0 (max x0 a0) (max y0 b0) (Rect (c, min x1 a1 - max x0 a0, min y1 b1 - max y0 b0))) erased
    | Words (c, _) when c >= 256 ->
        (* a styled text (a character of another size, a slant over the
         * next): all of it, where it changed or was uncovered *)
        if q > p || List.exists (meets (box l)) erased then draw 0 x y leaf
    | Words (c, s) ->
        (* its characters that changed, and those an erasing uncovered
         * (the columns it met: a cursor that moved, one character),
         * each span drawn once *)
        let (x0, y0, x1, y1) = box l in
        let uncovered = List.concat (List.map (fun r ->
          let (a0, _, a1, _) = r in
          if meets (x0, y0, x1, y1) r then [ (max x0 a0 - x) / 8, min (String.length s) ((min x1 a1 - x + 7) / 8) ] else []) erased) in
        List.iter (fun (i, j) -> draw 0 (x + (8 * i)) y (Words (c, String.sub s i (j - i)))) (spans ((if q > p then [ p, q ] else []) @ uncovered))
    | _ -> ()

(* What changed between two pictures, drawn: each shape's leaves
 * compared with the old shape's at its place (a key in a box of the
 * office changes a line of it, not the page), the old ones erased by
 * what is under them, the new ones drawn, in the picture's order. The
 * first shape is the ground, under all. A picture is kept with its
 * leaves: a shape that is the very same as the old one at its place (a
 * program that kept it: the editor keeps a line's) is not looked into
 * again *)
(* a picture's shape as it is compared: changed, its leaves each with
 * what of it is to be drawn; the same, its leaves and their box (looked
 * into only when an erasing meets the box) *)
type part = Changed of ((int * int * shape) * (int * int)) list | Same of (int * int * shape) list * (int * int * int * int)

let repaint shown now =
  let rec pairs olds news erased parts =
    match olds, news with
    | (o, _, _) :: os, (n, nl, b) :: ns when o == n -> pairs os ns erased (Same (nl, b) :: parts)
    | (_, ol, _) :: os, (_, nl, _) :: ns -> let e, m = compare_leaves ol nl erased [] in pairs os ns e (Changed (List.rev m) :: parts)
    | (_, ol, _) :: os, [] -> let e, _ = compare_leaves ol [] erased [] in pairs os [] e parts
    | [], (_, nl, _) :: ns -> let e, m = compare_leaves [] nl erased [] in pairs [] ns e (Changed (List.rev m) :: parts)
    | [], [] -> erased, parts in
  let erased, parts = pairs shown now [] [] in
  let drawn (_, (p, q)) = p = -1 || q > p in
  if erased <> [] || List.exists (fun part -> match part with Changed m -> List.exists drawn m | Same _ -> false) parts then begin
    List.iter (fun part ->
      match part with
      | Changed m -> List.iter (paint erased) m
      | Same (l, b) -> if List.exists (meets b) erased then List.iter (fun leaf -> paint erased (leaf, (0, 0))) l) (List.rev parts);
    flush ()
  end

(* The program, until its typed says None or the keys end: its picture
 * drawn where it changed, then the keys or the mouse waited for. The
 * console is raw meanwhile (rawcons): its ^C is a key, not the kill of
 * every process (emacs's C-x C-c). At the end the window is white. *)
let run_canvas (c : 'm canvas) =
  let w, h = window_size () in
  ignore (u_rawcons 1);
  let fds = Array.make 2 0 in
  fds.(1) <- 4;
  (* a shape with its leaves and their box: the old ones when it is the
   * very same *)
  let fresh n =
    let l = leaves 0 0 n [] in
    let b = List.fold_left (fun (x0, y0, x1, y1) leaf -> let (a0, b0, a1, b1) = box leaf in min x0 a0, min y0 b0, max x1 a1, max y1 b1) (max_int, max_int, min_int, min_int) l in
    (n, l, b) in
  let rec with_leaves olds news =
    match olds, news with
    | (o, ol, ob) :: os, n :: ns -> (if o == n then (n, ol, ob) else fresh n) :: with_leaves os ns
    | [], n :: ns -> fresh n :: with_leaves [] ns
    | _, [] -> [] in
  let rec loop model shown =
    let now = with_leaves shown (c.picture model) in
    repaint shown now;
    if u_ready fds 2 0 = 0 then begin
      let s = u_read 0 16 in
      let rec typed i model =
        if i >= String.length s then loop model now
        else match c.typed (Char.code s.[i]) model with Some m -> typed (i + 1) m | None -> () in
      if s <> "" then typed 0 model
    end
    else begin
      let s = u_read 4 12 in
      if String.length s = 12 && int16 s 8 >= 0 then (match c.moved (int16 s 0) (int16 s 4) (int16 s 8) model with Some m -> loop m now | None -> ())
      else if String.length s = 12 then loop model now
    end in
  loop (c.first w h) [];
  draw 0 0 0 (Rect (255, w, h));
  flush ();
  ignore (u_rawcons 0)

(* the file such a program edits: its text, "" when it is not there;
 * the text written, and whether all of it was (user.h's O_WRONLY |
 * O_CREATE | O_TRUNC; u_write is 0 when all was written) *)
let read_file file =
  let fd = u_open file 0 in
  if fd < 0 then ""
  else begin
    (* the pieces read, the last first, then each copied once into
     * bytes of their size (old: each added to the text so far, a copy
     * of all of it a piece: a WAV of 141 KB was 85 million
     * instructions, 600 a byte) *)
    let rec go acc n = let s = u_read fd 4096 in if s = "" then (acc, n) else go (s :: acc) (n + String.length s) in
    let pieces, n = go [] 0 in
    ignore (u_close fd);
    let b = Bytes.make n '\000' in
    ignore (List.fold_left (fun at s -> let at = at - String.length s in Bytes.blit_string s 0 b at (String.length s); at) n pieces);
    Bytes.to_string b
  end

let write_file file text =
  let fd = u_open file 0x601 in
  fd >= 0 && (let r = u_write fd text in ignore (u_close fd); r = 0)
