(* Pdf reads a PDF file: it finds its objects and lists its pages.

   A PDF file is a pile of numbered *objects* -- dictionaries, arrays,
   numbers, strings, streams of bytes (Pdf_object.mli) -- that name
   each other by number ("12 0 R"). At the end, a table says at which
   byte each one starts:

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

   A reader starts from the end. It reads "startxref", then the table,
   then the trailer's /Root (the catalog), then the catalog's /Pages.
   /Pages is a tree whose leaves are the pages, and whose nodes hand
   down what a page does not say itself (its paper's size, its fonts).
   Nothing else is read until it is asked for: the hundredth page of a
   thousand costs one walk down the tree and a few objects, which is
   what the table is for. PostScript, the language PDF came from, had
   to be run from its first line to know what its hundredth page was.

   A file is changed by adding to its end: new objects, and a new
   table that names the old one (/Prev). So the tables form a chain,
   the newest first, and an object's place is the first one met.

   Since PDF 1.5 (2003), the table may be a stream of binary numbers
   instead of text, and small objects may be packed together in one
   compressed stream ("object streams"). Every TeX and every recent
   program writes files this way. Both forms are read here.

   A file whose table is wrong or missing (cut short, or edited by
   hand, as the tests' standard.pdf is) is read by looking for every
   "n g obj" in it. [of_string] does this when the table leads nowhere.

   An encrypted file is not read ([of_string] says so), and neither
   are the outline and the form fields. Links are read ([links]): the
   links of a page, to another page or to an address.

   Where it stands in ix: this module is the entry to the directory,
   which takes bytes in and gives a picture out. Under the directory
   are most of lib_graphics and a part of lib_compression:

     bytes --Pdf--> objects, pages --Pdf_render--> Pdf_canvas --> Rgba_image
              |                       |    |
         Pdf_object              Pdf_font  Pdf_color, Pdf_shading,
         Pdf_filter                   |    Pdf_image
         (Zlib, Jpeg)                 |
                      Truetype, Cff, Type1 --> Outline --Curve--> polygons
                                                         (Fill, Stroke)

   Two programs call it. mini-page shows a file's pages in a window
   (Pageview), and mini-netscape shows a PDF that a link leads to as a
   page of pictures (Pdf_viewer). The way back is Pdf_write, which
   uses none of the reading modules. mini-office writes a file with
   it, and Pdf_write's tests read the file again with this module and
   draw it.

   terminology:
   PostScript, PDF, and a page description language. PostScript is a
   programming language whose programs draw pages, and a printer runs
   them. PDF is a file format: it has the drawing operators of
   PostScript, with the pages kept apart and indexed, and nothing to
   run. Both describe a page by what is on it (this letter of this
   font at this place) and not by its dots. That is what a page
   description language is, and it is why the same file prints at 300
   dots an inch and shows at 96.

   cs-history:
   John Warnock's memo of 1991, "The Camelot Project", asked for
   documents that could be sent between machines of any make and look
   the same on each. Adobe had PostScript (1984), which printers
   understood. PDF, which came with Acrobat in June 1993, is
   PostScript's picture of a page (paths, text and pictures, under a
   transform) with the programming taken out and an index put in. It
   has been an ISO standard since 2008 (ISO 32000-1, PDF 1.7).

   modern:
   For fifteen years, a browser showed a PDF through Adobe's plug-in.
   Chrome built a viewer in, in 2010, with Foxit's engine, which has
   been open since 2014 as PDFium. Mozilla's PDF.js (Andreas Gal and
   Chris Jones, 2011, in Firefox from 2013) is a viewer written in
   JavaScript that draws on a <canvas>. It proved that the web's own
   platform could do what the plug-in did, and it is the reason a
   browser written from scratch can reasonably have one.

   size:
   Showing a page on the screen takes about 4,800 lines of OCaml here
   (scripts/stats/pdf_survey.sh, 2026-10-10): 266 for mini-page's
   window, 1,458 for this directory, 1,202 for the fonts under it
   (TrueType, CFF, Type 1), and 1,839 for what both stand on (JPEG,
   PNG, Deflate, curves made into lines, a polygon filled, a picture
   copied). Plan 9's page is 3,919 lines of C and draws no PDF itself.
   It runs Ghostscript, which is more than 100,000 lines (from the
   author's memory, not counted here). There are three reasons for
   the distance:

   - PDF is not PostScript. To show a PostScript page is to run a
     program, with procedures, loops, dictionaries, a garbage-collected
     memory, and some hundreds of operators. A PDF page is a flat list
     of drawing operators, and what runs it is Pdf_render, 375 lines.
     Most of Ghostscript is the language, not the drawing.

   - Only a subset is read: the one that ordinary files are written
     in, as pdfTeX, a browser and an office program produce them. An
     encrypted file, the outline, and a scanned page's pictures (JBIG2,
     JPEG 2000, CCITT fax) are not read. A colour profile is taken, by
     its number of channels, as grey, RGB or CMYK. Ghostscript has all
     of these, and also hinted fonts, tens of devices and printers,
     overprint, halftones, and thirty years of files that are wrong
     and must be shown anyway.

   - The page is drawn the simple way. There is one paper in memory
     (Pdf_canvas), a path is made into a polygon, and there is one
     filler. A glyph is drawn by filling its outline, with no hinting,
     and nothing is kept from one use to the next. So a page takes
     seconds and over a hundred megabytes when compiled by mini-ml
     (the book: plan_pdf.md), where a tuned C program takes
     milliseconds.

   Also, variants with pattern matching make a parser a fraction of
   the size of its C. So the comparison is not 266 lines against
   100,000. It is 4,800 lines that show most files, slowly, on one
   device, against all of PostScript and PDF, fast, on any device.

   References: ISO 32000-1:2008 (PDF 1.7), sections 7.5 (file
   structure) and 7.7 (document structure); J. Warnock, The Camelot
   Project, 1991. *)
