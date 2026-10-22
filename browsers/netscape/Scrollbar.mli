(* Scrollbar: the bar at the right of a page longer than the window --
 * a thumb as tall as the part that shows, as far down its track as
 * that part is down the page; dragged, or its track clicked above or
 * below it for a page up or down.
 *
 *   a track 600 high from y = 50; a page of 3000, 600 shown,
 *   scrolled by 1200
 *
 *   thumb    120 high (600 * 600 / 3000), its top 240 under the
 *            track's (1200 of the 2400 it can be scrolled by: half
 *            of the 480 it can travel): from y = 290 to 410
 *   a press  at y = 300, on the thumb: grabbed 10 under its top. The
 *            pointer dragged to y = 410: the thumb's top at 400, the
 *            page scrolled by 1750 (350 / 480 of 2400)
 *            at y = 100, above the thumb: a page up; at 500: down
 *
 * It lies over the page's right edge and takes no room from it (a
 * page is not laid out again because its bar appears); a page that
 * fits has none. Window coordinates, y down; the page's lengths in
 * any unit they share (the page's, here). The program keeps what a
 * drag needs, the grab, in its model.
 *
 * ix: the author's mini-chrome's libs/gui/Gui_scrollbar.ml (its
 * 8af888e), y down, drawn as Netscape's: a grey track, a raised
 * thumb.
 *
 * evolution:
 * The bar to scroll by is Xerox PARC's (the Alto's Smalltalk, in the
 * 1970s); the Macintosh's (1984) has the thumb, its scroll box, whose
 * place says where one is, and an arrow at each end. Netscape's was
 * the system's (Motif's on Unix, Windows' on Windows); the bar that
 * lies over the page and fades is the iPhone's (2007), then Mac OS X
 * Lion's and Chrome's. *)

type t = {
  right : float; (* the track's right edge *)
  top : float; (* and its top *)
  height : float;
  total : float; (* the page's length *)
  shown : float; (* the part that shows *)
  offset : float; (* how far it is scrolled *)
}

val width : float

(* the thumb's top and its length; None when the whole page shows *)
val thumb : t -> (float * float) option

(* what a point is on: the thumb, with how far under the thumb's top
 * (the grab a drag keeps); the track above it or below it *)
type hit = Thumb of float | Before | After

val at : t -> float * float -> hit option

(* [dragged bar ~grab y]: the offset that puts the thumb's top [grab]
 * above the pointer at [y], within what can be scrolled *)
val dragged : t -> grab:float -> float -> float

(* the bar drawn; nothing when the whole page shows *)
val shapes : t -> Playground.shape list
