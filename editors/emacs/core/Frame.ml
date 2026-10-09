(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Frame.mli. efuns' Frame is its design's source: a buffer, a
 * point, a first line, a status line; the rows are made another way. *)
open Efuns

let create (caps : caps) (buf : buffer) : frame = {
  frm_buffer = buf;
  frm_point = Text.new_point buf.buf_text (Text.get_position buf.buf_point);
  frm_start = Text.new_point buf.buf_text (Text.get_position buf.buf_start);
  frm_goal = None; frm_xpos = 0; frm_ypos = 0; frm_width = 0; frm_height = 0; frm_has_status_line = true; frm_shown = None; caps;
}

let kill (frame : frame) : unit =
  let buf = frame.frm_buffer in
  Text.set_position buf.buf_text buf.buf_point (Text.get_position frame.frm_point);
  Text.set_position buf.buf_text buf.buf_start (Text.get_position frame.frm_start);
  Text.remove_point buf.buf_text frame.frm_point;
  Text.remove_point buf.buf_text frame.frm_start

let change_buffer (frame : frame) (buf : buffer) : unit =
  kill frame;
  frame.frm_buffer <- buf;
  frame.frm_point <- Text.new_point buf.buf_text (Text.get_position buf.buf_point);
  frame.frm_start <- Text.new_point buf.buf_text (Text.get_position buf.buf_start);
  frame.frm_goal <- None;
  let editor = Globals.editor in
  if List.memq buf editor.edt_buffers then
    editor.edt_buffers <- buf :: List.filter (fun (b : buffer) -> b != buf) editor.edt_buffers

let point (frame : frame) : int = Text.get_position frame.frm_point
let goto (frame : frame) (pos : int) : unit = Text.set_position frame.frm_buffer.buf_text frame.frm_point pos

(*****************************************************************************)
(* Columns *)
(*****************************************************************************)

