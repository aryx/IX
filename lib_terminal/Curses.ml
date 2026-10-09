(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: the author's playground's libs/terminal/Curses.ml; put's and box's attrs are said, where they were optional (Vt.plain); cursor_at, for a host that is no terminal; pieces, take and same, the one-byte glyphs made once: a screen made and compared in less time (docs/plans/plan_pascal.md); wide and combining characters (lay: docs/plans/plan_emacs.md) *)

(* See Curses.mli *)

(*****************************************************************************)
(* Screens *)
(*****************************************************************************)

(* the rows are shared between versions: drawing on a row copies that
   row only *)
type t = { rows : int; cols : int; cells : Vt.cell array array; cursor : (int * int) option }

let create ~rows ~cols = { rows; cols; cells = Array.make rows (Array.make cols Vt.blank); cursor = None }
let rows (t : t) = t.rows
let cols (t : t) = t.cols
let cursor (c : (int * int) option) (t : t) : t = { t with cursor = c }
let cursor_at (t : t) : (int * int) option = t.cursor
let cell (t : t) r c = if r >= 0 && r < t.rows && c >= 0 && c < t.cols then t.cells.(r).(c) else Vt.blank

(* ix: a character of one byte as a string, made once: a screen's cells
 * are mostly these, and a put made one for each (old, in glyphs:
 * String.sub s i len for every character) *)
let one : string array = Array.init 256 (fun (i : int) -> String.make 1 (Char.chr i))

