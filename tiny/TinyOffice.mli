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
 *         |              drawn, how it is edited (here: text)
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
 * The mouse and the keys:
 *
 *     left button          a click in a text box edits it; elsewhere,
 *                          the editing ends, and the place is kept
 *     right button, held   the box under it moves with the mouse; from
 *                          its bottom right corner, the box is resized
 *     C-o                  a new text box, where the last click was
 *     Backspace, Delete    the selected box removed
 *     C-_ (C-/)            undo: the page as it was before the last change
 *     C-x C-s, C-x C-c     save, quit (while editing too)
 *
 * {b Only what changed is drawn.} [view] is the page as shapes
 * (TinyLibDraw's): the ground, a group for each object, one for the
 * status line. TinyLibGUI's run_canvas, which runs the office on
 * tiny-kernel (TinyKernel/user/office.ml, a few lines), compares each
 * group with the one it drew before and draws what changed: tiny-kernel
 * draws a character in some 13,000 instructions, and a page redrawn at
 * each key would be seconds of tiny-machine.
 *
 * As TinyEditorScreen, this file uses no system calls: OCaml compiles
 * it for the tests (tests/TinyOffice_test.sh), tiny-ml for tiny-kernel.
 *
 * What is left out, for now: the other parts (the sheet, the drawing,
 * paint, the chart: steps 2 to 5 of the plan), publishing (step 6),
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

(* the mouse: where it is, its buttons (1 left, 2 middle, 4 right) *)
val mouse : office -> int -> int -> int -> unit

(* the page as shapes: the ground (white), each object's group (its
 * frame, its content: bold is words twice, a pixel apart), the status
 * line's *)
val view : office -> TinyLibDraw.shape list

(* the page as its file's text; and the program around saying it wrote it *)
val text : office -> string
val saved : office -> unit
val say : office -> string -> unit
