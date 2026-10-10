(* mini-office's page: where a document's text, its bands and its
 * objects are, on the page and on the screen; the text laid out round
 * the objects, a point's object.
 *
 * Three systems of coordinates, and this module is the only one
 * that knows all three:
 *
 *   the screen    Playground's: (0, 0) the middle, y up. The mouse is
 *                 in it, and every shape drawn
 *   the page      (0, 0) the first page's top left corner, y down,
 *                 and on down through the pages, page k starting at
 *                 k times [pitch] (a page's height and the gap). An
 *                 object's x, y, w, h are in it
 *   the text      the page's less [margin] on each axis: what Page
 *                 lays out in and answers in
 *
 *      screen                              page
 *                  y ^
 *     [origin] +---|---+               (0, 0) +-----------> x
 *              |   |   |                      |  +--text--+
 *        ------|---+---|--> x                 |  |        |
 *              |  0,0  |                      |  +--------+
 *              +-------+                    y v
 *
 *   [to_page] (sx, sy) = (sx - left, top - sy), (left, top) = [origin]
 *
 * Scrolling is [origin] moved up, and nothing else: the page's
 * coordinates do not know they are scrolled.
 *
 * Pages, wrapping and tied objects are all one mechanism, the boxes
 * Page.layout goes round ([text_around]):
 *
 *   an object, text on both sides      its box, with some room
 *   text above and below only          its box, as wide as the text
 *   text on its wider side             its box, reaching the edge of
 *                                      the narrower side
 *   in front of the text               no box
 *   the end of a page                  a box across the width, from
 *                                      the bottom margin of one page
 *                                      to the top margin of the next
 *
 * So the text of a document is one tall layout, and a page break is
 * a place the lines could not be. A tied object needs the layout to
 * know where it is, and the layout needs the objects: [placed] cuts
 * the circle with two passes (its comment).
 *
 * The answers are kept while the document is the same value (the
 * same record, by ==): [placed], [layout] and [pages] are asked
 * several times a frame by the update and the view, and a document
 * that did not change is not laid out again. A document being a
 * value is what makes that test enough.
 *
 * others:
 * A real word processor's pages are not boxes in one column: each
 * page is laid out from where the one before stopped, which is what
 * lets a page have its own size, columns, and footnotes that take
 * room from its text, and lets the pages after a change be redone
 * later. The playground's Flow (a text poured through one frame
 * after another, FrameMaker's way) is that, and is not here. *)

val page_size : Document.kind -> float * float

val margin : float

val pitch : Document.kind -> float

(* the first page's top-left corner on the screen *)
val origin : Document.doc -> float * float

val to_page : Document.doc -> float * float -> float * float

val obj_box : Document.doc -> Document.obj -> Widget.box

val on_slide : Document.doc -> Document.obj -> bool

(* the main part of a sheet, picture or drawing: the page's width less
   a margin, as tall as it is at that width *)
val main_box : Document.doc -> Component.part -> Widget.box

val text_around : Document.doc -> Document.obj list -> (Rich.t * Page.t) option

(* the top of the line the text's [offset] is on, in the page's
   coordinates *)
val line_top : Page.t -> int -> float

(* The objects where they are on the page: the charts made again from
   their sheets, and those tied to a paragraph placed from its line. That
   line is found in a first layout, without them -- so an object tied
   to a paragraph does not push its own paragraph away, and a second
   layout, with them, is the one shown. (Word goes round until nothing
   moves; two passes are right unless tied objects push each other's
   paragraphs.) *)
val placed : Document.doc -> Document.obj list

val layout : Document.doc -> (Rich.t * Page.t) option

(* The header and the footer, in the top and bottom margins of every
   page: laid out as texts of their own, each page filling in its
   fields -- where Word keeps a field's code and shows its result. The
   one being edited is shown as it is typed, codes and all. *)
val band_top : Document.doc -> Document.band -> float

val band_layout : Document.doc -> Document.band -> Rich.t -> Page.t

val with_fields : page:int -> pages:int -> Rich.t -> Rich.t

(* how many pages the document has: enough for its text and its objects *)
val pages : Document.doc -> int

(* the index of the object on top at a point of the screen *)
val object_at : Document.doc -> float * float -> int option

(* the four corners of an object on the screen: top-left, top-right,
   bottom-right, bottom-left *)
val corners : Widget.box -> (float * float) list

val corner_at : Document.doc -> int -> float * float -> int option
