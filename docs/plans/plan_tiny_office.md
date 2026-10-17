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
4. **Paint**: a box of pixels, drawn on with the mouse (paint.c's idea,
   in a part).
5. **The chart**: bars from a sheet's range, redrawn when its cells
   change.
6. **Publishing**: each part's `html` as it comes is fine too; this
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