(* a string's UTF-8 characters, each as its bytes *)
let glyphs (s : string) : string list =
  let n = String.length s in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      let b = Char.code s.[i] in
      let len = if b land 0xE0 = 0xC0 then 2 else if b land 0xF0 = 0xE0 then 3 else if b land 0xF8 = 0xF0 then 4 else 1 in
      let len = min len (n - i) in
      go (i + len) ((if len = 1 then one.(b) else String.sub s i len) :: acc)
  in
  go 0 []

(* ix: a text's characters in a row's cells, from column c. A wide
 * character (Utf8.width: Chinese, an emoji) has two cells, the second
 * with no glyph: a terminal draws it over both, and the columns after
 * it are where the cells say; one of no width (a combining accent)
 * goes in the cell of the character before it, as a terminal draws
 * it. (old: a cell a character: what followed a wide character was a
 * column off on the terminal.) *)
let lay (row : Vt.cell array) (c : int) (text : string) (attrs : Vt.attrs) : unit =
  let cols = Array.length row in
  let col = ref c and last = ref (-1) in
  List.iter (fun (g : string) ->
    let w = if String.length g = 1 then 1 else Utf8.width (Utf8.code g) in
    if w = 0 && !last >= 0 then row.(!last) <- { Vt.glyph = row.(!last).glyph ^ g; attrs }
    else begin
      (* (a wide one that would be cut at the edge is not put) *)
      if !col >= 0 && !col + w <= cols then begin
        row.(!col) <- { Vt.glyph = g; attrs };
        last := !col;
        if w = 2 then row.(!col + 1) <- { Vt.glyph = ""; attrs }
      end;
      col := !col + max 1 w
    end) (glyphs text)

let put ~(attrs : Vt.attrs) (r : int) (c : int) (text : string) (t : t) : t =
  if r < 0 || r >= t.rows then t
  else begin
    let row = Array.copy t.cells.(r) in
    lay row c text attrs;
    let cells = Array.copy t.cells in
    cells.(r) <- row;
    { t with cells }
  end

(* ix: several texts on a row, the row copied once: a line of a
 * program's text is a piece a word, and a put each copied the row for
 * each (a window's view at 51 by 113, by mini-ml's code: 5.6 ms of put
 * a character, 2.6 with this) *)
let pieces (r : int) (ps : (int * string * Vt.attrs) list) (t : t) : t =
  if r < 0 || r >= t.rows then t
  else begin
    let row = Array.copy t.cells.(r) in
    List.iter (fun ((c, text, attrs) : int * string * Vt.attrs) -> lay row c text attrs) ps;
    let cells = Array.copy t.cells in
    cells.(r) <- row;
    { t with cells }
  end

(* ix: a row taken from another screen, and whether two screens have
 * the same one (the rows are shared between versions: a program that
 * keeps a row it drew and a host that asks before comparing cells do
 * a line's work for a key, not a screen's) *)
let take (r : int) (from : t) (t : t) : t =
  if r < 0 || r >= t.rows || r >= from.rows || from.cols <> t.cols then t
  else begin
    let cells = Array.copy t.cells in
    cells.(r) <- from.cells.(r);
    { t with cells }
  end

let same (a : t) (b : t) (r : int) : bool = r >= 0 && r < a.rows && r < b.rows && a.cells.(r) == b.cells.(r)

let box ~(attrs : Vt.attrs) (top : int) (left : int) (height : int) (width : int) (t : t) : t =
  let edge = "+" ^ String.make (max 0 (width - 2)) '-' ^ "+" in
  let t = put ~attrs top left edge t |> put ~attrs (top + height - 1) left edge in
  List.fold_left (fun t r -> t |> put ~attrs r left "|" |> put ~attrs r (left + width - 1) "|") t (List.init (max 0 (height - 2)) (fun i -> top + 1 + i))

let text (t : t) : string list =
  Array.to_list t.cells
  |> List.map (fun row ->
         let s = String.concat "" (Array.to_list (Array.map (fun (c : Vt.cell) -> c.glyph) row)) in
         let n = ref (String.length s) in
         while !n > 0 && s.[!n - 1] = ' ' do decr n done;
         String.sub s 0 !n)

(*****************************************************************************)
(* The difference, as bytes *)
(*****************************************************************************)

let cup (r : int) (c : int) : string = Printf.sprintf "\x1b[%d;%dH" (r + 1) (c + 1)

let sgr (a : Vt.attrs) : string =
  let color base (c : Vt.color) =
    match c with
    | Default -> []
    | Black -> [ base ] | Red -> [ base + 1 ] | Green -> [ base + 2 ] | Yellow -> [ base + 3 ]
    | Blue -> [ base + 4 ] | Magenta -> [ base + 5 ] | Cyan -> [ base + 6 ] | White -> [ base + 7 ]
  in
  let codes = (0 :: (if a.bold then [ 1 ] else [])) @ (if a.reverse then [ 7 ] else []) @ color 30 a.fg @ color 40 a.bg in
  "\x1b[" ^ String.concat ";" (List.map string_of_int codes) ^ "m"

let refresh ~(before : t) (after : t) : string =
  let b = Buffer.create 256 in
  (* where the terminal's cursor is: where the last refresh left it,
     None when unknown (hidden, or after the last column: the wrap is
     pending); and its colours, plain between refreshes *)
  let at = ref before.cursor and pen = ref Vt.plain in
  let send (r : int) (c : int) (cell : Vt.cell) =
    if cell.attrs <> !pen then begin
      Buffer.add_string b (sgr cell.attrs);
      pen := cell.attrs
    end;
    Buffer.add_string b cell.glyph;
    at := if c + 1 < after.cols then Some (r, c + 1) else None
  in
  for r = 0 to after.rows - 1 do
    (* a row shared by the two versions hasn't changed *)
    if r >= before.rows || before.cells.(r) != after.cells.(r) then
      for c = 0 to after.cols - 1 do
        let now = after.cells.(r).(c) in
        if cell before r c <> now then begin
          (match !at with
          | Some (r', c') when r' = r && c' = c -> ()
          (* the gap sent again, when cheaper than the move and in the
             colours already set *)
          | Some (r', c')
            when r' = r && c' < c
                 && c - c' < String.length (cup r c)
                 && List.for_all (fun i -> after.cells.(r).(i).attrs = !pen) (List.init (c - c') (fun i -> c' + i)) ->
              for i = c' to c - 1 do
                send r i after.cells.(r).(i)
              done
          | _ -> Buffer.add_string b (cup r c));
          send r c now
        end
      done
  done;
  if !pen <> Vt.plain then Buffer.add_string b (sgr Vt.plain);
  (match after.cursor with
  | Some (r, c) ->
      if !at <> Some (r, c) then Buffer.add_string b (cup r c);
      if before.cursor = None then Buffer.add_string b "\x1b[?25h"
  | None -> if before.cursor <> None then Buffer.add_string b "\x1b[?25l");
  Buffer.contents b

let redraw (t : t) : string =
  let blank = { (create ~rows:t.rows ~cols:t.cols) with cursor = Some (0, 0) } in
  (* the terminal's cursor shown, so that a hidden one is hidden *)
  "\x1b[0m\x1b[2J\x1b[H\x1b[?25h" ^ refresh ~before:blank t
