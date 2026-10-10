(* Pdf_viewer: a PDF file shown as a page of the browser's: its pages
 * one under the other, each an <img> whose picture is drawn when it
 * comes into view (Tab), by lib_graphics/pdf. The author's
 * mini-chrome's (docs/plans/plan_pdf.md, stage F).
 *
 * The browser has a layout engine and scrolling already, so the
 * viewer is small: the document is turned into HTML ([html]),
 *
 *   <body>                          (grey, by a <style> in the head)
 *     <div><img src="pdf-page:1" width="816" height="1056"
 *               alt="page 1"></div>
 *     <div><img src="pdf-page:2" ...></div>
 *
 * one <img> a page, at the page's size (a PDF's point is 1/72 inch, a
 * CSS pixel 1/96: a US Letter page, 612 by 792 points, is the 816 by
 * 1056 above), white until its picture comes. The tab (Tab's
 * pdf_pages) draws the pages that are in view, and a window's height
 * before and after, as it is scrolled, and lets go of the others: a
 * page's picture is megabytes, a book a thousand pages. Zooming,
 * scrolling, going back: all the browser's own, with nothing written
 * for them here.
 *
 * pdf-page:3 is an address no server has: an <img>'s src that only
 * the tab understands ([page_of_src]), answered by [picture] where
 * any other is fetched. A PDF file is known by its first bytes
 * ([sniff]: %PDF- in its first kilobyte), whatever type its server
 * said, as a picture is by its own (Browser_picture).
 *
 * The drawing itself is Pdf_render's, over Pdf (the file's objects,
 * its pages): the same two that Pageview, the viewer outside the
 * browser, draws with; the browser adds only the page around them. In
 * mini-chrome an [options] says how much of it is done (its flag
 * pdf=: pdf=strokes for our letters, pdf=plain for the simplest
 * rendering); here everything is drawn, the letters of a font that
 * is not in the file being Pdf_render.hershey's strokes, and a
 * picture has one dot for a unit of the page shown.
 *
 * modern:
 * Chrome's viewer is a plug-in process of its own around PDFium;
 * Firefox's is a web page -- PDF.js, HTML and JavaScript drawing on
 * <canvas> elements, one a page, made as they scroll into view. This
 * is the second kind, with the drawing done in OCaml.
 *
 * cs-history:
 * For fifteen years a PDF in a browser was Adobe's Reader, a plug-in
 * (Netscape 2's invention, 1996: a program of another company's
 * drawing in a rectangle of the page), slow to start and a frequent
 * way into the machine. Chrome put a viewer of its own in the
 * browser in 2010 (Foxit's code, published as PDFium in 2014), and
 * Mozilla's PDF.js (2011) showed that the web's own canvas and
 * JavaScript were by then enough to draw one. *)

type t

(* the bytes are a PDF file's (its first ones say so), whatever its
 * type was said to be *)
val sniff : string -> bool

(* the file read: its objects' places, its pages; or why not *)
val open_ : string -> (t, string) result

(* the document as HTML, [name] its title: an <img src=[src n]> a page,
 * of the page's size *)
val html : t -> name:string -> string

(* the address of page [n]'s picture (from 1), and back *)
val src : int -> string
val page_of_src : string -> int option

(* page [n] drawn; a picture of one pixel if it cannot be *)
val picture : t -> int -> Rgba_image.t