(* what is shown for the character at pos, when it is at col: its
 * cells' text, how many bytes it is, how many cells *)
let shown (text : Text.t) (pos : int) (col : int) : string * int * int =
  let c = Text.get text pos in
  if c = '\t' then (let n = 8 - (col mod 8) in (String.make n ' ', 1, n))
  else if c < ' ' then ("^" ^ String.make 1 (Char.chr (Char.code c + 64)), 1, 2)
  else if c = '\x7f' then ("^?", 1, 2)
  else if c < '\x80' then (String.make 1 c, 1, 1)
  else begin
    let s = Text.sub text pos (min 4 (Text.length text - pos)) in
    let code, n = Utf8.decode s 0 in
    (* a byte that is no character's: its number, as Emacs shows it; a
     * wide character has two cells, a combining one none: it is drawn
     * over the character before (at a line's start it has no such) *)
    if code = 0xFFFD && s.[0] <> '\xef' then (Printf.sprintf "\\%03o" (Char.code c), 1, 4)
    else (String.sub s 0 n, n, if col = 0 then max 1 (Utf8.width code) else Utf8.width code)
  end

let next (text : Text.t) (pos : int) : int =
  if pos >= Text.length text then pos else let _, bytes, _ = shown text pos 0 in pos + bytes

(* (the bytes of a character after its first are 10xxxxxx) *)
let rec prev (text : Text.t) (pos : int) : int =
  if pos <= 0 then 0
  else if pos > 1 && Char.code (Text.get text (pos - 1)) land 0xC0 = 0x80 then prev text (pos - 1)
  else pos - 1

(* along the line from bol, a column counted at each character, while
 * [go] says so of the position and its column *)
let rec along (text : Text.t) (pos : int) (col : int) (go : int -> int -> bool) : int * int =
  if pos < Text.length text && Text.get text pos <> '\n' && go pos col then begin
    let _, bytes, cells = shown text pos col in
    along text (pos + bytes) (col + cells) go
  end
  else (pos, col)

let column (text : Text.t) (pos : int) : int =
  snd (along text (Text.bol text pos) 0 (fun (p : int) (_ : int) -> p < pos))

let position_of_column (text : Text.t) (bol : int) (col : int) : int =
  fst (along text bol 0 (fun (_ : int) (c : int) -> c < col))

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

(* position_at's: the cell asked of the rows being made, and the
 * position found for it *)
let at_cell : (int * int) option ref = ref None
let at_position : int ref = ref 0

let text_rows (frame : frame) : int = frame.frm_height - (if frame.frm_has_status_line then 1 else 0)

let reversed (frame : frame) : (int * int) list =
  List.concat_map (fun (f : frame -> (int * int) list) -> f frame) Globals.editor.edt_highlights

(* the rows of text shown, from frm_start: made *)
let layout (frame : frame) : shown =
  let text = frame.frm_buffer.buf_text in
  let height = text_rows frame and width = frame.frm_width in
  let rows : (int * string * Vt.attrs) list array = Array.make (max 0 height) [] in
  let starts = Array.make (max 0 height) max_int and stop = ref (Text.length text + 1) in
  let len = Text.length text in
  let start = Text.get_position frame.frm_start in
  let last = ref start in
  (* the piece being made: a text all shown one way *)
  let plain = Globals.editor.edt_plain in
  let piece = Buffer.create width and piece_col = ref 0 and piece_attrs = ref plain in
  let flush (row : int) : unit =
    if Buffer.length piece > 0 then rows.(row) <- (!piece_col, Buffer.contents piece, !piece_attrs) :: rows.(row);
    Buffer.clear piece in
  let put (row : int) (col : int) (s : string) (attrs : Vt.attrs) : unit =
    if attrs <> !piece_attrs then flush row;
    if Buffer.length piece = 0 then begin piece_col := col; piece_attrs := attrs end;
    Buffer.add_string piece s in
  (* the colors: the line's pieces not passed yet, and where it starts *)
  let colors = Ebuffer.colors frame.frm_buffer !last (max 1 height) in
  let line = ref (match colors with Some (_, n) -> n | None -> 0) and bol = ref !last in
  let of_line (n : int) : (int * int * Vt.attrs) list =
    match colors with Some (c, _) when n < Array.length c -> c.(n) | _ -> [] in
  let pieces = ref (of_line !line) in
  let reversed = reversed frame in
  let rec attrs (pos : int) : Vt.attrs =
    match !pieces with
    | (col, n, _) :: rest when col + n <= pos - !bol -> pieces := rest; attrs pos
    (* (a color over the editor's ground) *)
    | (col, _, a) :: _ when col <= pos - !bol -> if a.bg = Vt.Default then { a with bg = plain.bg } else a
    | _ -> plain in
  let attrs (pos : int) : Vt.attrs =
    let a = attrs pos in
    if List.exists (fun ((first, after) : int * int) -> first <= pos && pos < after) reversed then { a with reverse = true } else a in
  at_position := len;
  let rec go (pos : int) (row : int) (col : int) : unit =
    (* (what is shown at a cell asked: the last position at it or before it on its row) *)
    (match !at_cell with
     | Some (r, c) when row < r || (row = r && col <= c) -> at_position := pos
     | _ -> ());
    if row >= height then stop := pos
    else begin
      if col = 0 then starts.(row) <- pos;
      if pos = len || Text.get text pos = '\n' then begin
        flush row;
        if pos < len then begin
          if row + 1 < height then last := pos + 1;
          incr line;
          bol := pos + 1;
          pieces := of_line !line;
          go (pos + 1) (row + 1) 0
        end
      end
      else begin
        let glyph, bytes, cells = shown text pos col in
        (* the last column is the fold's mark's *)
        if col + cells > width - 1 then begin
          put row col (String.make (max 0 (width - 1 - col)) ' ' ^ "\\") plain;
          flush row;
          go pos (row + 1) 0
        end
        else begin
          put row col glyph (attrs pos);
          go (pos + bytes) row (col + cells)
        end
      end
    end in
  go start 0 0;
  { sh_text = text; sh_version = Text.version text; sh_start = start; sh_width = width; sh_height = height;
    sh_mode = frame.frm_buffer.buf_major_mode; sh_reversed = reversed; sh_plain = plain;
    sh_rows = rows; sh_starts = starts; sh_stop = !stop; sh_last = !last; sh_line = Text.line text start; sh_screen = None }

let position_at (frame : frame) (row : int) (col : int) : int =
  at_cell := Some (row, col);
  ignore (layout frame);
  at_cell := None;
  !at_position

(* OPTIMIZATION: a frame's rows are kept (frm_shown) and not made again
 * while what they were made of is the same: the text and its version,
 * the first line, the frame's size, the mode, what is in reverse, the
 * editor's plain color. A key that moves the point in what is shown,
 * the commonest, then costs the point's place found (its row from the
 * rows' starts, its column counted along that row) and the status
 * line; and a frame as wide as the screen takes its rows from the
 * screen it last wrote them on (Curses.take), so that a host finds them
 * the same rows and compares no cell of them (Curses.same). [cache]
 * unset is the simple way, to compare (-nocache; tests/keys.sh does).
 * old: let rows, cursor, last = layout frame, at each key, twice (once
 *   to know whether the point is shown).
 * A line down in tiny/TinyML.ml at 51 rows of 113 columns, 40 times:
 * 0.2 ms a key by OCaml's code, 0.5 by mini-ml's on arm64, 140 on arm
 * under mini-5i; 2.0, 7.0 and 1,900 before (the author, of mini-9pi, 2026-10-09: "If
 * i Put the arrow key down for a while and then stop, it still
 * continues to go down"). *)
let cache : bool ref = ref true

let rows (frame : frame) : shown =
  let text = frame.frm_buffer.buf_text in
  match frame.frm_shown with
  | Some s when !cache && s.sh_text == text && s.sh_version = Text.version text && s.sh_start = Text.get_position frame.frm_start
                && s.sh_width = frame.frm_width && s.sh_height = text_rows frame && s.sh_mode == frame.frm_buffer.buf_major_mode
                && s.sh_plain = Globals.editor.edt_plain && s.sh_reversed = reversed frame -> s
  | _ ->
      let s = layout frame in
      frame.frm_shown <- Some s;
      s

(* where the point is in the rows (a row and a column, the frame's), if it is *)
let cursor (frame : frame) (s : shown) : (int * int) option =
  let text = frame.frm_buffer.buf_text and point = point frame in
  if point < s.sh_start || point >= s.sh_stop then None
  else begin
    (* its row: the last that starts at it or before *)
    let rec row (r : int) : int = if r + 1 < Array.length s.sh_starts && s.sh_starts.(r + 1) <= point then row (r + 1) else r in
    let rec col (pos : int) (c : int) : int =
      if pos >= point then c else (let _, bytes, cells = shown text pos c in col (pos + bytes) (c + cells)) in
    if Array.length s.sh_starts = 0 then None else (let r = row 0 in Some (r, col s.sh_starts.(r) 0))
  end

let point_shown (frame : frame) : bool = cursor frame (rows frame) <> None
let last_line (frame : frame) : int = (rows frame).sh_last

let recenter (frame : frame) (above : int) : unit =
  let text = frame.frm_buffer.buf_text in
  Text.set_position text frame.frm_start (Text.forward_line text (point frame) (-above))

(* --**-  name  (mode)  L1 C0 -----: ** for a buffer modified *)
let status (frame : frame) (s : shown) : string =
  let buf = frame.frm_buffer in
  (* (the line's number: the first line shown's, and the lines from it) *)
  let line = (if point frame >= s.sh_start then s.sh_line + Text.newlines buf.buf_text s.sh_start (point frame) else Text.line buf.buf_text (point frame)) in
  let s = Printf.sprintf "--%s-  %s  (%s)  L%d C%d " (if Ebuffer.modified buf then "**" else "--") buf.buf_name
      buf.buf_major_mode.maj_name (line + 1) (column buf.buf_text (point frame)) in
  let n = Utf8.length s in
  if n >= frame.frm_width then Utf8.sub s 0 frame.frm_width else s ^ String.make (frame.frm_width - n) '-'

let display (frame : frame) (screen : Curses.t) : Curses.t * (int * int) =
  (* the point's line in the middle; first of all, if a folded line
   * still hides the point *)
  if not (point_shown frame) then recenter frame ((frame.frm_height - 1) / 2);
  if not (point_shown frame) then recenter frame 0;
  let s = rows frame in
  (* the screen these rows are on already, as they are: a frame as wide
   * as the screen, at the same place *)
  let written = (match s.sh_screen with
    | Some (old, y, x) when !cache && y = frame.frm_ypos && x = 0 && frame.frm_xpos = 0 && frame.frm_width = Curses.cols screen
                            && Curses.cols old = Curses.cols screen && Curses.rows old = Curses.rows screen -> Some old
    | _ -> None) in
  let screen = ref screen in
  Array.iteri (fun (i : int) (row : (int * string * Vt.attrs) list) ->
    screen := (match written with
      | Some old -> Curses.take (frame.frm_ypos + i) old !screen
      | None -> Curses.pieces (frame.frm_ypos + i)
                  (List.rev_map (fun ((col, text, attrs) : int * string * Vt.attrs) -> (frame.frm_xpos + col, text, attrs)) row) !screen)) s.sh_rows;
  if frame.frm_has_status_line then
    screen := Curses.put ~attrs:{ Globals.editor.edt_plain with reverse = true } (frame.frm_ypos + frame.frm_height - 1) frame.frm_xpos (status frame s) !screen;
  let row, col = match cursor frame s with Some c -> c | None -> (0, 0) in
  (!screen, (frame.frm_ypos + row, frame.frm_xpos + col))

let written (frame : frame) (screen : Curses.t) : unit =
  match frame.frm_shown with
  | Some s -> s.sh_screen <- Some (screen, frame.frm_ypos, frame.frm_xpos)
  | None -> ()
