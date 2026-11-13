(* Scrollbar draws the bar at the right of a page that is longer than
 * the window. Its thumb takes the same share of its track as the part
 * that shows takes of the page, and it is as far down its track as
 * that part is down the page. One drags the thumb, or clicks
 * the track above or below it to go a page up or down.
 *
 *   A track is 600 high from y = 50; a page of 3000 has 600 shown,
 *   and it is scrolled by 1200.
 *
 *   thumb    It is 120 high (600 * 600 / 3000). Its top is 240 under
 *            the track's top: 1200 is half of the 2400 the page can
 *            be scrolled by, and 240 is half of the 480 the thumb can
 *            travel. It goes from y = 290 to 410.
 *   a press  At y = 300 it is on the thumb, which is grabbed 10 under
 *            its top. When the pointer is dragged to y = 410, the
 *            thumb's top is at 400, and the page is scrolled by 1750
 *            (350 / 480 of 2400).
 *            At y = 100, above the thumb, it is a page up; at 500, it
 *            is a page down.
 *
 * It lies over the page's right edge and takes no room from it (a
 * page is not laid out again because its bar appears). A page that
 * fits has no bar. Points are in window coordinates, with y going
 * down; the page's lengths are in any unit they share (here, the
 * page's). The program keeps what a drag needs, the grab, in its
 * model.
 *
 * ix: copied from libs/gui/Gui_scrollbar.ml in the author's mini-chrome
 * (its 8af888e), with y going down, and drawn as Netscape's: a grey
 * track and a raised thumb.
 *
 * evolution:
 * The scroll bar comes from Xerox PARC (the Alto's Smalltalk, in the
 * 1970s). The Macintosh's (1984) has the thumb, which it calls the
 * scroll box and whose place says where one is, and an arrow at each
 * end. Netscape used the system's bar (Motif's on Unix, Windows' on
 * Windows). The bar that lies over the page and fades came with the
 * iPhone (2007), then with Mac OS X Lion and Chrome. *)

type t = {
  right : float; (* the track's right edge *)
  top : float; (* the track's top *)
  height : float;
  total : float; (* the page's length *)
  shown : float; (* the part that shows *)
  offset : float; (* how far it is scrolled *)
}

val width : float

(* The thumb's top and its length, or None when the whole page shows. *)
val thumb : t -> (float * float) option

(* What a point is on: the thumb, with how far the point is under the
 * thumb's top (the grab that a drag keeps), or the track above or below
 * the thumb. *)
type hit = Thumb of float | Before | After

val at : t -> float * float -> hit option

(* [dragged bar ~grab y] is the offset that puts the thumb's top [grab]
 * above the pointer at [y], kept within what can be scrolled. *)
val dragged : t -> grab:float -> float -> float

(* The bar's shapes, or none when the whole page shows. *)
val shapes : t -> Playground.shape list
