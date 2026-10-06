(* The viewers (Oberon's Viewers): the display is cut in tracks, side
 * by side, and a track in viewers, one above the other, with no gap
 * and no overlap. The space no viewer has, at a track's top, is its
 * filler's, a viewer as the others. So opening a viewer takes a piece
 * of another's place and closing one gives it to the one above: this
 * module does that arithmetic and tells the viewers, by messages, what
 * became of their rectangle; they draw.
 *
 * Not here yet: a track opened over others and closed again
 * (OpenTrack, CloseTrack: System.Grow's). *)

(* state: 0 closed, 1 a filler, 2 displayed *)
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

(* [open_ v x y]: in the track at x, v takes the part below y of the
 * viewer that has y (all of it, when too little would be left) *)
val open_ : viewer -> int -> int -> unit
(* [change v y]: v's top moves to y, the viewer above taking or giving *)
val change : viewer -> int -> unit
(* its place goes to the viewer above *)
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
