(* mini-office's page: where a document's text, its bands and its
 * objects are, on the page and on the screen; the text laid out round
 * the objects, a point's object. *)

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
