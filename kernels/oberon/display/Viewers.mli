(* The viewers (Oberon's Viewers): the display is cut in tracks, side
 * by side, and a track in viewers, one above the other, with no gap
 * and no overlap. The space no viewer has, at a track's top, is its
 * filler's, a viewer as the others. So opening a viewer takes a piece
 * of another's place and closing one gives it to the one above: this
 * module does that arithmetic and tells the viewers, by messages, what
 * became of their rectangle; they draw.
 *
 * A track may be opened over others, which are kept under it, their
 * viewers suspended, until it is closed (System.Grow: a viewer given
 * the whole height, or the whole display).
 *
 * A track of height 768, and [open_ v x 300] in it:
 *
 *     768 +-----------+          768 +-----------+
 *         |  filler   |              |  filler   |
 *     500 +-----------+          500 +-----------+
 *         |           |              |     u     |  Modify (300, 200)
 *         |     u     |          300 +-----------+
 *         |           |              |     v     |  then drawn by who
 *     100 +-----------+          100 +-----------+  opened it
 *         |     w     |              |     w     |
 *       0 +-----------+            0 +-----------+
 *
 * v takes the part of u below 300 and u keeps its top; closing v
 * gives the rectangle to the viewer above again (u: Modify (100,
 * 400)). So the heights of a track always add up to the display's,
 * with no test for it anywhere: the filler is what makes the
 * arithmetic total, an element that is there so that there is
 * always a viewer above.
 *
 * This module draws nothing and knows no kind of viewer: a viewer
 * is a frame (Display) and a state, and what it does of Modify is
 * its handler's (MenuViewers moves its two frames; a text frame
 * shows more lines or fewer).
 *
 * cs-history:
 * Windows that overlap, each a sheet of paper on a desk, are
 * Smalltalk's (Xerox PARC, mid 1970s), and what the Star, the Lisa
 * and the Macintosh sold. Tiling was the answer of those who found
 * that the user then spends his time arranging sheets: Cedar's
 * viewers at PARC, and the first Microsoft Windows (1985), tiled
 * for another reason. Wirth and Gutknecht chose tiling for
 * Oberon, with the system placing a new viewer by a rule and the
 * user correcting it.
 *
 * others:
 * Rob Pike's acme is the nearest: columns of tiled windows, each
 * with a tag line of commands, placed by a heuristic. The tiling
 * window managers of Unix (wmii, i3, dwm) and the split panes of
 * every editor and terminal multiplexer are the same idea; mini-rio,
 * in this tree, is the other one, overlapping windows drawn by the
 * hand.
 *
 * References: "Project Oberon", chapter 4, "The display system"
 * (why tiling, and the module Viewers); Viewers.Mod of Project
 * Oberon 2013. Rob Pike, "Acme: A User Interface for Programmers"
 * (1994). *)

(* state: 0 closed, 1 a filler, 2 displayed; negative: under another track *)
type viewer = {
  frame : Display.frame;
  mutable state : int;
  menu_h : int;          (* MenuViewers': its menu's height; 0 for another kind *)
}

(* The messages a viewer gets. Restore: draw yourself, your rectangle
 * is the frame's. Modify (y, h): your rectangle becomes that one, the
 * same top or the same bottom (sent before the frame is changed: the
 * handler has both). Suspend: you are no longer displayed. *)
exception Restore
exception Modify of int * int
exception Suspend

(* the tracks' total width; a viewer's least height *)
val cur_w : int ref
val min_h : int ref

(* a new track at the right of the others, of that width and height,
 * all of it the filler's *)
val init_track : int -> int -> viewer -> unit

(* [open_track x w filler]: a track over those that [x, x + w) touches,
 * all of it the filler's; [close_track x]: the track at x, if it is
 * over others, closed, and those shown again *)
val open_track : int -> int -> viewer -> unit
val close_track : int -> unit

(* [open_ v x y]: in the track at x, v takes the part below y of the
 * viewer that has y (all of it, when too little would be left) *)
val open_ : viewer -> int -> int -> unit
(* [change v y]: v's top moves to y, the viewer above taking or giving *)
val change : viewer -> int -> unit
(* its place goes to the viewer above (the last viewer of a track over
 * others: the track is closed) *)
val close : viewer -> unit
(* the last one closed *)
val recall : unit -> viewer option

val this : int -> int -> viewer option
(* the viewer above; the filler's is the lowest *)
val next : viewer -> viewer
(* [locate x h]: in the track at x, its filler, its lowest viewer, one
 * of at least h (else the highest), and the highest: where to open *)
val locate : int -> int -> viewer * viewer * viewer * viewer
(* to every viewer *)
val broadcast : Display.msg -> unit
