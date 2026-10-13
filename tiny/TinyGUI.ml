(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyGUI.mli *)

open TinyDraw
open TinyCalls
open TinyPlayground

(* a text; a text in a box, at its right; a button and the message it
 * sends; widgets side by side, the same width each; widgets one under
 * the other *)
type 'msg widget = Label of string | Field of string | Button of string * 'msg | Row of 'msg widget list | Col of 'msg widget list

(* a program: its first model, the model as widgets, the model after a
 * message, a key's messages *)
type ('m, 'msg) gui = { init : 'm; view : 'm -> 'msg widget; update : 'msg -> 'm -> 'm; key : int -> 'msg list }

(* what is kept under the model: where the mouse's button went down
 * (px -1: it is up), where the mouse is *)
type mouse = { px : int; py : int; x : int; y : int }

let up = { px = -1; py = -1; x = -1; y = -1 }

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
 * character) and its margins; a row as many times its widest widget;
 * a column its widest widget, the heights added *)
let rec size widget =
  match widget with
  | Label s -> (8 * String.length s) + 8, 24
  | Field s -> (8 * String.length s) + 8, 24
  | Button (s, _) -> (8 * String.length s) + 24, 28
  | Row l -> let (w, h) = widest l in (List.length l * (w + gap)) - gap, h
  | Col l -> fst (widest l), List.fold_left (fun h c -> h + snd (size c) + gap) (-gap) l

and widest l = List.fold_left (fun (w, h) c -> let (cw, ch) = size c in max w cw, max h ch) (0, 0) l

let inside x y (x0, y0, w, h) = x >= x0 && y >= y0 && x < x0 + w && y < y0 + h

(* a button's shapes: two edges lit, two in the shade, the other way
 * round and its text a pixel off when it is held *)
let button held x y w h s =
  let d = if held then 1 else 0 in
  let words = Move (((w - (8 * String.length s)) / 2) + d, ((h - 16) / 2) + d, Words (black, s)) in
  Move (x, y, Group [ Rect ((if held then light else dark), w, h); Rect ((if held then dark else light), w - 2, h - 2); Move (2, 2, Rect (face, w - 4, h - 4)); words ])

(* The place a widget is given, from the root down: a shape for each
 * text, field and button there (its first rectangle is all its box),
 * and the boxes that answer the mouse, each with its message. A row
 * shares its width, a column gives all of it and each widget the
 * height it asked for. A button is held when the mouse went down in
 * it and is still in it. *)
let rec place m x y w h widget =
  match widget with
  | Label s -> [ Move (x, y, Group [ Rect (face, w, h); Move (4, 4, Words (black, s)) ]) ], []
  | Field s ->
      [ Move (x, y, Group [ Rect (dark, w, h); Move (1, 1, Rect (light, w - 2, h - 2)); Move (w - 4 - (8 * String.length s), 4, Words (black, s)) ]) ], []
  | Button (s, msg) ->
      let box = x, y, w, h in
      [ button (inside m.px m.py box && inside m.x m.y box) x y w h s ], [ box, msg ]
  | Row l -> let cw = (w + gap) / List.length l in each m (fun _ -> cw - gap, h) (fun (cw, _) -> cw + gap, 0) x y l
  | Col l -> each m (fun c -> w, snd (size c)) (fun (_, ch) -> 0, ch + gap) x y l

(* a list's widgets one after the other: the size each is given, how
 * far the next one is *)
and each m given next x y l =
  match l with
  | [] -> [], []
  | c :: rest ->
      let (w, h) = given c in
      let (shapes, boxes) = place m x y w h c in
      let (dx, dy) = next (w, h) in
      let (shapes', boxes') = each m given next (x + dx) (y + dy) rest in
      shapes @ shapes', boxes @ boxes'

(* a model's widgets, at the size they ask for *)
let laid (g : ('m, 'msg) gui) model m = let v = g.view model in let (w, h) = size v in place m edge edge w h v

(* The shapes of one list that are not, at their place, in the other *)
let rec others shown now =
  match shown, now with
  | was :: a, s :: b -> if was = s then others a b else s :: others a b
  | _, rest -> rest

(* On the window, what is to draw after the shapes shown: the boxes of
 * those that are no longer given back to the ground, then the new
 * ones. A button pressed is one shape, whatever the widgets. (old:
 * every shape at each picture, through the playground's show: some
 * eighty messages a click, and a click shorter than them was lost) *)
let redraw shown now =
  let blank s = match s with Move (x, y, Group (Rect (_, w, h) :: _)) -> Move (x, y, Rect (face, w, h)) | s -> s in
  List.iter (fun s -> draw 0 0 0 (blank s)) (others now shown);
  List.iter (draw 0 0 0) (others shown now);
  flush ()

(*****************************************************************************)
(* The mouse, the keys *)
(*****************************************************************************)

(* The mouse at (x, y), its buttons b: the model and the mouse after.
 * The left button down: where it went down is kept. Up again: the
 * button it went down in, if the mouse is still in it, sends its
 * message (so a press is taken back by leaving the button). A mouse
 * that moves with its button up is the same mouse, the same value. *)
let mouse (g : ('m, 'msg) gui) model m x y b =
  if b land 1 = 1 then model, (if m.px < 0 then { px = x; py = y; x = x; y = y } else { px = m.px; py = m.py; x = x; y = y })
  else if m.px < 0 then model, m
  else List.fold_left (fun model (box, msg) -> if inside m.px m.py box && inside x y box then g.update msg model else model) model (snd (laid g model m)), up

(* a key: its messages, one after the other *)
let key (g : ('m, 'msg) gui) model k = List.fold_left (fun model msg -> g.update msg model) model (g.key k)

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* The program, until a q or the keys' end: the widgets drawn where
 * they are others (a model and a mouse that are the same values are
 * not looked at), then the keys or the mouse waited for, whichever is
 * first. *)
let run (g : ('m, 'msg) gui) =
  let fds = Array.make 2 0 in
  fds.(1) <- 4;
  let rec loop model m seen shown =
    let now = if seen then shown else fst (laid g model m) in
    if not seen then redraw shown now;
    if u_ready fds 2 0 = 0 then begin
      let s = u_read 0 16 in
      if s = "" then exit 0;
      let rec typed i model = if i >= String.length s then model else if s.[i] = 'q' then exit 0 else typed (i + 1) (key g model (Char.code s.[i])) in
      loop (typed 0 model) m false now
    end
    else begin
      let s = u_read 4 12 in
      if String.length s < 12 then exit 0;
      let (model', m') = mouse g model m (int16 s 0) (int16 s 4) (int16 s 8) in
      loop model' m' (model' == model && m' == m) now
    end
  in
  draw 0 0 0 (Rect (face, 640, 480));
  loop g.init up false []