(* ix: from mini-chrome's libs/pdf/Pdf.mli (docs/plans/done/plan_pdf.md);
 * the "size" note above is ix's own *)

type t

(* a page. It has its dictionary; the resources that its content names
 * (fonts, pictures...); the part of the paper shown (in points, 1/72
 * inch: left, bottom, right, top); how it is turned (0, 90, 180 or 270
 * degrees); and its object's number, which a link to it names (0 if it
 * has none) *)
type page = {
  dict : Pdf_object.dict;
  resources : Pdf_object.t;
  box : float * float * float * float;
  rotate : int;
  number : int;
}

(* whether bytes look like a PDF file, that is, have "%PDF-" in their
 * first kilobyte *)
val sniff : string -> bool

(* reads the file. It fails (Failure) on bytes that are not a PDF file,
 * on a file with no pages, and on an encrypted file *)
val of_string : string -> t

(* follows a reference to its object (Null if it leads nowhere); any
 * other object is given back as it is *)
val resolve : t -> Pdf_object.t -> Pdf_object.t

(* [get t d key] is the value of key in d, resolved, or Null if key is
 * absent *)
val get : t -> Pdf_object.dict -> string -> Pdf_object.t

(* an object as a dictionary (a stream's dictionary, too); the empty
 * dictionary if the object has none *)
val dict : t -> Pdf_object.t -> Pdf_object.dict

(* a stream's bytes, with its filters undone (Pdf_filter); "" if the
 * object is not a stream *)
val data : t -> Pdf_object.t -> string

(* the pages, in order *)
val pages : t -> page list

(* a page's drawing operators, which Pdf_render runs *)
val content : t -> page -> string

(* where a link leads. It is either a page of the file (counted from 0)
 * with, if the link says so, the height on it to show at the window's
 * top (in the page's points, as in box); or an address (a URI action) *)
type target = Page of int * float option | Uri of string

(* a link: where it is on its page (in points, as in box: left, bottom,
 * right, top), and where it leads *)
type link = { rect : float * float * float * float; target : target }

(* [links t pages p] is the list of page p's links. They are its
 * /Annots of subtype /Link (section 12.5.6.5) that lead to a page of
 * [pages] (a destination, named or not: section 12.3.2) or to a URI
 * (12.6.4.7). The other links (to another file, to a program to run,
 * to JavaScript) are left out *)
val links : t -> page array -> page -> link list
