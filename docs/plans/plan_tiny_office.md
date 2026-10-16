# Plan: tiny-office, a spreadsheet, a word processor, a drawing, paint and charts in about 800 lines

The author (2026-10-16): "later on an app like a spreadsheet and word
document; ideally we could do a tiny-office but it seems difficult";
then, offered a spreadsheet alone: "any chance we can get a more
complete tiny-office? Find a way to get a spreadsheet, word, paint,
diagram, etc with very few LOC?"; then "let's commit the plan".

m-ix has mini-office (`apps/office/`, about 5,200 lines): a document of
parts (text, sheet, picture, drawing, chart), each "a record of
functions" (Office.ml's header), on lib_gui and the playground. t-ix
has none. This plan is how to get its idea, every kind of document in
one program, in about a seventh of the lines. The sizes below are
guesses.

## 1. The idea: one program, one document, small parts

It is the compound document of the Xerox Star, Smalltalk and OpenDoc,
which mini-office has too, cut to the bone:

- **A document is a page of objects**, each a kind, a box on the page,
  and its data.
- **One shell does what all applications share**: selecting, moving
  and resizing an object, the keys and the mouse, opening and saving,
  undo, M-x.
- **A part is only what its kind needs**: a record of three functions,
  `draw` (the data in its box, as TinyLibDraw's messages), `key` and
  `click` (the data changed).

```
    the shell          page, selection, move, resize, files, undo, M-x
        |
    a part = { draw; key; click }, on data that is a string
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

1. **The shell and the text part**: a page with text boxes, typed
   into, moved, saved, opened again; undo.
2. **The sheet**: a grid in a box, a cell typed at the last line as in
   emacs's prompt, formulas, recomputation.
3. **The drawing**: boxes, ovals, lines, arrows and labels, made by
   dragging.
4. **Paint**: a box of pixels, drawn on with the mouse (paint.c's idea,
   in a part).
5. **The chart**: bars from a sheet's range, redrawn when its cells
   change.

Tests: each part's functions on the host, as TinyEditorScreen's are
(its data in, its messages or its new data out), by OCaml and by
tiny-ml on tiny-cpu; the program as a whole by recorded sessions.

## 4. Costs and limits

- **Speed is the main risk.** tiny-machine runs at 8 MHz. A page must
  redraw only what changed: what emacs needed too (5c6ae40e: what was
  measured with tiny-prof, and joins two by two instead of TinyLibStd's
  quadratic String.concat).
- **tiny-ml's limits** shape the code: a record has 11 fields at most,
  a closure cannot take too many values (tiny-machine's 11 registers),
  no Bytes. emacs lives with all three.
- **Left out**: fonts and sizes (one font, 8 by 16), printing, real
  formats (.docx, .xlsx), spelling, more than one page.

## 5. The other way, not taken

Plan 9's: a filter per kind of document (troff, pic, tbl, grap), its
input written in emacs and the result shown in a viewer. About 500
lines, but nothing to drag or to draw with the mouse. The compound
document gives the office people expect, for some 300 lines more, and
its parts' data is that same kind of text.
