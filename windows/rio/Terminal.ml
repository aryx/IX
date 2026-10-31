(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Terminal.mli *)

type t = {
  image : Display.image; r : Rectangle.t; font : Font.t;
  cols : int; rows : int;
  mutable past : string list;                  (* the lines above the last, the newest first: 1,000 at most *)
  mutable last : string;
  mutable back : int;                          (* how many lines up from the end is shown: 0, the end *)
  mutable scrolling : bool;                    (* what is shown follows what is written *)
  (* a place in the text is a line's number (how many lines were ended
   * before it: the last line's is [ended]) and a column. The text
   * selected is from a place to another, the second not in it; while
   * the left button is down, [anchor] is where it went down *)
  mutable ended : int;
  mutable selected : ((int * int) * (int * int)) option;
  mutable anchor : (int * int) option;
  mutable clicked : (int * int) * int;         (* the left button's last press: where, when (ms) *)
  mutable part : string;                       (* a character's first bytes, written without its last *)
  mutable held : int;                          (* the mouse's buttons at the event before *)
  cell : int;                                  (* a character's width *)
  ink : Display.image; paper : Display.image; bar : Display.image; mark : Display.image;
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
    past = []; last = ""; back = 0; scrolling = true; ended = 0; selected = None; anchor = None; clicked = ((-1, 0), 0); held = 0; cell; part = "";
    ink = Display.color d Display.black; paper = Display.color d Display.white; bar = Display.color d (Display.rgb 0x99 0x99 0x99);
    (* (what is selected: a pale blue behind it, ix's; rio's is a grey green) *)
    mark = Display.color d (Display.rgb 0xb8 0xcc 0xe0) }

let rec take n = function [] -> [] | l :: more -> if n = 0 then [] else l :: take (n - 1) more
let rec drop n l = if n = 0 then l else match l with [] -> [] | _ :: more -> drop (n - 1) more

(* the lines shown, the first on top: [rows] of them, [back] lines before the end *)
let shown (t : t) = List.rev (take t.rows (drop t.back (t.last :: t.past)))

(* the number of the line on row k of what is shown *)
let line_at (t : t) k = t.ended - t.back - (min t.rows (1 + List.length t.past - t.back) - 1) + k

(* a row of the rectangle drawn again: its line, or nothing; what is
 * selected of it on its mark *)
let row (t : t) k line =
  let tr : Rectangle.t = text_r t in
  let y = tr.min.y + (k * Font.height t.font) in
  Draw.fill t.image (Rectangle.v tr.min.x y tr.max.x (y + Font.height t.font)) t.paper;
  (match t.selected with
   | Some ((l0, c0), (l1, c1)) ->
       let n = line_at t k in
       if n >= l0 && n <= l1 then begin
         let from = if n = l0 then c0 else 0 and upto = if n = l1 then c1 else Utf8.length line + 1 in
         if upto > from then Draw.fill t.image (Rectangle.v (tr.min.x + (from * t.cell)) y (min tr.max.x (tr.min.x + (upto * t.cell))) (y + Font.height t.font)) t.mark
       end
   | None -> ());
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
 * reader of what is above stays where it is, and so does what is shown
 * when it does not scroll and is full (the end is then below it) *)
let newline (t : t) =
  t.past <- take kept (t.last :: t.past);
  t.last <- "";
  t.ended <- t.ended + 1;
  if t.back > 0 || (not t.scrolling && 1 + List.length t.past > t.rows) then t.back <- min (t.back + 1) (List.length t.past)

let put (t : t) text =
  let moved = ref false and before = t.back in
  (* (a write may end inside a character: its start waits for the next) *)
  let whole, part = Utf8.chars (t.part ^ text) in
  t.part <- part;
  List.iter (fun c ->
    (match c with
     | "\n" -> newline t; moved := true
     | "\t" -> t.last <- t.last ^ String.make (8 - (Utf8.length t.last mod 8)) ' '
     | c when c >= " " -> t.last <- t.last ^ c
     | _ -> ());
    if Utf8.length t.last >= t.cols then begin newline t; moved := true end) whole;
  if t.back > 0 && before > 0 then scroll_bar t   (* (what is shown did not change: only where it is) *)
  else if !moved then all t
  else row t (min (List.length t.past) (t.rows - 1)) t.last

let erase (t : t) =
  if t.last <> "" then begin
    t.last <- Utf8.sub t.last 0 (Utf8.length t.last - 1);
    if t.back = 0 then row t (min (List.length t.past) (t.rows - 1)) t.last
  end

let scroll (t : t) n =
  let back = max 0 (min (t.back + n) (1 + List.length t.past - t.rows)) in
  if back <> t.back then begin t.back <- back; all t end

let half (t : t) = max 1 (t.rows / 2)

let at_end (t : t) = t.back = 0
let scrolling (t : t) = t.scrolling
let set_scrolling (t : t) on = t.scrolling <- on; if on then scroll t (-100000)

(* the scroll bar's rectangle, at the text's left *)
let in_bar (r : Rectangle.t) (p : Point.t) = Rectangle.contains r p && p.x < r.min.x + bar_w

(* the place in the text under a point: its row's line, the column
 * its x is in (not past the line's end) *)
let place (t : t) (p : Point.t) =
  let tr : Rectangle.t = text_r t in
  let lines = shown t in
  let k = max 0 (min (List.length lines - 1) ((p.y - tr.min.y) / Font.height t.font)) in
  line_at t k, max 0 (min (Utf8.length (List.nth lines k)) ((p.x - tr.min.x + (t.cell / 2)) / t.cell))

let contents (t : t) = String.concat "\n" (List.rev (t.last :: t.past))

(* the line of a number ("" when it is forgotten) *)
let line (t : t) n = let k = t.ended - n in if k = 0 then t.last else match List.nth_opt t.past (k - 1) with Some l -> l | None -> ""

(* the text selected, its lines ended by newlines but the last *)
let selection (t : t) =
  match t.selected with
  | None -> ""
  | Some ((l0, c0), (l1, c1)) ->
      let line = line t in
      let part n =
        let l = line n in
        let from = if n = l0 then c0 else 0 and upto = if n = l1 then c1 else Utf8.length l in
        Utf8.sub l from (max 0 (upto - from)) in
      String.concat "\n" (List.init (l1 - l0 + 1) (fun k -> part (l0 + k)))

(* What a double click at a place selects (rio's wdoubleclick, on one
 * line): after an opening bracket or quote, up to the one that closes
 * it, those inside counted (before a closing one, back to its opening
 * one; none found: nothing); at the line's start or end, the line and
 * its newline; else the word there (letters, digits, _ and what is
 * not ASCII) *)
let pairs = [ "{", "}"; "[", "]"; "(", ")"; "<", ">"; "\xc2\xab", "\xc2\xbb"; "\"", "\""; "'", "'"; "`", "`" ]

let double (t : t) ((n, c) : int * int) =
  let chars = Array.of_list (fst (Utf8.chars (line t n))) in
  let len = Array.length chars in
  (* from k by steps of d: where [close] is, the [opening]s met on the way closed first *)
  let rec matching opening close d k nest =
    if k < 0 || k >= len then None
    else if chars.(k) = close then (if nest = 0 then Some k else matching opening close d (k + d) (nest - 1))
    else matching opening close d (k + d) (if chars.(k) = opening then nest + 1 else nest) in
  let after = if c > 0 then List.assoc_opt chars.(c - 1) pairs else None
  and before = if c < len then List.find_opt (fun (_, r) -> r = chars.(c)) pairs else None in
  match after, before with
  | Some close, _ -> (match matching chars.(c - 1) close 1 c 0 with Some k -> (n, c), (n, k) | None -> (n, c), (n, c))
  | None, Some (opening, close) -> (match matching close opening (-1) (c - 1) 0 with Some k -> (n, k + 1), (n, c) | None -> (n, c), (n, c))
  | None, None ->
      if c = 0 || c >= len then (n, 0), (if n < t.ended then (n + 1, 0) else (n, len))
      else begin
        let word k = k >= 0 && k < len && (match chars.(k).[0] with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true | ch -> ch >= '\x80') in
        let rec left k = if word (k - 1) then left (k - 1) else k and right k = if word k then right (k + 1) else k in
        (n, left c), (n, right c)
      end

(* The mouse in the text's rectangle; what it means is the text's to
 * say (rio's terminal.c). A button just pressed in the scroll bar
 * scrolls, as rio's: the left one back and the right one forward, by
 * as many lines as the mouse is below the bar's top (near the top a
 * line, at the bottom a windowful); the middle one shows what is at
 * that place among all the lines. The left button in the text
 * selects: from where it goes down to where the mouse is, until it
 * comes up; a double click, what [double] says. *)
let mouse (t : t) (m : Mouse.state) =
  let fresh = m.buttons <> 0 && t.held = 0 in
  t.held <- m.buttons;
  if fresh && in_bar t.r m.pos then begin
    let lines = max 1 ((m.pos.y - t.r.min.y) / Font.height t.font) in
    if m.buttons land 1 <> 0 then scroll t lines
    else if m.buttons land 4 <> 0 then scroll t (- lines)
    else if m.buttons land 2 <> 0 then begin
      let total = 1 + List.length t.past in
      let first = total * (m.pos.y - t.r.min.y) / max 1 (Rectangle.dy t.r) in
      scroll t ((total - first - t.rows) - t.back)
    end
  end
  else if m.buttons land 1 <> 0 then begin
    let here = place t m.pos in
    if fresh then begin
      let at, msec = t.clicked in
      if at = here && m.msec - msec < 500 then begin
        (* (the button's release selects nothing else; a third click is a first) *)
        t.anchor <- None; t.clicked <- ((-1, 0), 0); t.selected <- Some (double t here); all t
      end
      else begin t.anchor <- Some here; t.clicked <- (here, m.msec) end
    end;
    (match t.anchor with
     | Some a ->
         let now = if compare a here <= 0 then Some (a, here) else Some (here, a) in
         if now <> t.selected then begin t.selected <- now; all t end
     | None -> ())
  end
  else t.anchor <- None

(* (one for all the windows; the menu opens on the item last chosen) *)
let snarf = ref "" and chosen = ref 0

type answer = [%mli]

let menu (t : t) screen mouse at =
  match Menu.hit screen t.font mouse 2 [ "snarf"; "paste"; "send"; (if t.scrolling then "noscroll" else "scroll") ] !chosen at with
  | Some 0 -> chosen := 0; (let text = selection t in if text <> "" then snarf := text); Nothing
  | Some 1 -> chosen := 1; Typed !snarf
  | Some 2 -> chosen := 2; Typed (if String.ends_with ~suffix:"\n" !snarf then !snarf else !snarf ^ "\n")
  | Some 3 -> Scroll (not t.scrolling)
  | _ -> Nothing

let reshape (t : t) (image : Display.image) r =
  let fresh = make image r t.font in
  fresh.past <- t.past;
  fresh.last <- t.last;
  fresh.ended <- t.ended;
  fresh.selected <- t.selected;
  fresh.scrolling <- t.scrolling;
  all fresh;
  fresh
