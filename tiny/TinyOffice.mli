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
 * {b Every object's data is text.} A text box's is its text, with two
 * marks: a line "# words" is a heading, and *words* are bold. So the
 * file of a page is the objects one after the other, each a line (its
 * kind and its box) and its data; undo is the earlier pages, kept in
 * a list (an edit makes a new page, the old one is not changed); and a
 * page can be read, or mended, in emacs.
 *
 * {b A text box is edited by the screen editor.} A click in it starts
 * TinyEditorScreen on its text, in the box: Emacs's keys, M-x and
 * macros, the text as it is written (the marks shown). A click
 * elsewhere ends the editing, and the box shows the text filled to its
 * width, the headings and the bold drawn. Writing the source and
 * seeing the result is troff's way; here both are in the same box.
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
 * The mouse and the keys:
 *
 *     left button          a click in a text box edits it, in a sheet
 *                          chooses a cell; elsewhere, the editing ends,
 *                          and the place is kept; on the menus, they
 *     the selected box     its tab above it (its kind) moves it; the
 *                          square at its corner resizes it
 *     right button, held   the box under it moves with the mouse; from
 *                          its bottom right corner, the box is resized
 *     C-o, C-x t, C-x d    a new text box, sheet, drawing, where the
 *                          last click was
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
 * As TinyEditorScreen, this file uses no system calls: OCaml compiles
 * it for the tests (tests/TinyOffice_test.sh), tiny-ml for tiny-kernel.
 *
 * What is left out, for now: the other parts (paint, the chart: steps
 * 4 and 5 of the plan), moving a drawing's shapes once drawn, a sheet's floating point, its
 * other functions than sum, and formulas that follow a cell moved, publishing (step 6),
 * fonts and sizes (one font, 8 by 16), several pages, and undo of the
 * typing inside a box (undo takes the page back to before the box was
 * edited).
 *)

type office

(* [create width height file text]: the office on a page of that size
 * in pixels, file the page's name, text the file's text ("" for a new
 * page) *)
val create : int -> int -> string -> string -> office

(* a key (as TinyEditorScreen's: a byte), and what it asks of the
 * program around: nothing, to save the file, to quit *)
val key : office -> int -> TinyEditorScreen.request

(* the mouse: where it is, its buttons (1 left, 2 middle, 4 right); and
 * what it asks of the program around (the File menu's) *)
val mouse : office -> int -> int -> int -> TinyEditorScreen.request

(* the page as shapes: the ground (white), each object's group (its
 * frame, its content: bold is words twice, a pixel apart), the status
 * line's, the menus' bar and the open menu *)
val view : office -> TinyLibPlayground.shape list

(* the page as its file's text; and the program around saying it wrote it *)
val text : office -> string
val saved : office -> unit
val say : office -> string -> unit
