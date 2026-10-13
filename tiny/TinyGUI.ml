(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyGUI.mli *)

open TinyDraw
open TinyCalls
open TinyPlayground

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
