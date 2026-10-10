(* Pdf: a PDF file read -- its objects found, its pages listed.

   A PDF file is a pile of numbered *objects* -- dictionaries, arrays,
   numbers, strings, streams of bytes (Pdf_object.mli) -- that name
   each other by number ("12 0 R"), and at the end a table saying at
   which byte each one starts:

     %PDF-1.4                          the first line
     1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
     2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
     3 0 obj << /Type /Page /Contents 4 0 R ... >> endobj
     4 0 obj << /Length 44 >> stream ... endstream endobj
     xref                              where each object is
     0 5
     0000000000 65535 f
     0000000009 00000 n
     ...
     trailer << /Size 5 /Root 1 0 R >>
     startxref
     312                               where the table is
     %%EOF

   A reader starts from the end: "startxref", the table, the trailer's
   /Root (the catalog), its /Pages -- a tree whose leaves are the
   pages, and whose nodes hand down what a page does not say itself
   (its paper's size, its fonts). Nothing else is read until asked
   for: the hundredth page of a thousand is one walk down the tree
   and a few objects, which is what the table is for. PostScript, the
   language PDF came from, had to be run from its first line to know
   what its hundredth page was.

   A file is changed by adding to its end: new objects, a new table
   that names the old one (/Prev). So the tables are a chain, the
   newest first, and an object's place is the first one met.

   Since PDF 1.5 (2003) the table may be a stream of binary numbers
   instead of text, and small objects may be packed together in one
   compressed stream ("object streams"): what every TeX and every
   recent program writes. Both are read here.

   A file whose table is wrong or missing -- cut short, edited by
   hand, as tests/pdf's standard.pdf -- is read by looking for every
   "n g obj" in it ([of_string] does it when the table leads nowhere).

   Not read: an encrypted file (said), the outline, links and form
   fields, the names of pages.

   cs-history:
   John Warnock's memo of 1991, "The Camelot Project": documents sent
   between machines of any make and looking the same on each. Adobe had PostScript
   (1984), which printers understood; PDF, with Acrobat in June 1993,
   is PostScript's picture of a page -- paths, text, pictures, under
   a transform -- with the programming taken out and an index put in.
   An ISO standard since 2008 (ISO 32000-1, PDF 1.7).

   modern:
   For fifteen years a browser showed a PDF through Adobe's plug-in.
   Chrome built a viewer in (2010, Foxit's engine, open since 2014 as
   PDFium); Mozilla's PDF.js (Andreas Gal and Chris Jones, 2011,
   in Firefox from 2013) is a viewer written in JavaScript, drawing on
   a <canvas> -- the proof that the web's own platform could do what
   the plug-in did, and the reason a browser written from scratch can
   reasonably have one.

   size:
   A page on the screen is about 4,800 lines of OCaml here
   (scripts/stats/pdf_survey.sh, 2026-10-10): mini-page's window 266,
   this directory 1,458, the fonts under it 1,202 (TrueType, CFF,
   Type 1), and what both stand on 1,839 (JPEG, PNG, Deflate, curves
   made lines, a polygon filled, a picture copied). Plan 9's page is
   3,919 lines of C and draws no PDF itself: it runs Ghostscript,
   which is more than 100,000 (the author's memory, not counted here).
   Three reasons for the distance:

   - PDF is not PostScript. To show a PostScript page is to run a
     program: procedures, loops, dictionaries, a memory that is
     collected, some hundreds of operators. A PDF page is a flat list
     of drawing operators; what runs it is Pdf_render, 375 lines.
     Most of Ghostscript is the language, not the drawing.

   - A subset, the one ordinary files are written in: what pdfTeX, a
     browser and an office program produce. Not read: an encrypted
     file, the outline, links; a scanned page's pictures (JBIG2, JPEG
     2000, CCITT fax); a colour profile, taken by its number of
     channels as grey, RGB or CMYK. Ghostscript has all of these, and
     hinted fonts, tens of devices and printers, overprint, halftones,
     and thirty years of files that are wrong and must be shown.

   - Drawn the simple way: one paper in memory (Pdf_canvas), a path
     made a polygon, one filler, a glyph its outline filled, with no
     hinting and none kept from one use to the next. So a page is
     seconds and over a hundred megabytes by mini-ml (the book:
     plan_pdf.md), where a tuned C program takes milliseconds.

   And variants with pattern matching make a parser a fraction of its
   C. So not 266 lines against 100,000: 4,800 for most files, slowly,
   on one device, against all of PostScript and PDF, fast, on any.

   References: ISO 32000-1:2008 (PDF 1.7), sections 7.5 (file
   structure) and 7.7 (document structure); J. Warnock, The Camelot
   Project, 1991. *)
(* ix: mini-chrome's libs/pdf/Pdf.mli (docs/plans/plan_pdf.md); the note
 * "size" above is ix's *)

type t

(* a page: its dictionary, what its content names (fonts, pictures...),
 * the part of the paper shown (in points, 1/72 inch: left, bottom,
 * right, top), and how it is turned (0, 90, 180 or 270 degrees) *)
type page = { dict : Pdf_object.dict; resources : Pdf_object.t; box : float * float * float * float; rotate : int }

(* whether bytes look like a PDF file: "%PDF-" in the first kilobyte *)
val sniff : string -> bool

(* the file read; fails (Failure) on what is not one, has no pages, or
 * is encrypted *)
val of_string : string -> t

(* a reference followed to its object (Null if it leads nowhere);
 * anything else as it is *)
val resolve : t -> Pdf_object.t -> Pdf_object.t

(* [get t d key]: a dictionary's value, resolved; Null if absent *)
val get : t -> Pdf_object.dict -> string -> Pdf_object.t

(* an object as a dictionary (a stream's, too); empty if it is none *)
val dict : t -> Pdf_object.t -> Pdf_object.dict

(* a stream's bytes, its filters undone (Pdf_filter); "" if it is none *)
val data : t -> Pdf_object.t -> string

(* the pages, in order *)
val pages : t -> page list

(* a page's drawing operators (Pdf_render) *)
val content : t -> page -> string
