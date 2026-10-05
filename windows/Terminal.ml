(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Terminal.mli *)

type t = {
  image : Display.image; r : Rectangle.t; font : Font.t;
  cols : int; rows : int;
  mutable past : string list;                  (* the lines above the last, the newest first: rows - 1 at most *)
  mutable last : string;
  ink : Display.image; paper : Display.image;
}

let make (image : Display.image) r font =
  let cell = max 1 (Font.width font "m") in
  { image; r; font; cols = max 1 (Rectangle.dx r / cell); rows = max 1 (Rectangle.dy r / Font.height font);
    past = []; last = ""; ink = Display.color image.display Display.black; paper = Display.color image.display Display.white }

(* a row of the rectangle drawn again: its line, or nothing *)
let row (t : t) k line =
  let y = t.r.min.y + (k * Font.height t.font) in
  Draw.fill t.image (Rectangle.v t.r.min.x y t.r.max.x (y + Font.height t.font)) t.paper;
  ignore (Font.string t.image (Point.v t.r.min.x y) t.ink t.font line)

let all (t : t) =
  Draw.fill t.image t.r t.paper;
  List.iteri (fun k line -> row t k line) (List.rev (t.last :: t.past))

let redraw = all

let reshape (t : t) (image : Display.image) r =
  let fresh = make image r t.font in
  let rec keep n = function [] -> [] | l :: more -> if n = 0 then [] else l :: keep (n - 1) more in
  fresh.past <- keep (fresh.rows - 1) t.past;
  fresh.last <- t.last;
  all fresh;
  fresh

(* the last line ended: one more above it, the oldest forgotten *)
let newline (t : t) =
  let rec keep n = function [] -> [] | l :: more -> if n = 0 then [] else l :: keep (n - 1) more in
  t.past <- keep (t.rows - 1) (t.last :: t.past);
  t.last <- ""

let put (t : t) text =
  let moved = ref false in
  String.iter (fun c ->
    (match c with
     | '\n' -> newline t; moved := true
     | '\t' -> t.last <- t.last ^ String.make (8 - (String.length t.last mod 8)) ' '
     | c when c >= ' ' -> t.last <- t.last ^ String.make 1 c
     | _ -> ());
    if String.length t.last >= t.cols then begin newline t; moved := true end) text;
  (* the lines moved up when the rectangle was full: all of it again *)
  if !moved && List.length t.past >= t.rows - 1 then all t
  else if !moved then List.iteri (fun k line -> row t k line) (List.rev (t.last :: t.past))
  else row t (List.length t.past) t.last

let erase (t : t) =
  if t.last <> "" then begin
    t.last <- String.sub t.last 0 (String.length t.last - 1);
    row t (List.length t.past) t.last
  end
