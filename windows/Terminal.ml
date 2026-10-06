(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Terminal.mli *)

type t = {
  image : Display.image; r : Rectangle.t; font : Font.t;
  cols : int; rows : int;
  mutable past : string list;                  (* the lines above the last, the newest first: 1,000 at most *)
  mutable last : string;
  mutable back : int;                          (* how many lines up from the end is shown: 0, the end *)
  ink : Display.image; paper : Display.image; bar : Display.image;
}

let kept = 1000
(* the scroll bar's width, and the space before the text (rio's is 12 and 4) *)
let bar_w = 10 and gap = 4

(* the text's own rectangle: right of the scroll bar *)
let text_r (t : t) = Rectangle.v (t.r.min.x + bar_w + gap) t.r.min.y t.r.max.x t.r.max.y

let make (image : Display.image) (r : Rectangle.t) font =
  let cell = max 1 (Font.width font "m") in
  let d = image.display in
  { image; r; font; cols = max 1 ((Rectangle.dx r - bar_w - gap) / cell); rows = max 1 (Rectangle.dy r / Font.height font);
    past = []; last = ""; back = 0;
    ink = Display.color d Display.black; paper = Display.color d Display.white; bar = Display.color d (Display.rgb 0x99 0x99 0x99) }

let rec take n = function [] -> [] | l :: more -> if n = 0 then [] else l :: take (n - 1) more
let rec drop n l = if n = 0 then l else match l with [] -> [] | _ :: more -> drop (n - 1) more

(* the lines shown, the first on top: [rows] of them, [back] lines before the end *)
let shown (t : t) = List.rev (take t.rows (drop t.back (t.last :: t.past)))

(* a row of the rectangle drawn again: its line, or nothing *)
let row (t : t) k line =
  let tr : Rectangle.t = text_r t in
  let y = tr.min.y + (k * Font.height t.font) in
  Draw.fill t.image (Rectangle.v tr.min.x y tr.max.x (y + Font.height t.font)) t.paper;
  ignore (Font.string t.image (Point.v tr.min.x y) t.ink t.font line)

(* the scroll bar: grey, and white where the lines shown are among all of them *)
let scroll_bar (t : t) =
  let total = 1 + List.length t.past in
  let h = Rectangle.dy t.r in
  let first = max 0 (total - t.back - t.rows) in
  let y0 = t.r.min.y + (h * first / total) and y1 = t.r.min.y + (h * (total - t.back) / total) in
  Draw.fill t.image (Rectangle.v t.r.min.x t.r.min.y (t.r.min.x + bar_w) t.r.max.y) t.bar;
  Draw.fill t.image (Rectangle.v t.r.min.x y0 (t.r.min.x + bar_w - 1) (max (y0 + 2) y1)) t.paper

let all (t : t) =
  Draw.fill t.image (text_r t) t.paper;
  List.iteri (fun k line -> row t k line) (shown t);
  scroll_bar t

let redraw = all

(* the last line ended: one more above it, the oldest forgotten; a
 * reader of what is above stays where it is *)
let newline (t : t) =
  t.past <- take kept (t.last :: t.past);
  t.last <- "";
  if t.back > 0 then t.back <- min (t.back + 1) (List.length t.past)

let put (t : t) text =
  let moved = ref false in
  String.iter (fun c ->
    (match c with
     | '\n' -> newline t; moved := true
     | '\t' -> t.last <- t.last ^ String.make (8 - (String.length t.last mod 8)) ' '
     | c when c >= ' ' -> t.last <- t.last ^ String.make 1 c
     | _ -> ());
    if String.length t.last >= t.cols then begin newline t; moved := true end) text;
  if t.back > 0 then scroll_bar t            (* (what is shown did not change: only where it is) *)
  else if !moved then all t
  else row t (min (List.length t.past) (t.rows - 1)) t.last

let erase (t : t) =
  if t.last <> "" then begin
    t.last <- String.sub t.last 0 (String.length t.last - 1);
    if t.back = 0 then row t (min (List.length t.past) (t.rows - 1)) t.last
  end

let scroll (t : t) n =
  let back = max 0 (min (t.back + n) (1 + List.length t.past - t.rows)) in
  if back <> t.back then begin t.back <- back; all t end

let half (t : t) = max 1 (t.rows / 2)

(* the scroll bar's rectangle, at the text's left *)
let in_bar (r : Rectangle.t) (p : Point.t) = Rectangle.contains r p && p.x < r.min.x + bar_w

(* The mouse in the text's rectangle, a button just pressed. In the
 * scroll bar, rio's: the left button goes back and the right one
 * forward, by as many lines as the mouse is below the bar's top (near
 * the top a line, at the bottom a windowful); the middle one shows
 * what is at that place among all the lines. (In the text itself:
 * nothing yet: selecting.) *)
let pressed (t : t) (m : Mouse.state) =
  if in_bar t.r m.pos then begin
    let lines = max 1 ((m.pos.y - t.r.min.y) / Font.height t.font) in
    if m.buttons land 1 <> 0 then scroll t lines
    else if m.buttons land 4 <> 0 then scroll t (- lines)
    else if m.buttons land 2 <> 0 then begin
      let total = 1 + List.length t.past in
      let first = total * (m.pos.y - t.r.min.y) / max 1 (Rectangle.dy t.r) in
      scroll t ((total - first - t.rows) - t.back)
    end
  end

let reshape (t : t) (image : Display.image) r =
  let fresh = make image r t.font in
  fresh.past <- t.past;
  fresh.last <- t.last;
  all fresh;
  fresh
