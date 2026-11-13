(* What TinyOffice's parts share: the page's objects, the state of the
 * edit in the selected box, and the office's record. That record is
 * the whole state of the program; the shell (TinyOffice) and each
 * part's keys and mouse change it in place.
 *
 *     office
 *       page      obj list, the bottom one first; each obj has a kind,
 *                 a box and its data, a string (TinyOffice.mli says why)
 *       undo      the earlier pages, each list as it was: an edit makes
 *                 a new list, so the old page stays unchanged
 *       sel       the index of the selected object in page
 *       editing   the edit going on in the selected box: a text's doc,
 *                 a sheet's cell, a drawing's tool, a paint's colour
 *       where     the window: the file, the size, the page shown
 *
 * An edit in progress is a value ([edit]), and a part's keys are
 * handled by a function of it. The menus' commands are values too
 * ([command]).
 *)

(* Bytes of the machine's palette. [grey] is for a frame, [blue] for the
 * selected box, [light_grey] for the status line, and [pale_blue] for
 * selected text. *)
val white : int
val black : int
val grey : int
val blue : int
val light_grey : int
val pale_blue : int

type kind =
  | Box_text
  | Box_sheet
  | Box_drawing
  | Box_paint
  | Box_chart

(* The box is in pixels. [called] is a sheet's name, by which a chart
 * refers to it ("" for other kinds). [page_no] counts from 0. *)
type obj = {
  kind : kind; x : int; y : int; w : int; h : int; data : string;
  called : string; page_no : int }

(* The word for a kind, as it is written in the file and on a box's
 * tab. *)
val kind_name : kind -> string

(* The size is in pixels. [pages] counts the empty pages too. *)
type window = {
  file : string; width : int; height : int; mutable shown : int;
  mutable pages : int }

(* A text box being edited. [sty] has one style byte per character
 * (bold 1, italic 2, underlined 4, large 8). [anchor] is the other end
 * of the selection from [cur]; when it equals [cur], nothing is
 * selected. [typing] is the style of what is typed next. *)
type doc = {
  mutable txt : string; mutable sty : string; mutable cur : int;
  mutable anchor : int; mutable typing : int; mutable selecting : bool }

(* The edit going on in the selected box.
 * - [Cell (c, r, typed)]: a sheet's cell, and what is being typed in it
 *   (None when the cell is chosen but nothing is typed yet).
 * - [Sketch (tool, stroke)]: a drawing's tool (0 a box, 1 an arrow,
 *   2 a text), and the stroke the left button is making, from where it
 *   went down to where it is now, in the box's coordinates.
 * - [Painting (ink, brush, last)]: a paint's colour (its index in
 *   pixel_letters), its brush (0 thin, 1 thick), and the pixel where
 *   the left button last was, while it is down.
 * - [Naming typed]: the selected sheet's new name, being typed. *)
type edit = Nothing | Writing of doc | Cell of int * int * string option
  | Sketch of int * (int * int * int * int) option
  | Painting of int * int * (int * int) option | Naming of string

(* What the menus ask for. [Do_style 0] is plain. [Do_clear] clears a
 * paint's picture. [Do_name] starts typing a sheet's name, and
 * [Do_chart] makes a chart of the chosen cell's column. [Do_page 1]
 * shows the next page and [Do_page (-1)] the one before; [Do_new_page]
 * adds a page after the one shown. *)
type command = Do_save | Do_quit | Do_undo | Do_delete | Do_add of kind
  | Do_tool of int | Do_cut | Do_copy | Do_paste | Do_style of int
  | Do_ink of int | Do_brush of int | Do_clear | Do_name | Do_chart
  | Do_page of int | Do_new_page | Do_delete_page

(* The record has eleven fields, the most tiny-ml allows on
 * tiny-machine. *)
type office = {
  mutable page : obj list;       (* the objects, the bottom one first *)
  mutable undo : obj list list;  (* the pages before, the last first *)
  mutable clean : obj list;      (* the page as it was last saved *)
  mutable sel : int option;      (* the selected object's index in
                                  * page *)
  mutable editing : edit;        (* the edit in the selected box *)
  mutable drag : (int * int * int * obj * bool) option;
                                 (* a box being dragged: its index, where
                                  * the mouse was, the object as it was
                                  * then, and whether it is resized *)
  mutable at : int * int;        (* the last click *)
  menu : TinyLibGUI.menu_state;  (* the menus' state, including the
                                  * mouse's buttons as last seen *)
  mutable message : string;      (* the status line's text *)
  mutable prefix : bool;         (* whether C-x was just typed *)
  where : window;                (* the file, the window's size, the page
                                  * shown *)
}

(* The page with its i-th object replaced, or removed when the object
 * given is None. *)
val replace : obj list -> int -> obj option -> obj list

(* the index of the topmost object under (x, y) on the page shown *)
val hit : office -> int -> int -> int option

(* They are called while a box is edited, so a box is selected; they
 * raise Invalid_argument when none is. *)
val selected : office -> int
val selected_box : office -> obj

(* saves the page as it is for undo, before a change *)
val keep : office -> unit

(* sets the selected box's data; if the data differs, the change is
 * recorded for undo *)
val change : office -> string -> unit
