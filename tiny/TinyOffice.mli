(* tiny-office: a page of objects, each a kind of document in a box,
 * in one program (docs/plans/done/plan_tiny_office.md).
 *
 * It is the compound document of the Xerox Star and of Smalltalk, cut
 * down:
 *
 *     the shell          the page: selecting, moving, resizing, a new
 *         |              box, deleting, undo, the file
 *     a part             what one kind of object needs: how it is
 *         |              drawn, how it is edited (here: text, sheet,
 *         |              drawing)
 *     its data           a string, whatever the kind
 *
 * {b Every object's data is text}. Undo goes back to earlier pages,
 * which are kept in a list: an edit makes a new page and leaves the old
 * one unchanged.
 *
 * {b The file of a document is in mini-troff's format}
 * (plan_typesetting.md): Markdown lines, plus \name[options]{text} for
 * what Markdown lacks. The pages come one after the other, separated by
 * a line \newpage (as in LaTeX). Each object is a \box[x y w h]{...}
 * around its content:
 * - a text box holds Markdown: **bold**, *italic*, a line starting with
 *   "# " for large, \u{} for underlined, \large{} for large inside a
 *   line;
 * - a sheet is a table: the columns' letters, then what was typed, one
 *   row per line;
 * - a drawing or a paint is a fence (```drawing, ```paint) around its
 *   lines.
 * So a document can be read, or written, in emacs, and a Markdown file
 * opens as a single text box. While a text box is being edited, its
 * data is not Markdown but its text with a mark wherever the style
 * changes, as in "a \{b}bold\{} word"; Markdown is used only in the
 * file.
 *
 * {b A text box is edited as it is shown} (WYSIWYG, as in the Alto's
 * Bravo, then MacWrite and Word). Its text is filled to the box's
 * width, a word that does not fit going to the next line, and each
 * character is drawn in its style with the kernel's fonts: bold, large
 * (16x32), and italic, which slants any of them. A line is as tall as
 * its largest character. A click places the cursor and a drag selects.
 * The Format menu (or C-b, Tab, C-u, C-l) sets or removes a style, on
 * the selection or on what is typed next. Edit has Cut, Copy and Paste
 * (C-w, C-y). The box grows to show all of its text. The author wanted
 * a word processor here, not a box edited as troff source with its
 * marks visible.
 *
 * {b A sheet's data has one line per cell}: the cell's name and what was
 * typed in it, as in "a1 Rent", "b1 500", "b3 =b1+b2". What is typed is
 * a number, a formula after an = (with + - * /, parentheses, cells, and
 * sum(b1:b2)), or a text (how values are computed is in twist:, below).
 * Numbers are integers only, as in tiny-ml. A sheet is edited like any
 * spreadsheet: choose a cell (by a click or the arrows), and what you
 * type replaces what was there; it shows in the status line, as in a
 * formula bar. Enter stores it and moves down. Enter on a cell brings
 * back what is in it.
 *
 * {b A drawing's data has one line per shape}, at its place in the box:
 * "box 20 20 80 30 cpu", "arrow 100 35 180 90", "text 30 150 a note"
 * (the idea comes from pic). An arrow goes across, then up or down,
 * like a connector in a block diagram: the only shapes we can draw are
 * rectangles and words, and a slanted line would need a new kind. The
 * left button drags out a box or an arrow, or places a text; the Draw
 * menu, or Tab, changes the tool. What is typed becomes the label of
 * the last shape.
 *
 * {b The menus} are TinyLibGUI's pull-down menus across the top, as in
 * every office program since the Lisa and the Macintosh:
 * - File (Save, Quit);
 * - Edit (Undo, Cut, Copy, Paste, Delete box);
 * - Insert (Text, Sheet, Drawing, Paint);
 * - the menu of the box being edited (Format for a text, Sheet for a
 *   sheet, Draw for a drawing, Paint for a paint);
 * - Page, last (Next, Previous, New page, Delete page). One page is
 *   shown at a time, and the status line says which.
 * Each item shows its key.
 *
 * {b A paint's data has one line per row of pixels}, one letter per
 * pixel giving its colour: ". white, k black, r red..." (see
 * TinyLibPlayground's pixel_letters). A pixel is 4x4 on the page. The
 * left button paints a line between the places where the mouse was
 * seen, thin or thick (3 pixels). The Paint menu, or a digit, chooses
 * the colour. A row is a single word in the kernel's fat pixels, so a
 * stroke redraws only its rows, not the whole picture.
 *
 * {b A chart draws a sheet's cells as bars}. Its data is one line, such
 * as "bars budget b1:b3 a1:a3": the sheet's name, the cells holding the
 * values, and the cells holding the labels. A sheet gets a name when it
 * is made (sheet1, sheet2...), shown on its tab and in its \box line.
 * With a cell chosen, the Sheet menu can rename the sheet (its charts
 * are renamed too), or make a chart of the cell's column: its numbers
 * are the values and the column to its left gives the labels.
 *
 * The mouse and the keys:
 *
 *     left button          a click in a text box edits it; in a sheet
 *                          it chooses a cell; elsewhere it ends the
 *                          editing and remembers the place; on the
 *                          menus it opens them
 *     the selected box     dragging its tab (which shows its kind)
 *                          moves it; the square at its corner resizes it
 *     right button, held   the box under it moves with the mouse; from
 *                          its bottom right corner, the box is resized
 *     C-o, C-x t, d, p     a new text box, sheet, drawing, paint,
 *                          where the last click was
 *     in a text            characters are typed; Backspace, C-d delete;
 *                          the arrows, C-a, C-e move; C-g unselects
 *     in a sheet           a character starts a new entry for the cell;
 *                          Enter or an arrow stores it; C-g forgets it
 *     in a drawing         Tab changes the tool; the left button draws;
 *                          a character goes to the last label; C-g
 *                          stops editing
 *     Backspace, Delete    remove the selected box
 *     C-_ (C-/)            undo: the page as it was before the last change
 *     C-x ], C-x [         the next page, the one before (Emacs's)
 *     C-x C-s, C-x C-c     save, quit (while editing too)
 *
 * {b Only what changed is drawn.} [view] gives the page as
 * TinyLibPlayground shapes: the ground, a group for each object, and
 * one for the status line. On tiny-kernel the office runs under
 * TinyLibGUI's run_canvas (user/office.ml is a few lines), which
 * compares each group with the one it drew before and draws only what
 * changed. This matters because tiny-kernel takes some 13,000
 * instructions to draw a character: redrawing the whole page at each
 * key would take seconds on tiny-machine.
 *
 * twin:
 * Its full-size counterpart in m-ix is mini-office (apps/office/, about
 * 5,200 lines): a document of parts (text, sheet, picture, drawing,
 * chart), each a record of functions.
 *
 * mini-office is the author's playground's apps/office/TinyOffice.ml,
 * brought to ix under that name. There, a part is a record of functions
 * (Component); a file is a marshalled value after a header line
 * (Saved); shapes use floats and can move, scale and rotate; letters
 * are Hershey's strokes; a text is a piece table (lib_gui's Text_edit);
 * the menus are Gui's, in immediate mode; and a PDF is written from the
 * view. What differs here:
 * - an object's kind is a word and its data a string, and the code
 *   matches on the kind where mini-office calls a part's functions;
 * - the file is text in mini-troff's format, so emacs and troff can
 *   read it without any of the office's code;
 * - coordinates are integers in pixels, with the kernel's single font
 *   and its styles;
 * - run_canvas draws the page only where it changed;
 * - PDF is left to tiny-troff.
 *
 * dropped:
 * For now, the office has none of these:
 * - charts other than bars (pies, lines);
 * - moving a drawing's shapes once they are drawn;
 * - floating point in a sheet, functions other than sum, and formulas
 *   that follow a cell when it moves;
 * - a fill in a paint, and more than ten colours;
 * - other fonts and sizes (there is one 8x16 font, with its bold,
 *   italic and large), and coloured text;
 * - centred or justified paragraphs, and text that flows from one box
 *   to the next or onto the next page;
 * - undo of the typing inside a box (undo takes the document back to
 *   before the box was edited).
 *
 * twist:
 * A sheet's values are computed again at each view: each cell once,
 * after the cells it needs. mini-office's Sheet instead builds a
 * dependency graph and recalculates only what a change reaches. With
 * no graph there is nothing to invalidate. A cell that is still being
 * computed when it is needed counts as #CYCLE, which is what a cell
 * that depends on itself shows. And a chart, which reads the sheet's
 * values at each view, follows its sheet with no code of its own.
 *
 * archi:
 * The shell is this file. The parts are the modules of TinyOffice/,
 * one per kind: Text, Sheet, Drawing, Paint and Chart. Each reads its
 * data, handles its keys and makes its view. They are built on Model,
 * which holds the page's objects, what is being edited, and the
 * office's record. File reads and writes the file.
 *
 * context:
 * This file makes no system calls: the program around it reads the
 * keys and the mouse, draws, and writes the file.
 *
 * exercises:
 * - a save that is a tiny-vcs commit: the document is Markdown's lines,
 *   so tiny-vcs's diff of two saves reads well.
 *)

(* [create width height file text] makes the office on a page of that
 * size in pixels. [file] is the document's name and [text] the file's
 * contents ("" for a new document). The name is an Fpath.t so that the
 * two arguments cannot be swapped by mistake. *)
val create : int -> int -> Fpath.t -> string -> Model.office

(* what a key or the mouse asks of the program around *)
type request = Continue | Save | Quit

val key : Model.office -> TinyLibPlayground.key -> request

(* [mouse o x y buttons] handles the mouse (buttons: 1 left, 2 middle,
 * 4 right). Only the File menu asks something of the program around. *)
val mouse : Model.office -> int -> int -> int -> request

(* The page as shapes: the white ground, a group for each object (its
 * frame and its content), the status line, the menu bar and the open
 * menu. *)
val view : Model.office -> TinyLibPlayground.shape list

(* [text] is the page as the text of its file. The program around calls
 * [saved] once it has written that text, and [say] to show a message in
 * the status line. *)
val text : Model.office -> string
val saved : Model.office -> unit
val say : Model.office -> string -> unit

(* [main caps argv] is the program, run as office file. It shows the
 * document in the window and saves it when asked. It prints the usage
 * when argv does not name a file. *)
val main :
  < Cap.open_in; Cap.open_out; Cap.stderr; Cap.clock; Cap.keyboard; .. > ->
  string array -> Exit.t
