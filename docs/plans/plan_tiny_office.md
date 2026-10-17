# Plan: tiny-office, a spreadsheet, a word processor, a drawing, paint and charts in about 900 lines

The author (2026-10-16): "later on an app like a spreadsheet and word
document; ideally we could do a tiny-office but it seems difficult";
then, offered a spreadsheet alone: "any chance we can get a more
complete tiny-office? Find a way to get a spreadsheet, word, paint,
diagram, etc with very few LOC?"; then "let's commit the plan"; then "yes but a big issue is what do you
do with the produced document?" (section 4), and "yes add it to the
plan and commit".

m-ix has mini-office (`apps/office/`, about 5,200 lines): a document of
parts (text, sheet, picture, drawing, chart), each "a record of
functions" (Office.ml's header), on lib_gui and the playground. t-ix
has none. This plan is how to get its idea, every kind of document in
one program, in about a sixth of the lines. The sizes below are
guesses.

## 1. The idea: one program, one document, small parts

It is the compound document of the Xerox Star, Smalltalk and OpenDoc,
which mini-office has too, cut to the bone:

- **A document is a page of objects**, each a kind, a box on the page,
  and its data.
- **One shell does what all applications share**: selecting, moving
  and resizing an object, the keys and the mouse, opening and saving,
  undo, M-x.
