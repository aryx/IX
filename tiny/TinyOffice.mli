(* tiny-office: a page of objects, each a kind of document in a box,
 * in one program (docs/plans/plan_tiny_office.md).
 *
 * Its full-size counterpart in m-ix is mini-office (apps/office/,
 * about 5,200 lines): a document of parts (text, sheet, picture,
 * drawing, chart), each a record of functions. This is the same idea
 * cut down, the compound document of the Xerox Star and of Smalltalk:
 *
 *     the shell          the page: selecting, moving, resizing, a new
 *         |              box, deleting, undo, the file
 *     a part             what one kind of object needs: how it is
 *         |              drawn, how it is edited (here: text, sheet,
 *         |              drawing)
 *     its data           a string, whatever the kind
 *
 * {b Every object's data is text}, and undo is the earlier pages, kept
 * in a list (an edit makes a new page, the old one is not changed).
 *
 * {b The file of a page is a document in mini-troff's format}
 * (plan_typesetting.md: Markdown's lines, \name[options]{text} for what
 * Markdown has not): each object a \box[x y w h]{...} around its
 * content, a text box's Markdown: **bold**, *italic*, a line "# "
 * large, \u{} underlined, \large{} large in a line; a sheet a table
 * (the columns' letters, then what was typed, a row a line), a drawing
 * or a paint a fence (```drawing, ```paint) of its lines. So a page is
 * read, or written, in emacs; and a Markdown file is opened as one text
 * box. (Being edited, a text box's data is its text with a mark where
 * the style changes, "a \{b}bold\{} word"; it is the file's Markdown
 * only in the file.)
 *
 * {b A text box is edited as it is shown} (WYSIWYG, the Alto's Bravo,
 * then MacWrite and Word): its text filled to the box's width, a word
 * that does not fit on the next line, each character in its style (the
 * kernel's fonts: italic slanted, large 16 by 32, bold its strokes
 * wider); a
 * line as tall as its largest character. A click puts the cursor, a
 * drag selects; the Format menu (or C-b, Tab, C-u, C-l) sets or takes
 * off a style, of the selection, or of what is typed next; Edit's Cut,
 * Copy, Paste (C-w, C-y). The box grows to show all of its text.
 * (Before, the box was edited by TinyEditorScreen, its marks shown, as
 * troff's source: the author wanted a word processor.)
 *
 * {b A sheet's data is a line a cell}: its name and what was typed in
 * it, "a1 Rent", "b1 500", "b3 =b1+b2". What was typed is a number, a
 * formula after an = (+ - * /, parentheses, cells, sum(b1:b2)), or
 * text. The values are computed at each view, each cell once, those it
 * needs first: a cell being computed counts as #CYCLE, which is what a
 * cell that needs itself shows. Integers only (tiny-ml's). It is edited
 * as any spreadsheet: a cell chosen (a click, the arrows), what is
 * typed replaces what was, shown in the status line as in a formula
 * bar, Enter puts it and goes down; Enter on a cell brings back what is
 * in it.
 *
 * {b A drawing's data is a line a shape}, at its place in the box:
 * "box 20 20 80 30 cpu", "arrow 100 35 180 90", "text 30 150 a note"
 * (pic's idea). An arrow goes across then up or down, a block
 * diagram's connector: the shapes are rectangles and words, and a
 * slanted line would need another kind. The left button drags a box or
 * an arrow, or places a text (the Draw menu, or Tab, changes the tool);
 * what is typed is the last shape's label.
 *
 * {b The menus} are pull-down menus across the top, TinyLibGUI's, as
 * in every office program since the Lisa's and the Macintosh's: File
 * (Save, Quit), Edit (Undo, Delete box), Insert (Text, Sheet,
 * Drawing), and Draw while a drawing is edited (its tools). Each item
 * shows its key.
 *
 * {b A paint's data is a line a row of pixels}, a letter a pixel, its
 * colour: ". white, k black, r red..." (TinyLibPlayground's
 * pixel_letters). A pixel is 4 by 4 on the page; the left button
 * paints, a line between the places the mouse was seen at, thin or
 * thick (3 pixels); the Paint menu, or a digit, a colour. A row is one
 * word of the kernel's fat pixels, so a stroke draws its rows again,
 * not the picture.
 *
 * The mouse and the keys:
 *
 *     left button          a click in a text box edits it, in a sheet
 *                          chooses a cell; elsewhere, the editing ends,
 *                          and the place is kept; on the menus, they
 *     the selected box     its tab above it (its kind) moves it; the
 *                          square at its corner resizes it
 *     right button, held   the box under it moves with the mouse; from
 *                          its bottom right corner, the box is resized
 *     C-o, C-x t, d, p     a new text box, sheet, drawing, paint,
 *                          where the last click was
 *     in a text            a character typed; Backspace, C-d; the
 *                          arrows, C-a, C-e; C-g no selection
 *     in a sheet           a character starts what is typed in the cell;
 *                          Enter, the arrows put it; C-g forgets it
 *     in a drawing         Tab another tool; the left button draws; a
 *                          character the last label's; C-g leaves it
 *     Backspace, Delete    the selected box removed
 *     C-_ (C-/)            undo: the page as it was before the last change
 *     C-x C-s, C-x C-c     save, quit (while editing too)
 *
 * {b Only what changed is drawn.} [view] is the page as shapes
 * (TinyLibPlayground's): the ground, a group for each object, one for the
 * status line. TinyLibGUI's run_canvas, which runs the office on
 * tiny-kernel (TinyKernel/user/office.ml, a few lines), compares each
 * group with the one it drew before and draws what changed: tiny-kernel
 * draws a character in some 13,000 instructions, and a page redrawn at
 * each key would be seconds of tiny-machine.
 *
 * This file uses no system calls: OCaml compiles
 * it for the tests (tests/TinyOffice_test.sh), tiny-ml for tiny-kernel.
 *
 * What is left out, for now: the chart (step 5 of the plan),
 * publishing (step 6), moving a drawing's shapes once drawn, a sheet's
 * floating point, its other functions than sum, and formulas that
 * follow a cell moved, a paint's fill and its colours other than ten,
 * other fonts and sizes (one font, 8 by 16, its italic and its double),
 * colours of text, paragraphs centred or justified, several pages, and
 * undo of the
 * typing inside a box (undo takes the page back to before the box was
 * edited).
 *)

type office

(* [create width height file text]: the office on a page of that size
 * in pixels, file the page's name, text the file's text ("" for a new
 * page) *)
val create : int -> int -> string -> string -> office

(* what a key or the mouse asks of the program around: nothing, to save
 * the file, to quit *)
type request = Continue | Save | Quit

(* a key (a byte, as the console gives it: the arrows 128 to 131), and
 * what it asks *)
val key : office -> int -> request

(* the mouse: where it is, its buttons (1 left, 2 middle, 4 right); and
 * what it asks of the program around (the File menu's) *)
val mouse : office -> int -> int -> int -> request

(* the page as shapes: the ground (white), each object's group (its
 * frame, its content), the status line's, the menus' bar and the open
 * menu *)
val view : office -> TinyLibPlayground.shape list

(* the page as its file's text; and the program around saying it wrote it *)
val text : office -> string
val saved : office -> unit
val say : office -> string -> unit

(* What tiny-troff (TinyTroff.ml) reads of a page, to print it as text
 * or HTML: its objects, from its file's text (a page of that width and
 * height, for a Markdown file's one box); a text box's characters and
 * their styles (a byte each: bold 1, italic 2, underlined 4, large 8);
 * a sheet's cells (each its name and what was typed), each cell's
 * value, a cell's name (its column and row, from 0); a drawing's shapes
 * (each its kind, box, arrow or text, its numbers, its label) *)
type obj = { kind : string; x : int; y : int; w : int; h : int; data : string }
val parse : int -> int -> string -> obj list
val decode : string -> string * string
type value = Num of int | Str of string | Err of string
val cells : string -> (string * string) list
val values : string -> string -> value
val name : int -> int -> string
val figures : string -> (string * int list * string) list
