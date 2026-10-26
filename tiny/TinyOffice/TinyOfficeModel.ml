(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeModel.mli *)
open TinyLibGUI

(* the page's colours, bytes of the machine's palette: white, black, a
 * frame's grey, the selected box's blue, the status line's light grey,
 * selected text's pale blue *)
let white = 255
let black = 0
let grey = 153
let blue = 3
let light_grey = 204
let pale_blue = 188

(* an object of the document: its kind ("text", "sheet", "drawing",
 * "paint", "chart"), its box in pixels, its data, its name (a sheet's,
 * which a chart names; "" for the others), the page it is on (from 0) *)
type obj = {
  kind : string; x : int; y : int; w : int; h : int; data : string;
  called : string; page_no : int }

(* the window on the document: its file, its size in pixels, the page
 * shown, how many pages there are (a page with nothing on it counts) *)
type window = {
  file : string; width : int; height : int; mutable shown : int;
  mutable pages : int }

(* a text box being edited: its characters and their styles (a byte
 * each: bold 1, italic 2, underlined 4, large 8), the cursor, the
 * selection's other end (the cursor's place: none), the style of what
 * is typed next, whether the left button is selecting *)
type doc = {
  mutable txt : string; mutable sty : string; mutable cur : int;
  mutable anchor : int; mutable typing : int; mutable selecting : bool }

(* what the selected box is edited by: nothing; a text box's text; a
 * sheet's cell, its column and row, and what is being
 * typed in it (None: the cell chosen, nothing typed yet); a drawing's
 * tool (0 a box, 1 an arrow, 2 a text), and the stroke the left button
 * is making, from where it went down to where it is, in the box; a
 * paint's colour (its place in pixel_letters), its brush (0 thin, 1
 * thick), and the pixel where the left button last was, when it is
 * down; the selected sheet's new name, being typed *)
type edit = Nothing | Writing of doc | Cell of int * int * string option
  | Sketch of int * (int * int * int * int) option
  | Painting of int * int * (int * int) option | Naming of string

(* what the menus ask for: to save, to quit, to undo, to delete the
 * selected box, a new box of a kind, a drawing's tool; in a text, to
 * cut, copy, paste, a style (0: plain); in a paint, a colour, a brush,
 * the picture cleared; in a sheet, a name typed, a chart of the chosen
 * cell's column; the next page shown (1) or the one before (-1), a new
 * page after it, the page deleted *)
type command = Do_save | Do_quit | Do_undo | Do_delete | Do_add of string
  | Do_tool of int | Do_cut | Do_copy | Do_paste | Do_style of int
  | Do_ink of int | Do_brush of int | Do_clear | Do_name | Do_chart
  | Do_page of int | Do_new_page | Do_delete_page

type office = {
  mutable page : obj list;       (* the objects, the bottom one first *)
  mutable undo : obj list list;  (* the pages before, the last first *)
  mutable clean : obj list;      (* the page as it was last saved *)
  mutable sel : int;             (* the selected object, its place in page;
                                  * -1 none *)
  mutable editing : edit;        (* what the selected box is edited by *)
  mutable drag : (int * int * int * obj * bool) option;
                                 (* a box grabbed: the object, where the
                                  * mouse was, the object then, resizing *)
  mutable at : int * int;        (* the last click *)
  menu : menu_state;             (* the menus', and the mouse's buttons as
                                  * last seen *)
  mutable message : string;      (* the status line's *)
  mutable prefix : bool;         (* C-x typed *)
  where : window;                (* the file, the window's size, the page
                                  * shown *)
}

(* (eleven fields: tiny-ml's most on tiny-machine) *)

(*****************************************************************************)
(* The page's objects *)
(*****************************************************************************)

(* the page with its i-th object replaced, or removed (None) *)
let rec replace (l : obj list) (i : int) (b : obj option) : obj list =
  match l with
  | x :: rest ->
    if i > 0 then x :: replace rest (i - 1) b
    else (match b with Some b -> b :: rest | None -> rest)
  | [] -> []

(* the topmost object under (x, y) on the page shown: its place, -1 *)
let hit (o : office) (x : int) (y : int) : int =
  let rec go i found = function
    | (b : obj) :: rest ->
      go (i + 1)
        (if b.page_no = o.where.shown && x >= b.x && x < b.x + b.w
            && y >= b.y && y < b.y + b.h then i
         else found) rest
    | [] -> found in
  go 0 (-1) o.page

(* a change about to be made: the page as it is, kept for undo *)
let keep (o : office) = o.undo <- o.page :: o.undo


(* the selected box's data changed (a change, for undo, when it is
 * other data) *)
let change (o : office) (data : string) =
  let b = List.nth o.page o.sel in
  if data <> b.data then
    (keep o; o.page <- replace o.page o.sel (Some { b with data }))