- **A part is only what its kind needs**: a record of four functions,
  `draw` (the data in its box, as TinyLibDraw's messages), `key` and
  `click` (the data changed), and `html` (the data published:
  section 4).

```
    the shell          page, selection, move, resize, files, undo, M-x
        |
    a part = { draw; key; click; html }, on data that is a string
        |
    text     sheet     drawing     paint     chart (a sheet's cells)
        |
    TinyLibDraw (tiny-kernel's /draw), TinyEditorScreen (editing text)
```

## 2. Every part's data is text

This is what keeps it small:

| Part | Its data | Lines |
|---|---|---:|
| Text (word) | the text, with a few marks (`*bold*`, `# heading`), filled to the box's width: troff's idea | ~100 |
| Sheet | cells as lines: `a1 = 3`, `b1 = a1*2 + sum(a1:a3)`; a formula's parser, the cells recomputed in the order they need | ~200 |
| Drawing (diagram) | shapes as lines: `box 10 10 80 40 "cpu"`, `arrow 90 30 150 30`: pic's idea; made and moved with the mouse | ~120 |
| Paint | pixels as rows of letters, one a colour of the palette | ~60 |
| Chart | a range of a sheet's cells, drawn as bars | ~40 |
| The shell | the page, the selection, moving and resizing, files, undo, M-x | ~250 |
| Publishing | each part's `html`, and the page around them (section 4) | ~100 |

What text gives for nothing, or nearly:

- **Saving and opening**: a file is the objects one after the other,
  each a line (its kind and its box) and its text.
- **Undo**: an edit makes a new document instead of changing the old
  one, so undo takes the previous one off a list: about 10 lines.
- **Editing text**: a text part is edited by TinyEditorScreen in its
  box, with Emacs's keys, M-x and macros.
- **Mending by hand**: any part, and the whole file, can be opened in
  emacs. That helps to debug and to teach: what a drawing is, is
  readable.
- **Parts that share**: a chart names a sheet's cells; a drawing's box
  holds text.

## 3. The steps

Each leaves something usable on tiny-kernel, in a window of
tiny-windows like emacs, and a screen session in `make check`:

0. **put, and files kept across a stop** (section 4), before the
   office is used for real. **Done (2026-10-17)**: `put file [name]`
   (TinyKernel/user/put.c) sends a line `put name size` and the
   bytes to port 70; the peer (TinyMachinePeer) gives them to the host,
   which writes them into tiny-machine's `-net` directory, or the web
   page's localStorage, and answers ok or why not. `get ''` (Gopher's
   empty line, its menu) lists what was put, so a new boot brings it
   all back: ``for(f in `{get ''}) get $f > $f``. `make check` puts two
   files, reads them on the host, and gets them back on a second boot.
   Not run: the web page's side (its test needs Python's websockets).
1. **The shell and the text part**: a page with text boxes, typed
   into, moved, saved, opened again; undo. **Done (2026-10-17)**:
   `tiny/TinyOffice.ml` (the page, the shell, the text part; about 235
   lines of code) and `TinyKernel/user/office.ml` (tiny-kernel's
   `office file`, 15 lines: the page given to TinyLibGUI's
   run_canvas). Found on the way:
   - A text box is edited by TinyEditorScreen, which got Emacs's
     auto-fill-mode (`auto_fill`): a line written wider than its box
     scrolled sideways, and showed one piece of the paragraph.
   - Only what changed is drawn: each shape of the view (the ground, a
     box, the status line) compared with the one drawn before, a leaf
     (a rectangle, words) with the one at its place; what changed
     erased, then drawn in the page's order with what was under it. A
     rectangle drawn again is drawn only where it was erased: the
     page's background meets everything, and drawn whole it wiped the
     boxes.
   - The author: "why so much code in user/emacs.ml ? and
     user/office.ml? I thought those files were supposed to be very
     small, just some little glue to the main TinyXxx file"; then "why
     another TinyLibXxx ? can't we use TinyLibDraw.ml and
     TinyLibGUI.ml?"; "let's do it". The two programs had the same
     window size (an ENQ), file, loop, raw console and drawing, each
     its own: now TinyLibGUI's run_canvas (a program that draws its
     whole window, below the widgets), its read_file and write_file;
     the shapes are TinyLibPlayground's, as mini-office stands on the
     playground's in m-ix (they were moved to TinyLibDraw for a day; the
     author: "not a huge fan of moving the shape to LibDraw as it
     creates a mismatch with where it is in m-ix"; the tests that run
     on tiny-cpu, with no kernel, link the host's stand-in for its
     calls, TinyKernel/host/TinyCalls.ml, instead);
     TinyEditorScreen gives its screen as shapes (shapes), used by
     emacs and by the office's text boxes. emacs.ml went from 89 lines
     of code to 18, office.ml from about 100 to 15; TinyLibGUI gained
     about 120. Measured with tiny-prof, eight keys typed one at a time
     in emacs: 13.5 million instructions in /examples/wc.c (13.4
     before), 9.6 in a file without colours (7.9 before): the words of
     a line compared from both ends (a mode line's column, one or two
     characters), a line's shape kept by the editor and not looked into
     again, a rectangle erased once, what an erasing uncovers drawn
     only in its columns.
   - tiny-ml has no modules: the editor's functions are given names of
     their own (editor_key...), the office having a key, a view, a
     create; a field shared by two records (x) is annotated; the
     editor's record of 20 fields is made in two steps (11 registers).
   - The tests' tiny-cpu link put 640 KB of the runtime's memory
     between code that calls across it (a call reaches 128 KB): the
     memory is a file of its own now, linked last
     (tests/TinyOffice_test.sh).
   - tiny-windows' mouse box keeps only the last state: a drag is seen
     as its steps, and a press and a move read at once are one press.
   - Tests: tests/TinyOffice_test.sh (a page worked at, by OCaml and by
     tiny-ml on tiny-cpu); make check's officekeys.events (a page typed,
     saved, C-x C-c, cat) and office.events (two boxes in a window, one
     moved, one being edited: the screen).
2. **The sheet**: a grid in a box, a cell typed at the last line as in
   emacs's prompt, formulas, recomputation. **Done (2026-10-17)**, while
   the author was away ("go forward on the office plan; I'll check
   when I'm back"): about 150 lines of code in TinyOffice.ml. C-x t
   makes a sheet; its data a line a cell, "b3 =b1+b2"; a formula is
   read and computed at once by recursive descent (+ - * /,
   parentheses, cells, sum(a1:b3)), each cell once a view, those it
   needs first, a cell being computed counting as #CYCLE; errors in
   the cell (#SYNTAX, #REF, #TEXT, #DIV0, #CYCLE). Edited as a
   spreadsheet: a click or the arrows choose a cell, typing replaces
   it, shown in the status line as a formula bar, Enter puts it and
   goes down, Enter on a cell brings back what is in it, C-g forgets
   it. Integers only: tiny-ml has no floating point on tiny-machine.
   The office's editing is now a variant (nothing, a text box's
   editor, a sheet's cell). Tests: TinyOffice_test.sh's sheet scenes;
   make check's officesheet.events (a budget in a window, its shares)
   and officekeys.events (a sheet saved in the page, cat).
3. **The drawing**: boxes, ovals, lines, arrows and labels, made by
   dragging. **Done (2026-10-17)**, also while the author was away:
   about 100 lines of code. C-x d makes a drawing; its data a line a
   shape, at its place in the box ("box 20 20 80 30 cpu", "arrow 100
   35 180 90", "text 30 150 a note"). The left button drags a box or an
   arrow, or places a text, kept in the box; Tab changes the tool;
   what is typed is the last shape's label, Backspace shortens it and
   removes a shape whose label is empty. Not done: ovals and slanted
   lines (the playground's shapes are rectangles and words; an arrow
   goes across then up or down, a block diagram's connector, its head
   rectangles narrowing to its end), moving a shape once drawn. Tests:
   TinyOffice_test.sh's drawing scenes; make check's officedraw.events
   (a diagram of three boxes and two arrows, in a window).
   - **Pull-down menus, and the mouse for moving (2026-10-17).** The
     author: "it's currently hard to use; I think we should use menus
     (and TinyLibGUI) to make things less keyboard oriented", "also I
     was not able to resize or move boxes", "pull down menu is one of
     the classic UI for office like programs, so let's follow that",
     "we can add new widgets to TinyLibGUI". TinyLibGUI has pull-down
     menus now (about 60 lines of code): a bar of titles, each a menu
     of items and their messages, its state below the model as the
     widgets' mouse is; a press on a title and a let go on an item chooses it,
     and so does a click on the title then one on the item. The office
     has File (Save, Quit), Edit (Undo, Delete box), Insert (Text,
     Sheet, Drawing), and Draw (the tools) while a drawing is edited;
     each item shows its key. The selected box has a tab above it (its
     kind), which the left button drags to move it, and a square at its
     corner, to resize it; the right button still does both.
   - Why the boxes did not move: the right button reached the office
     (the screen's mouse and tiny-windows' send it as 4), but a box
     moved only on a motion seen with the button held. The mouse is a
     place, not its history, and the office, redrawing the whole screen
     after the press, may next see the button up, far away: no move.
     The let go now counts where it is, for a box moved or resized and
     for a drawing's stroke. The menus are the same: a press on a title
     and a let go on an item, with nothing seen between, is a choice.
   - run_canvas's mouse may end the program now (File's Quit): its
     moved gives an option, as typed does. emacs's binary grew by 10
     KB, TinyLibGUI being linked whole.
   - Tests: TinyOffice_test.sh's menus scene (a menu opened, an item
     clicked, an item reached by a drag, by a press and a let go
     alone, the Draw menu, a click outside, Save) and moves scene (the
     tab and the corner, a press and a let go alone); the old scenes'
     points 30 pixels lower, under the bar. make check's
     officesheet.events makes its sheet from the Insert menu.
   - **Styles, a selection, WYSIWYG (2026-10-17).** The author: "how do
     add bold or italic in this tiny-word ? or text with different
     size? pretty fundamental for a tiny-office no?", then "let's do the
     menu, the selection, and wysiwyg; pretty important for a
     tiny-office", and "you can then remove the autofill feature".
     - The kernel draws styled text: a new message, 't', a text with a
       style (bold 1, italic 2, underlined 4, large 8). Its fonts are
       made from the machine's 8 by 16 when first asked for: italic,
       its rows slanted 3 pixels (cells 11 wide, so a slant stays in
       its cell), large, each pixel 2 by 2, bold, each stroke a pixel
       wider but for a gap of one pixel, and those together.
       TinyLibDraw's d_styled sends it,
       tiny-windows forwards it (its rectangle twice as large).
     - A word's style is in its colour's high bits (TinyLibPlayground's
       bold, italic, underlined, large: 256 to 2048), so the shape type
       is the same as m-ix's. run_canvas redraws a styled word whole
       where it changed or was uncovered (its characters are not 8
       pixels wide, and a slant goes over the next).
     - The office's text boxes are no longer TinyEditorScreen's: about
       150 lines of their own. The data is the text with a mark where
       the style changes, "a \{b}bold\{} word" (b, i, u, l; \{}
       plain), readable in emacs. Being edited it is two strings, the
       characters and a style byte each; laid out in the box's width at
       each view (a word that does not fit to the next line, a line as
       tall as its largest character); a click puts the cursor, a drag
       selects (pale blue under the words); the Format menu (Bold,
       Italic, Underline, Large, Plain; C-b, Tab, C-u, C-l) sets or
       takes off a style of the selection, or of what is typed next;
       Edit has Cut, Copy, Paste (C-w, C-y). The box grows to show its
       text. The office no longer links TinyEditorScreen, whose
       auto-fill, added for the office, is gone.
     - Tests: TinyOffice_test.sh's first scene types a large title and
       bold words; a styles scene (four styles typed, a drag selecting,
       Format's Italic, cut and pasted, the file's marks).
       office.events's screen shows a large title, bold, italic, bold
       italic and underlined words; officekeys.events cats a page with
       its marks.
     - **www has them too (2026-10-17).** The author: "Should we modify
       www to also display web pages using large font, bold, italic,
       underline, etc. ?", then "let's do both steps". TinyBrowser draws
       <em> and <i> in italic (red before), <u> and <ins> underlined,
       bold and headings in bold, and <h1> and <h2> large: a large
       heading's words are laid out at half the width, and each of its
       lines is two of the page's (its top half, then its bottom half,
       a run's pic -2), so the page stays rows of 16 pixels, each drawn
       on its own through the strip image. Bold drawn twice, a pixel
       apart, made an m a block (TinyBrowser's comment had said so, and
       the office's screens had no m in bold): the kernel's bold is now
       a font of its own, each stroke a pixel wider but for a gap of
       one pixel. Tests: TinyBrowser_test.sh's lines (a large heading
       has an empty line under it, its bottom half), its tiny-cpu run
       with heap halves of 352 KB (360 left too little stack, the
       browser's code a little larger); make check's seven www screens
       looked at before recording (the History heading large, the
       references' italic, the infobox's bold).
4. **Paint**: a box of pixels, drawn on with the mouse (paint.c's idea,
   in a part). **Done (2026-10-17)**, the author: "let's move on to step
   4, paint". About 65 lines of code in TinyOffice.ml. C-x p, or
   Insert's Paint, makes a paint; its data a line a row of pixels, a
   letter a pixel (. white, k black, r red, g green, b blue, y yellow,
   o orange, p purple, n brown, a grey), a row ending at its last
   colour that is not white. A pixel is 4 by 4 on the page. The left
   button paints a line between the places the mouse was seen at (the
   mouse is a place: a fast stroke is seen at a few points), thin or
   thick (3 pixels); the Paint menu (ten colours, the brushes, Clear),
   or a digit, a colour; a stroke is one undo.
   - Drawn fast: a row is one word, its letters, in a style of the
     playground's, fat_pixels; the playground makes the letters the
     palette's bytes when it draws the row, and the kernel's 't'
     message has a style 16, a byte a square of 4 by 4, a run of one
     colour filled at once. So a picture is one leaf a row, a stroke
     draws again the rows it went through, and the view does no work
     a pixel (it did at first: the session lost its events).
   - Tests: TinyOffice_test.sh's paint scene (a line, a thick stroke
     seen at its two ends only, the Paint menu, Clear, undo, the
     file); make check's officepaint.events (a house, its roof, a
     door, a thick sun, the ground, in a window; tiny-prof: some 34
     million instructions of the office for the session). tetris's
     screen recorded again: its pieces fall by the clock, and the
     playground's code is a little larger.
   - **The file, in mini-troff's format (2026-10-17).** The author,
     on a tiny-troff: "could we do a tiny-troff that actually reuse the
     same format than tiny-office?", "so we could either edit the
     document in wysywyg way with the office program, or in textual
     form with TinyScreenEditor, and use the tiny-troff to generate the
     html (or pdf)", then "maybe let's try to make the document format
     closer to what we used for mini-troff markdown/latex mix", and "I
     like it. Let's do it". A page's file is now plan_typesetting.md's
     format: each object a `\box[x y w h]{` line, its content, a line
     `}`; a text's Markdown (`**bold**`, `*italic*`, `# ` a large line,
     `\u{}`, `\large{}`, `\` before a character read otherwise); a
     sheet a Markdown table, its header the columns' letters; a drawing
     or a paint a fence of its lines. The kind is in the content, no
     count of bytes: emacs can edit a page, and a Markdown file with
     no `\box` opens as one text box. About 100 lines of code (the
     Markdown's inlines both ways, the table both ways), in place of
     the 15 of the old format. Tests: TinyOffice_test.sh's files in
     the new format, a page of the four kinds read and written again
     the same, a Markdown file opened; officekeys.events's `cat`.
     Next: tiny-troff, the page to text and HTML (step 6's publishing).
5. **The chart**: bars from a sheet's range, redrawn when its cells
   change. **Done (2026-10-17)**, the author: "let's commit and move
   forward", then, of how a chart names its sheet, named sheets. About
   90 lines of code in TinyOffice.ml.
   - A sheet has a name, sheet1, sheet2... when made, written after its
     box's numbers (`\box[10 40 282 114 budget]{`) and on its tab. The
     Sheet menu, a cell chosen, names it (typed in the status line;
     its charts renamed with it), or makes a chart of the cell's
     column: its cells from the first number to the last, the column
     at its left their labels, beside the sheet (under it, the page too
     narrow).
   - A chart's data is a line, `bars budget b1:b3 a1:a3`, in a fence
     ```chart. Its bars are the sheet's values at each view (a bar a
     value, as tall as its share of the largest, its value above, its
     label under), so it follows the sheet. One function,
     chart_bars, gives the bars to the office and to tiny-troff (text:
     a line of #s a bar; HTML: SVG).
   - Tests: TinyOffice_test.sh's chart scene (a sheet named from the
     menu, a chart of a column, a value changed and the chart with it,
     the file); TinyTroff_test.sh's charts (and one of a sheet that is
     not there); make check's officesheet.events makes a chart of its
     budget (Rent, Food, Total), its screen looked at, and
     officekeys.events's sheet has its name in the file.
