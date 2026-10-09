(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: the author's playground's apps/office/TinyOffice.ml (docs/plans/plan_office.md) *)
(* TinyOffice: the office suite as people know it today -- Microsoft
 * 365, Apple's iWork, LibreOffice -- rather than any one program of its
 * history.
 *
 * You start from a choice of what to make: a document, a spreadsheet, a
 * presentation, a picture, a drawing. Each opens in its own editor, and
 * every one of those editors can hold things made by the others: a
 * sheet in a letter, a drawing over a sheet, a picture on a slide. They
 * float where you put them; you drag them, and drag a corner to resize
 * them; in a text, the text runs round them as you do. Click one again
 * and you edit it where it is, the menu bar turning into its editor's
 * while the host's File menu stays -- and Escape brings the host back.
 *
 * **Why a new program, and not the old ones grown.** The Tiny programs
 * before this one are each a period piece, true to the program they
 * are named after, and what they cannot do is what their originals
 * could not do -- which is the point of them, and why this one is
 * separate rather than a change to them:
 *
 * - TinyWord, TinyExcel, TinyPowerPoint, TinyMacPaint and TinyMacDraw
 *   are each one kind of document, and none of them can hold another's
 *   (only TinyPowerPoint holds parts, one per slide, in a fixed place).
 *   There is no suite: five programs that share nothing but code.
 *
 * - TinyOpenDoc (OpenDoc, 1994-97) is a document of parts with no
 *   application at all -- and so no kind of document either: nothing is
 *   "a spreadsheet with a drawing in it". Its parts are laid out *by
 *   position*, a tree of rows and columns: a part cannot float over
 *   another, cannot sit anywhere but in its row, and a text cannot run
 *   round it. Its sizes are negotiated or scaled, but only within the
 *   tree's own slots.
 *
 * - TinyFrameMaker (FrameMaker, around 1986) lays its frames out *by
 *   order*: each tied to a place in one text, set below its line, as
 *   wide as its column. A frame cannot sit beside a paragraph with the
 *   text running round it, cannot be dragged, only anchored; and the
 *   text is the only container -- a sheet cannot hold anything.
 *
 * What TinyOffice has that none of them has, and what a modern suite
 * is made of:
 *
 * - **a start screen**: the kind first, then the editor for it;
 * - **every kind a host**: a document, a sheet, a presentation, a
 *   picture and a drawing can each hold objects of the others (OLE's
 *   shape, 1993: applications that embed each other, rather than
 *   OpenDoc's parts without applications);
 * - **free-floating objects**: placed anywhere on the page, over what is
 *   there, dragged, resized by their corners, brought to the front or
 *   sent to the back -- a part with a size of its own scaled to its
 *   frame (or kept at its natural size), a text box reflowing inside it;
 * - **text that wraps round them**, as Publisher (1991) and Pages
 *   (2005) do: the lines beside an object are shortened to the room it
 *   leaves (appkits/richtext/Page's ~around), live, as it is dragged;
 * - **in-place editing with menu merging**: the object's editor takes
 *   the menu bar, the host keeping only File -- OLE 2's rule;
 * - **objects that move with the text** (Arrange > Move with Text): an
 *   object tied to its paragraph, and still free to be dragged, which
 *   ties it to the paragraph it is dropped beside -- Word's "move
 *   object with text", where TinyFrameMaker's anchors cannot be moved
 *   at all. Its place is found in two layouts, the first without the
 *   tied objects to find their paragraphs' lines;
 * - **each object its own wrapping**, Word's choices (Arrange): the
 *   text on its wider side, on both sides ("Square"), above and below
 *   it only, or not at all, the object in front of the text. Page has
 *   one rule, a line filling every stretch it is left; the rest is the
 *   box each object gives it -- reaching the edge on the side the text
 *   must not go;
 * - **pages**: a document's text runs on from page to page, the pages
 *   one under the other, scrolled with the wheel and the page keys and
 *   following the caret -- one tall layout, the margins between pages
 *   boxes the text goes round like any other;
 * - **headers and footers**, the same on every page, edited in place
 *   by a click in the margin (the body dimmed meanwhile), with *fields*
 *   each page fills in: "page {page} of {pages}" -- Word's fields, their
 *   code shown while being edited and their result otherwise;
 * - **the show** (Slide > Show): the slides one at a time, the whole
 *   screen, drawn by the same code as the page being edited, scaled;
 * - **a chart linked to a sheet** (Insert > Chart, the sheet object
 *   selected, or in a spreadsheet): the chart holds no sheet, only which
 *   sheet it shows, and is made again from that sheet's cells every
 *   time it is drawn -- OLE's *linking*, beside its embedding -- so its
 *   bars follow the numbers as they are typed, in place.
 *
 * What it uses: appkit_embed (Component, the protocol, and its
 * draw_in/input_in scaling), the parts of apps/ (Part_text, Part_sheet,
 * Part_picture, Part_drawing, and Part_chart for the charts) as both
 * the main content of the sheet, picture and drawing documents and the
 * objects floating on any of them, appkits/richtext (Rich, Page and its
 * text round boxes, on one side or both) for the document and the
 * slides, Stroke_text, appkits/document's Undo, and the
 * playground's menus.
 *
 * It saves (File, File_menu, and Open... on the start screen):
 * every kind in one file type, the document's own records with each
 * part replaced by its kind and saved text.
 *
 * What it deliberately does not do: rotation; the presentation's
 * master, its transitions and its builds (TinyPowerPoint has them); a
 * first page without its header, or odd and even pages; a link to a
 * sheet in another file (its link is to an object of the same
 * document); collaboration, and the cloud.
 *
 * Exercises: a {date} field; a header left out of
 * the first page; text wrapped to an object's outline rather than its
 * box ("Tight", a drawing's figures giving the stretches); snapping an
 * object to the others' edges while it is dragged; a chart of a range
 * chosen by dragging over the cells, rather than of columns A and B; a
 * pie chart.
 *)
let app caps = Playground.game Office_view.view (Office_update.update caps) Office_model.initial
let () =
  Cap.main (fun caps ->
      try Playground_platform.run_app caps (Playground_platform.flags caps) (app (caps :> File_menu.caps))
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1)
