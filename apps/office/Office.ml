(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyOffice: the office suite as people know it today -- Microsoft
 * 365, Apple's iWork, LibreOffice -- rather than any one program of its
 * history.
 *
 * (Here the program is mini-office, and this file is its last lines:
 * the model, the update and the view given to Playground.game. The
 * text below is the playground's TinyOffice's, whole, with its names;
 * the two pictures that follow are ix's, with ix's names.)
 *
 * The suite, top down. Each line stands on those under it, and only on
 * them: no kit draws, no part knows the document it is in, and nothing
 * in the picture knows a window or the screen's pixels.
 *
 *   Office            this file: Playground.game view update initial
 *
 *   Office_model      the state, a value: the document's versions (Undo),
 *                     what is selected, dragged, edited in place
 *   Office_update     a frame's mouse and keys  ->  the next model
 *   Office_edit       the edits, each a version; the menus that ask
 *   Office_page       where things are on a page; the text round them
 *   Office_view       the model  ->  shapes
 *   Office_export     the same shapes  ->  a PDF file
 *   Office_templates  a new document of each kind
 *
 *   Document          a body, and the objects floating on it
 *   File_menu, Saved  its file: Marshal behind a line, in the Store
 *
 *   Component         what a part is: a record of functions
 *   Part_text    Part_sheet    Part_picture   Part_drawing   Part_chart
 *      |             |              |              |         Part_image
 *   Rich, Style  Sheet          Bitmap, Paint  Figure
 *   Page         Formula        Pattern        Drawing       the kits:
 *      |             |          Seed_fill          |         they draw
 *   Stroke_text  Sheet_view                    Figure_shapes nothing
 *   ------------------------------------------------------ apps/office
 *   Gui               menus, buttons, fields: immediate mode
 *   lib_gui           Widget (a box, its paint), Text_edit (the piece
 *                     table), Theme, Focus
 *   Playground        shapes (rectangle, oval, words, group; move,
 *                     scale, rotate) and the computer: mouse, keys, time
 *   Hershey           the letters' strokes (lib_graphics)
 *
 * A frame's way, which is the whole program: the platform reads the
 * mouse and the keys into a [computer]; [update] makes the next model
 * from it; [view] makes that model a list of shapes; the platform
 * draws them. The model is a value and the view a function of it
 * (Mvu.mli says what that buys), so undo is a list of documents
 * (Undo), Export is the view written to a file, and a session
 * recorded as a script of keys gives the same frame each time, which
 * is how this program is tested (Session).
 *
 * Where the shapes go is not this program's business. It is linked
 * with one Playground_platform, and there are four:
 *
 *   ppm        a frame written to a file: Linux, the tests
 *   sdl        a window on Linux
 *   software   Plan 9: the pixels computed here, the picture given to
 *              the draw device
 *   draw       Plan 9: a message a shape to the draw device, which has
 *              the pixels (Display, Draw: lib_graphics)
 *
 * The first three share Shape_render_software, which fills polygons
 * and strokes lines with lib_graphics (Fill, Stroke, Blit); the last
 * two share Plan9_loop, which opens /dev/draw, the mouse and the
 * keyboard. And those are files: on the bare mini-9pi the kernel's
 * devices, in a window the ones mini-rio serves under the same names
 * (Fileserver). So mini-office is the same program on the screen and
 * in a window, and has not one line about windows:
 *
 *   mini-office -> Playground -> Playground_platform -> /dev/draw,
 *                  shapes        Display, Draw           /dev/mouse...
 *                                                           |
 *                                             the kernel's, or mini-rio's
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
 *
 * evolution:
 * The suite's programs are older than the suite. The spreadsheet is
 * VisiCalc's (Dan Bricklin and Bob Frankston, 1979, the Apple II),
 * then Lotus 1-2-3's (1983, the IBM PC), then Excel's (Microsoft,
 * 1985, the Macintosh): Sheet.mli. The word processor that shows the
 * page is Bravo's (Butler Lampson and Charles Simonyi, Xerox PARC,
 * 1974), made modeless by Gypsy (Larry Tesler and Tim Mott, 1975),
 * and Simonyi's again at Microsoft, Word (1983): Rich.mli, Page.mli.
 * The picture as dots and the picture as objects are MacPaint and
 * MacDraw (Apple, 1984): Bitmap.mli, Figure.mli. Slides came last,
 * PowerPoint (Robert Gaskins and Dennis Austin, Forethought, 1987,
 * bought by Microsoft that year). They were sold apart, then in one
 * box (Microsoft Office, 1989 for the Macintosh), and only then made
 * to hold each other's documents (OLE, and in 1993 OLE 2:
 * Component.mli). The other road was one program from the start, its
 * kinds of document sharing everything: AppleWorks (1984), Lotus
 * Symphony (1984), ClarisWorks (1991), whose frames of one kind in
 * another are the nearest ancestor of this program's objects.
 *
 * modern:
 * What a suite is now, and is not here, is several people in one
 * document at once: Google Docs (2006) and its like run in a browser
 * and merge every keystroke of every writer. The first way to do it,
 * operational transformation (Ellis and Gibbs, 1989), rewrites an
 * edit made beside another so that both orders give the same text;
 * the later one, a CRDT, makes the edits commute by construction. A
 * document as a value with a list of its versions, as here, is the
 * case of one writer: the list would have to become a graph.
 *
 * others:
 * Unix's and Plan 9's compound document is a text file and a
 * pipeline. A table is the lines between .TS and .TE, a drawing
 * between .PS and .PE, an equation between .EQ and .EN, and tbl, pic
 * and eqn are each a program that rewrites its own lines for troff
 * and leaves the others alone: pic file | tbl | eqn | troff. The
 * same three ideas as Component's, by other means: a part is edited
 * by the one editor there is, the text editor; the registry is the
 * pipeline; and a part no program knows passes through whole. What
 * it gives up is this program's subject, seeing the page while
 * changing it.
 *
 * References: docs/plans/plan_office.md (what was copied, what
 * changed, what runs where); the playground's apps/office, whose
 * other programs (TinyVisiCalc, TinyLotus123, TinyExcel, TinyBravo,
 * TinyWord, TinyOpenDoc...) are the history above, one program each.
 * Butler Lampson, "Bravo Manual", in the Alto User's Handbook (Xerox
 * PARC, 1976-78) (from memory). Brian Kernighan, "PIC -- A Language
 * for Typesetting Graphics" (1982), for the other road.
 *)
(* ix: the author's playground's apps/office/TinyOffice.ml (docs/plans/plan_office.md) *)
let app caps = Playground.game Office_view.view (Office_update.update caps ~exported:Office_export.pdf) Office_model.initial
let () =
  Cap.main (fun caps ->
      (* heap=modest: a document is kept, with its history (Plan9_loop
       * says what it changes) *)
      try Playground_platform.run_app caps (("heap", "modest") :: Playground_platform.flags caps) (app (caps :> File_menu.caps))
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1)