6. **Publishing**: **tiny-troff done (2026-10-17)**, the author: "yes
   commit, then let's do tiny-troff". `tiny/TinyTroff.ml` (about 185
   lines of code) prints a page, or a Markdown file, as text (each
   line filled, a large line underlined by =, a sheet's values in
   columns, a drawing in characters, + - | a box, > < v ^ an arrow's
   head, a paint's letters) or as HTML (each part at its place: <p>,
   <h1>, <b> <i> <u>; a sheet a <table> of its values; a drawing and a
   paint SVG). It reads the page with TinyOffice's functions
   (TinyOffice.mli's last part), the format written once. tiny-kernel's
   `troff [-h] file` (user/troff.ml, a few lines), and
   /examples/report.ixd to try it: `troff -h /examples/report.ixd >
   r.html; put r.html` publishes a page.
   - troff links the office (its reading of a page) and what the office
     is on: 200 KB, since tiny-ml drops what a program does not call
     (b572b25e, the other session's, while troff was being written;
     before it, troff was over the 384 KB an ML program of tiny-kernel's
     has, and the office itself at 377 KB). If the office outgrows it:
     mlsys.c could put the value stack and the heap after the program
     (tiny-cpu's linker would define a label end), tried and set aside.
   - Tests: tests/TinyTroff_test.sh (a page of the four kinds as text
     and HTML, a Markdown file as text; OCaml, and tiny-ml on
     tiny-cpu); make check's troff of /examples/report.ixd, as text and
     the size of its web page. paint's, tetris's, windows's and
     nested's screens recorded again (paint's ball and tetris's pieces
     where the clock has them, the boot image larger; ls with troff).
   - **PDF (2026-10-17)**, the author: "ok let's try the PDF output;
     hopefully it does not need too many lines". About 110 lines of
     TinyTroff.ml: one page the size of the parts, a pixel a point, the
     text in Courier (a font every reader has, nothing carried; at
     13.33 points 8 a character, the office's 8 by 16; Courier-Bold,
     -Oblique, -BoldOblique for the styles, twice the size for large),
     laid out by the office's own lay_out (now in TinyOffice.mli); a
     sheet's values in a grid, a drawing's lines and arrowheads, a
     paint's and a chart's rectangles; not compressed. `troff -p` on
     tiny-kernel, and `tiny-troff [-h | -p] file` on the host
     (TinyTroffCommand.ml: the author, "why can't we tiny-office on the
     host? (and same for tiny-troff)"). Checked: TinyTroff_test.sh
     prints the PDF (the same bytes from tiny-cpu), Ghostscript renders
     it without a complaint and pdftotext reads its text; make check's
     troff -p of /examples/report.ixd, the same 2,431 bytes as the
     host's.
   - **On the host (2026-10-17).** The author: "tiny-office should not
     talk directly to the kernel; it should use intermediate library
     abstraction that then could also work on the host no?", and "maybe
     we can put this in a sdl/ directory that we usually skip already I
     think as part of make loc". It did: TinyOffice.ml makes no call,
     TinyLibGUI, the playground and TinyLibDraw make theirs through
     TinyCalls, which was the kernel's (calls.ml) or the tests' stub.
     TinyCalls is now a virtual library of dune's
     (TinyKernel/host/TinyCalls.mli), with two implementations: the
     stub (TinyKernel/host/stub/, the tests', the default) and a
     window's (tiny/sdl/TinyCalls.ml): the drawing messages done by
     tiny-kernel's own TinyKernelGraphics.ml in TinyMemory's screen,
     shown by TinyMachineSDL (now a library, with the key's bytes that
     were tiny-machine-window's), the mouse the box of descriptor 4,
     the keys descriptor 0, an ENQ answered with the window's size, the
     host's files and clock. The few lines of each program
     (TinyKernel/user/office.ml, emacs.ml, calc.ml, tetris.ml) are
     compiled by OCaml there as they are (an `open TinyCalls`, which
     tiny-ml leaves): tiny-office, tiny-emacs, tiny-calc, tiny-tetris.
     tiny/sdl/ is not counted by make loc (a program's host).
     TINY_SCREEN=file writes the screen when the program ends: the four
     looked at under SDL_VIDEODRIVER=dummy (the office on
     /examples/report.ixd, emacs on wc.c in colours, the calculator,
     tetris's first piece falling).
   - The step as planned: each part's `html` as it comes is fine too; this
   step is the page around them, and a session that publishes a
   document and reads it with www.

Tests: each part's functions on the host, as TinyEditorScreen's are
(its data in, its messages or its new data out), by OCaml and by
tiny-ml on tiny-cpu; the program as a whole by recorded sessions.

## 4. What becomes of a document

The author: "a big issue is what do you do with the produced
document?" A document that dies with the machine, in a format no one
else reads, is a toy. What tiny-kernel had (2026-10-16):

- **Nothing survives a stop**: its files are in its memory. (`-d disk`
  of tiny-machine is for an older kernel, TinyKernel/steps/t6.)
- **A way out, the network**: httpd serves the files to a browser;
  with `tiny-machine -net-forward 8080:80`, Firefox on the host opens
  `http://localhost:8080/name`, and can save it.

**Publish it as a web page.** Each part's fourth function, `html`,
writes its data in formats that everything reads:

| Part | Published as | Read by |
|---|---|---|
| Text | HTML: `<h1>`, `<p>`, `<b>` | every browser, tiny-kernel's www |
| Sheet | an HTML `<table>` of its values; and CSV | browsers; CSV by Excel, LibreOffice, and tiny-kernel's grep, sort, wc |
| Drawing | SVG, in the page | every browser (TinyBrowser hides SVG) |
| Paint | BMP: no compression, about 20 lines to write, shown by every browser | browsers |
| Chart | SVG bars | browsers |

What it gives: read on tiny-kernel with www and on the host in any
browser; printed, and saved as PDF, by the browser, with no PDF code in
t-ix; shared, since it is a page httpd serves, to the host or to
another tiny-machine on the wire. The text file stays the source and
the HTML is the published form, troff's way.

**Keeping files across a stop: put (step 0).** Fetching with Firefox
works but is clumsy. put, get's reverse: a file sent to the host's end
of the wire (TinyMachinePeer), written into its `-net` directory; and
at the boot, the files of that directory brought back (or got by name).
A small piece of tiny-kernel and TinyMachinePeer of its own.

**Not done: other people's documents**, .docx and .xlsx: those formats
are huge. CSV read into a sheet is cheap and is the common case.

## 5. Costs and limits

- **Speed is the main risk.** tiny-machine runs at 8 MHz. A page must
  redraw only what changed: what emacs needed too (5c6ae40e: what was
  measured with tiny-prof, and joins two by two instead of TinyLibStd's
  quadratic String.concat).
- **tiny-ml's limits** shape the code: a record has 11 fields at most,
  a closure cannot take too many values (tiny-machine's 11 registers),
  no Bytes. emacs lives with all three.
- **Left out**: fonts and sizes (one font, 8 by 16), printing of our
  own (the browser prints the published page), reading .docx and
  .xlsx, spelling, more than one page.

## 6. The other way, not taken

Plan 9's: a filter per kind of document (troff, pic, tbl, grap), its
input written in emacs and the result shown in a viewer. About 500
lines, but nothing to drag or to draw with the mouse. The compound
document gives the office people expect, for some 400 lines more, and
its parts' data is that same kind of text.
