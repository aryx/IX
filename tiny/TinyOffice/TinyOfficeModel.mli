(* What TinyOffice's parts share: the page's objects, what the selected
 * box is being edited by, and the office's record, the whole state of
 * the program, which the shell (TinyOffice) and each part's keys and
 * mouse change in place.
 *
 *     office
 *       page      obj list, the bottom one first; each obj a kind, a box
 *                 and its data, a string (TinyOffice.mli says why)
 *       undo      the pages before, each a list as it was: an edit
 *                 makes a new list, so the old page is kept as it is
 *       sel       the selected object, its place in page
 *       editing   what the selected box is edited by: a text's doc,
 *                 a sheet's cell, a drawing's tool, a paint's colour
 *       where     the window: the file, the size, the page shown
 *
 * An edit is a value, and a part's keys a function of it: Writing d,
 * Cell (c, r, typed), Sketch (tool, stroke), Painting (ink, brush,
 * last), Naming typed; the menus' commands too (command).
 *)

(* the page's colours, bytes of the machine's palette: white, black, a
 * frame's grey, the selected box's blue, the status line's light grey,
 * selected text's pale blue *)
val white : int
val black : int
val grey : int
val blue : int
val light_grey : int
val pale_blue : int

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
 * sheet's cell, its column and row, and what is being typed in it
 * (None: the cell chosen, nothing typed yet); a drawing's tool (0 a
 * box, 1 an arrow, 2 a text), and the stroke the left button is making,
 * from where it went down to where it is, in the box; a paint's colour
 * (its place in pixel_letters), its brush (0 thin, 1 thick), and the
 * pixel where the left button last was, when it is down; the selected
 * sheet's new name, being typed *)
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

(* (eleven fields: tiny-ml's most on tiny-machine) *)
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
  menu : TinyLibGUI.menu_state;  (* the menus', and the mouse's buttons as
                                  * last seen *)
  mutable message : string;      (* the status line's *)
  mutable prefix : bool;         (* C-x typed *)
  where : window;                (* the file, the window's size, the page
                                  * shown *)
}

(* the page with its i-th object replaced, or removed (None) *)
val replace : obj list -> int -> obj option -> obj list

(* the topmost object under (x, y) on the page shown: its place, -1 *)
val hit : office -> int -> int -> int

(* a change about to be made: the page as it is, kept for undo *)
val keep : office -> unit

(* the selected box's data changed (a change, for undo, when it is
 * other data) *)
val change : office -> string -> unit
