(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficePaint.mli *)
open TinyLibPlayground
open TinyOfficeModel

(*****************************************************************************)
(* Paint *)
(*****************************************************************************)

(* A paint's data is its picture, a line a row of pixels, a letter a
 * pixel, its colour:
 *
 *     ..kkk..
 *     .krrrk.
 *
 * . white, k black, r red, g green, b blue, y yellow, o orange, p
 * purple, n brown, a grey (TinyLibPlayground's pixel_letters; a row
 * ends at its last colour that is not white). A pixel is a square of 4
 * by 4 on the page; a row is one word of fat pixels, its letters (made
 * the kernel's bytes when it is drawn), so a stroke draws again the
 * rows it went through, and nothing else. *)
let paint_names = [ "white"; "black"; "red"; "green"; "blue"; "yellow";
                    "orange"; "purple"; "brown"; "grey" ]

(* the picture's size in pixels, in box b *)
let paint_cols (b : obj) = max 1 ((b.w - 4) / 4)
let paint_rows (b : obj) = max 1 ((b.h - 4) / 4)

(* the pixel under (x, y), in the picture *)
let pixel_at (b : obj) (x : int) (y : int) =
  (max 0 (min (paint_cols b - 1) ((x - b.x - 2) / 4)),
   max 0 (min (paint_rows b - 1) ((y - b.y - 2) / 4)))

(* a row without the white at its end *)
let rec trim_white (row : string) =
  let n = String.length row in
  if n > 0 && row.[n - 1] = '.' then trim_white (String.sub row 0 (n - 1))
  else row

(* The pixels a stroke of a brush covers, from (c0, r0) to (c1, r1), in
 * a letter, put in the picture: a thick brush 3 pixels wide. *)
let painted (b : obj) (letter : char) (brush : int) (c0 : int) (r0 : int)
    (c1 : int) (r1 : int) : string =
  let nrows = paint_rows b and ncols = paint_cols b in
  let rows = Array.make nrows "" in
  List.iteri (fun r row -> if r < nrows then rows.(r) <- row)
    (String.split_on_char '\n' b.data);
  let set c r =
    if c >= 0 && c < ncols && r >= 0 && r < nrows then begin
      let row = rows.(r) in
      let row =
        if String.length row > c then row
        else row ^ String.make (c + 1 - String.length row) '.' in
      rows.(r) <-
        trim_white
          (String.sub row 0 c ^ String.make 1 letter
           ^ String.sub row (c + 1) (String.length row - c - 1))
    end in
  let n = max 1 (max (abs (c1 - c0)) (abs (r1 - r0))) in
  for k = 0 to n do
    let c = c0 + ((c1 - c0) * k / n) and r = r0 + ((r1 - r0) * k / n) in
    if brush = 0 then set c r
    else
      for dr = -1 to 1 do
        for dc = -1 to 1 do set (c + dc) (r + dr) done
      done
  done;
  (* (the rows up to the last one that is not white) *)
  let last = ref (-1) in
  for r = 0 to nrows - 1 do if rows.(r) <> "" then last := r done;
  String.concat "" (List.init (!last + 1) (fun r -> rows.(r) ^ "\n"))

(* a stroke painted in the selected paint (the page changed, its undo
 * kept when the stroke began) *)
let paint (o : office) (ink : int) (brush : int) (c0 : int) (r0 : int)
    (c1 : int) (r1 : int) =
  let b = List.nth o.page o.sel in
  o.page <-
    replace o.page o.sel
      (Some { b with data = painted b pixel_letters.[ink] brush c0 r0 c1 r1 })

(* a key in a paint: a digit a colour (0 white, 1 black...); C-g leaves it *)
let paint_key (o : office) (brush : int) (k : int) =
  if k >= 48 && k < 58 then o.editing <- Painting (k - 48, brush, None)
  else if k = 7 then o.editing <- Nothing
  else
    o.message <-
      "a paint: the left button paints; the Paint menu, or a digit a colour; C-g"

(* A paint: each row a word of fat pixels, the rows that fit, as much
 * of each as fits *)
let paint_view (b : obj) : shape list =
  let ncols = paint_cols b and nrows = paint_rows b in
  let rec rows l r =
    match l with
    | row :: rest when r < nrows ->
        let n = min ncols (String.length row) in
        (if n > 0 then
           [ Move (b.x + 2, b.y + 2 + (4 * r),
                   Words (fat_pixels,
                          if n = String.length row then row
                          else String.sub row 0 n)) ]
         else [])
        @ rows rest (r + 1)
    | _ -> [] in
  rows (String.split_on_char '\n' b.data) 0
