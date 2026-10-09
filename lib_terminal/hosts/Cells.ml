(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Cells.mli *)

type rgb = int * int * int

type surface = {
  w : int;
  h : int;
  fill : int * int * int * int -> rgb -> unit;
  glyph : int -> int -> rgb -> string -> unit;
}

(*****************************************************************************)
(* Keys *)
(*****************************************************************************)

let key (alt : bool) (ctrl : bool) (name : string) : string option =
  if String.length name = 1 && not ctrl then Some (if alt then "\x1b" ^ name else name) else Vt.key ~alt ~ctrl name

let click (button : int) (row : int) (col : int) : string = Printf.sprintf "\x1b[<%d;%d;%dM" button (col + 1) (row + 1)

(*****************************************************************************)
(* The colours *)
(*****************************************************************************)

(* the CGA's: a colour's parts are 0 or 170, 85 or 255 when bright;
 * dark yellow is brown *)
let cga (c : Vt.color) (bright : bool) : rgb =
  let v (on : bool) : int = if bright then (if on then 255 else 85) else if on then 170 else 0 in
  match c with
  | Vt.Black -> (v false, v false, v false)
  | Vt.Red -> (v true, v false, v false)
  | Vt.Green -> (v false, v true, v false)
  | Vt.Yellow -> if bright then (255, 255, 85) else (170, 85, 0)
  | Vt.Blue -> (v false, v false, v true)
  | Vt.Magenta -> (v true, v false, v true)
  | Vt.Cyan -> (v false, v true, v true)
  | Vt.White | Vt.Default -> (v true, v true, v true)
  | Vt.Rgb (r, g, b) -> (r, g, b)

let colors (a : Vt.attrs) : rgb * rgb =
  let fg = cga a.fg a.bold in
  let bg = match a.bg with Vt.Default -> (0, 0, 0) | c -> cga c false in
  if a.reverse then (bg, fg) else (fg, bg)

(*****************************************************************************)
(* The box characters *)
(*****************************************************************************)

let box (glyph : string) (w : int) (h : int) : (int * int * int * int) list option =
  let cx = w / 2 and cy = h / 2 in
  (* a line across at y, from x0 to before x1; one down at x *)
  let across (y : int) (x0 : int) (x1 : int) = (x0, y, x1, y + 1) in
  let down (x : int) (y0 : int) (y1 : int) = (x, y0, x + 1, y1) in
  (* a corner: an arm to the right (or to the left), one below (or
   * above), from the lines' crossing at (x, y) *)
  let arms (right : bool) (below : bool) (x : int) (y : int) =
    [ (if right then across y x w else across y 0 (x + 1)); (if below then down x y h else down x 0 (y + 1)) ] in
  (* a double one: the outer corner a pixel away from the arms, the
   * inner one a pixel towards them *)
  let double (right : bool) (below : bool) =
    let xo = if right then cx - 1 else cx + 1 and yo = if below then cy - 1 else cy + 1 in
    let xi = if right then cx + 1 else cx - 1 and yi = if below then cy + 1 else cy - 1 in
    arms right below xo yo @ arms right below xi yi in
  match glyph with
  | "─" -> Some [ across cy 0 w ]
  | "│" -> Some [ down cx 0 h ]
  | "┌" -> Some (arms true true cx cy)
  | "┐" -> Some (arms false true cx cy)
  | "└" -> Some (arms true false cx cy)
  | "┘" -> Some (arms false false cx cy)
  | "═" -> Some [ across (cy - 1) 0 w; across (cy + 1) 0 w ]
  | "║" -> Some [ down (cx - 1) 0 h; down (cx + 1) 0 h ]
  | "╔" -> Some (double true true)
  | "╗" -> Some (double false true)
  | "╚" -> Some (double true false)
  | "╝" -> Some (double false false)
  | _ -> None

(*****************************************************************************)
(* What changed *)
(*****************************************************************************)

type run = { row : int; col : int; glyphs : string list; fg : rgb; bg : rgb }

let runs (before : Curses.t option) (next : Curses.t) : run list =
  let rows = Curses.rows next and cols = Curses.cols next in
  let before = match before with Some b when Curses.rows b = rows && Curses.cols b = cols -> Some b | _ -> None in
  let moved = match before with Some b -> Curses.cursor_at b <> Curses.cursor_at next | None -> false in
  let under (t : Curses.t) (r : int) (c : int) : bool = moved && Curses.cursor_at t = Some (r, c) in
  let changed (r : int) (c : int) : bool =
    match before with
    | None -> true
    | Some b -> Curses.cell b r c <> Curses.cell next r c || under b r c || under next r c in
  let cursor_row (t : Curses.t) : int = match Curses.cursor_at t with Some (r, _) -> r | None -> -1 in
  (* a row that is the screen before's own (Curses.same) has nothing
   * changed, but the cursor on it: not looked at (old: every cell of
   * every row compared, 1.2 ms of a key's at 51 by 113) *)
  let untouched (r : int) : bool =
    match before with
    | Some b -> Curses.same b next r && not (moved && (cursor_row b = r || cursor_row next = r))
    | None -> false in
  let out : run list ref = ref [] in
  for r = 0 to rows - 1 do
   if not (untouched r) then begin
    (* the run being gathered, its cells the last first *)
    let current : (int * string list * rgb * rgb) option ref = ref None in
    let close () : unit =
      (match !current with Some (col, gs, fg, bg) -> out := { row = r; col; glyphs = List.rev gs; fg; bg } :: !out | None -> ());
      current := None in
    for c = 0 to cols - 1 do
      if not (changed r c) then close ()
      else begin
        let cell : Vt.cell = Curses.cell next r c in
        let fg, bg = colors cell.attrs in
        match !current with
        | Some (col, gs, f, b) when f = fg && b = bg -> current := Some (col, cell.glyph :: gs, f, b)
        | _ -> close (); current := Some (c, [ cell.glyph ], fg, bg)
      end
    done;
    close ()
   end
  done;
  List.rev !out

(*****************************************************************************)
(* Painted *)
(*****************************************************************************)

let paint (s : surface) (r : run) : unit =
  let y = r.row * s.h in
  s.fill (r.col * s.w, y, (r.col + List.length r.glyphs) * s.w, y + s.h) r.bg;
  List.iteri (fun (i : int) (g : string) ->
    let x = (r.col + i) * s.w in
    match box g s.w s.h with
    | Some lines -> List.iter (fun ((x0, y0, x1, y1) : int * int * int * int) -> s.fill (x + x0, y + y0, x + x1, y + y1) r.fg) lines
    | None -> if g <> " " then s.glyph x y r.fg g) r.glyphs

let show (s : surface) (before : Curses.t option) (next : Curses.t) : unit =
  List.iter (paint s) (runs before next);
  match Curses.cursor_at next with
  | Some (r, c) when r >= 0 && r < Curses.rows next && c >= 0 && c < Curses.cols next ->
      let fg, _ = colors (Curses.cell next r c).attrs in
      s.fill (c * s.w, ((r + 1) * s.h) - 2, (c + 1) * s.w, (r + 1) * s.h) fg
  | _ -> ()
