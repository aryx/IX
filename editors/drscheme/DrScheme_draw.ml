(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, its window's geometry and what every part draws with: the buttons, the lines of a text, the sections View: the texts and View: images; a string's characters are taken without a Seq, and text_view's x and y are a pair (docs/plans/plan_scheme.md) *)

(* See DrScheme_draw.mli *)

open Playground

(*****************************************************************************)
(* The window's geometry *)
(*****************************************************************************)

(* from the window's top-left corner, y going down, to the Playground's
 * centre *)
let at (x : float) (y : float) (s : shape) : shape = s |> move (x -. 500.) (500. -. y)
let box (c : color) (x : float) (y : float) (w : float) (h : float) : shape = rectangle c w h |> at (x +. (w /. 2.)) (y +. (h /. 2.))

let frame (c : color) (x : float) (y : float) (w : float) (h : float) : shape list =
  [ box c x y w 1.; box c x (y +. h -. 1.) w 1.; box c x y 1. h; box c (x +. w -. 1.) y 1. h ]

(* a character's cell: the text drawn in columns, as a code editor's *)
let cw = 11.
let lh = 20.

let glyph (c : color) (x : float) (y : float) (ch : char) : shape list =
  if ch = ' ' || ch = '\n' then [] else [ words c (String.make 1 ch) |> scale 1.55 |> at (x +. (cw /. 2.)) (y +. (lh /. 2.)) ]

let label (c : color) (x : float) (y : float) (s : string) : shape list = List.concat (List.mapi (fun i ch -> glyph c (x +. (float_of_int i *. cw)) y ch) (List.init (String.length s) (String.get s)))

(* the text in a proportional font, for the window's own words *)
let caption (c : color) (x : float) (y : float) (size : float) (s : string) : shape = words c s |> scale (size /. 10.) |> at x y

let title_h = 34.
let toolbar_y = 34.
let defs_y = 96.
let defs_h = 468.
let inter_y = 572.
let inter_h = 386.
let status_y = 960.
let text_x = 10.
let cols = int_of_float ((1000. -. (2. *. text_x)) /. cw)
let rows = int_of_float ((defs_h -. 8.) /. lh)

(* Windows XP's, which DrScheme 209 wore on it *)
let chrome = rgb 236 233 216
let title_blue = rgb 0 84 227
let dark = rgb 90 90 90
let error_color = rgb 200 0 0

(*****************************************************************************)
(* Buttons *)
(*****************************************************************************)

let inside (mx, my) (x, y, w, h) = mx >= x && mx < x +. w && my >= y && my < y +. h

(* the mouse from the Playground's centre to the window's corner *)
let mouse_at (computer : computer) : float * float = (computer.mouse.mx +. 500., 500. -. computer.mouse.my)

(* the toolbar's buttons *)
let step_button = (640., 42., 110., 46.)
let execute_button = (760., 42., 120., 46.)
let break_button = (890., 42., 100., 46.)
let language_button = (10., 964., 360., 32.)

(* a toolbar button: raised, its icon and its word *)
let button ((x, y, w, h) : float * float * float * float) (icon : shape list) (word : string) (enabled : bool) : shape list =
  [ box (rgb 250 250 245) x y w h ] @ frame (rgb 160 160 150) x y w h @ List.map (at (x +. 20.) (y +. (h /. 2.))) icon
  @ [ caption (if enabled then black else rgb 160 160 160) (x +. 24. +. ((w -. 24.) /. 2.)) (y +. (h /. 2.)) 16. word ]

(*****************************************************************************)
(* The lines of a text *)
(*****************************************************************************)

(* the lines of a text, each with the offset it starts at *)
let lines (s : string) : (int * string) list =
  let rec go start acc = match String.index_from_opt s start '\n' with Some j -> go (j + 1) ((start, String.sub s start (j - start)) :: acc) | None -> List.rev ((start, String.sub s start (String.length s - start)) :: acc) in
  go 0 []

(* the line and column of an offset *)
let place (s : string) (pos : int) : int * int =
  let ls = lines s in
  let rec go i = function (start, l) :: rest -> if pos <= start + String.length l || rest = [] then (i, pos - start) else go (i + 1) rest | [] -> (0, 0) in
  go 0 ls

let offset (s : string) (line : int) (col : int) : int =
  match List.nth_opt (lines s) line with Some (start, l) -> start + max 0 (min col (String.length l)) | None -> String.length s

(*****************************************************************************)
(* View: the texts *)
(*****************************************************************************)

(* DrScheme's colours for its program text *)
let paren_color = rgb 132 60 36
let symbol_color = rgb 38 38 128
let constant_color = rgb 41 128 38
let comment_color = rgb 194 116 31

(* each character's colour: a small lexer over the whole text *)
let colors (s : string) : color array =
  let n = String.length s in
  let a = Array.make n symbol_color in
  let fill i j c = for k = i to min (n - 1) (j - 1) do a.(k) <- c done in
  let delim c = String.contains " \n\t()[]\";'" c in
  let rec go i =
    if i < n then
      match s.[i] with
      | ';' ->
          let j = match String.index_from_opt s i '\n' with Some j -> j | None -> n in
          fill i j comment_color; go j
      | '"' ->
          let rec close j = if j >= n then n else if s.[j] = '\\' then close (j + 2) else if s.[j] = '"' then j + 1 else close (j + 1) in
          let j = close (i + 1) in
          fill i j constant_color; go j
      | '(' | ')' | '[' | ']' -> a.(i) <- paren_color; go (i + 1)
      | '\'' -> a.(i) <- constant_color; go (i + 1)
      | c when delim c -> go (i + 1)
      | _ ->
          let j = ref i in
          while !j < n && not (delim s.[!j]) do incr j done;
          let tok = String.sub s i (!j - i) in
          if s.[i] = '#' || float_of_string_opt tok <> None || tok = "true" || tok = "false" || tok = "empty" then fill i !j constant_color;
          go !j
  in
  go 0;
  a

(* the parenthesis matching the one beside the caret: DrScheme greys
   the expression between them *)
let matching (s : string) (caret : int) : (int * int) option =
  let n = String.length s in
  let rec back i depth = if i < 0 then None else match s.[i] with ')' | ']' -> back (i - 1) (depth + 1) | '(' | '[' -> if depth = 1 then Some i else back (i - 1) (depth - 1) | _ -> back (i - 1) depth in
  let rec fwd i depth = if i >= n then None else match s.[i] with '(' | '[' -> fwd (i + 1) (depth + 1) | ')' | ']' -> if depth = 1 then Some (i + 1) else fwd (i + 1) (depth - 1) | _ -> fwd (i + 1) depth in
  if caret > 0 && (s.[caret - 1] = ')' || s.[caret - 1] = ']') then Option.map (fun i -> (i, caret)) (back (caret - 1) 0)
  else if caret < n && (s.[caret] = '(' || s.[caret] = '[') then Option.map (fun j -> (caret, j)) (fwd caret 0)
  else None

(* [text_view ...]: lines of text from line [top], with backgrounds over
   character ranges *)
(* (ix: at, where it was ~x and ~y: eight parameters are one more than
 * mini-ml's code for arm takes) *)
let text_view ~(at : float * float) ~(rows : int) ~(top : int) (s : string) (color_of : int -> color) (shades : ((int * int) * color) list) (caret : int option) : shape list =
  let x, y = at in
  let shapes = ref [] in
  let push l = shapes := l @ !shapes in
  List.iteri
    (fun i (start, l) ->
      let row = i - top in
      if row >= 0 && row < rows then begin
        let ly = y +. (float_of_int row *. lh) in
        let len = min cols (String.length l) in
        (* the shades first, under the characters *)
        List.iter
          (fun ((a, b), c) ->
            let a = max a start and b = min b (start + len + 1) in
            if a < b then push [ box c (x +. (float_of_int (a - start) *. cw)) ly (float_of_int (b - a) *. cw) lh ])
          shades;
        for k = 0 to len - 1 do
          push (glyph (color_of (start + k)) (x +. (float_of_int k *. cw)) ly l.[k])
        done;
        match caret with
        | Some c when c >= start && c <= start + String.length l -> push [ box black (x +. (float_of_int (c - start) *. cw) -. 1.) (ly +. 1.) 2. (lh -. 2.) ]
        | _ -> ()
      end)
    (lines s);
  List.rev !shapes

(*****************************************************************************)
(* View: images *)
(*****************************************************************************)

let color_of_name (name : string) : color =
  match name with
  | "red" -> rgb 255 0 0
  | "green" -> rgb 0 160 0
  | "blue" -> rgb 0 0 255
  | "yellow" -> rgb 255 255 0
  | "gold" -> rgb 255 215 0
  | "orange" -> rgb 255 165 0
  | "purple" -> rgb 160 32 240
  | "black" -> black
  | "white" -> white
  | "gray" | "grey" -> rgb 190 190 190
  | "darkgray" | "darkgrey" -> rgb 110 110 110
  | "brown" -> rgb 165 42 42
  | "pink" -> rgb 255 192 203
  | "cyan" -> rgb 0 255 255
  | "magenta" -> rgb 255 0 255
  | "lightblue" -> rgb 173 216 230
  | "darkgreen" -> rgb 0 100 0
  | "navy" -> rgb 0 0 128
  | "tan" -> rgb 210 180 140
  | _ -> rgb 128 128 128

(* the language's description drawn by the Bigbang way's combinators *)
let rec picture (i : Scheme_image.t) : Bigbang.image =
  let mode (m : Scheme_image.mode) : Bigbang.mode = match m with Solid -> Solid | Outline -> Outline in
  match i with
  | Circle (r, md, c) -> Bigbang.circle r (mode md) (color_of_name c)
  | Ellipse (w, h, md, c) -> Bigbang.ellipse w h (mode md) (color_of_name c)
  | Rectangle (w, h, md, c) -> Bigbang.rectangle w h (mode md) (color_of_name c)
  | Triangle (s, md, c) -> Bigbang.triangle s (mode md) (color_of_name c)
  | Text (s, size, c) -> Bigbang.text s size (color_of_name c)
  | Scene (w, h) -> Bigbang.empty_scene w h
  | Beside (a, b) -> Bigbang.beside (picture a) (picture b)
  | Above (a, b) -> Bigbang.above (picture a) (picture b)
  | Overlay (a, b) -> Bigbang.overlay (picture a) (picture b)
  | Place (a, x, y, s) -> Bigbang.place_image (picture a) x y (picture s)
