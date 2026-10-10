(* A drawing: its figures, from the one at the back to the one in
 * front, each with an id that stays its own while it is moved,
 * resized, sent back or brought forward -- a selection is a list of
 * ids, not of places in the list.
 *
 * The order is the whole of "in front of": a figure is drawn after
 * everything behind it, and a click is tried on everything in front of
 * it first. So the list is drawn from the start and hit-tested from the
 * end -- the same two walks, in opposite directions, as any toolkit's
 * tree (notes_gui.md section 6).
 *
 * A drawing is a value: every function here returns a new one, so the
 * application's undo is keeping the old ones (appkits/document/Undo).
 *
 * Grouping is MacDraw's own: the figures chosen become one Group,
 * taking the place in the order of the one that was furthest in front;
 * ungrouping puts them back there, in their order, with new ids.
 *
 * Four figures added, then two of them grouped, the ids as [add] and
 * [group] give them (the back of the drawing on the left):
 *
 *   add four times        1:rect  2:oval  3:line  4:text
 *   to_back [3]           3:line  1:rect  2:oval  4:text
 *   group [2; 4]          3:line  1:rect  5:Group [oval; text]
 *   ungroup 5             3:line  1:rect  6:oval  7:text
 *
 *   [at] a point where the line and the rect both are: 1, the rect,
 *   being after the line in the list, and so in front of it
 *
 * An id is never given twice, so a selection kept from before an edit
 * names the same figures after it or nothing: 2 and 4 are gone when
 * the group is made, and a list of places would now name others.
 *
 * Where it stands. Part_drawing holds one, with a selection (ids) and
 * what a drag is doing; its menu's Bring to Front and Send to Back
 * are [to_front] and [to_back]. Figure_shapes draws [figures] in
 * their order. mini-office's page is the same structure a level up:
 * a document's objects are a list back to front, drawn from the
 * start and clicked from the end (Document, Office_page.object_at).
 *
 * terminology:
 * Drawing back to front and letting what comes later cover what came
 * before is the painter's algorithm; the place in the list is the
 * z-order, z being the axis out of the screen. A list of shapes kept
 * to be drawn again is a display list, as against a picture drawn
 * once and forgotten (Bitmap.mli).
 *
 * others:
 * The same rule elsewhere in ix: an SVG file's shapes are painted in
 * the order of the file (Svg), and a PDF page's operators one over
 * the other (Pdf_render). HTML has a number to change the order,
 * z-index, and pays for it with the rules that say what the number
 * is compared with.
 *
 * References: the playground's appkits/draw and its TinyMacDraw. *)

(*****************************************************************************)
(* {1 The figures} *)
(*****************************************************************************)

type id = int
type t

val empty : t

(* [add figure t]: in front of everything, and its id *)
val add : Figure.t -> t -> t * id

(* back to front *)
val figures : t -> (id * Figure.t) list
val get : t -> id -> Figure.t option

(*****************************************************************************)
(* {1 Clicking and selecting} *)
(*****************************************************************************)

(* [at ~tolerance t point]: the figure in front at that point, if any *)
val at : tolerance:float -> t -> Figure.point -> id option

(* the figures entirely inside a box: what a marquee drag selects *)
val within : t -> Figure.box -> id list

(*****************************************************************************)
(* {1 Editing} *)
(*****************************************************************************)

val update : id -> (Figure.t -> Figure.t) -> t -> t
val move : id list -> float -> float -> t -> t
val delete : id list -> t -> t

(* in front of all the others, or behind them -- keeping their order
 * among themselves *)
val to_front : id list -> t -> t
val to_back : id list -> t -> t

(* [group ids t]: one Group of them, and its id (None for fewer than
 * two) *)
val group : id list -> t -> t * id option

(* [ungroup id t]: its figures back, and their ids ([] if it was not a
 * group) *)
val ungroup : id -> t -> t * id list

(* copies, a little down and to the right, in front; and their ids *)
val duplicate : id list -> t -> t * id list

(*****************************************************************************)
(* {1 Lining up} *)
(*****************************************************************************)

type side = Lefts | Rights | Tops | Bottoms | Centers

(* [align side ids t]: the figures lined up on the left edge of the
 * leftmost of them (and so on), or on their common horizontal centre *)
val align : side -> id list -> t -> t

(* the box round some figures *)
val bounds : t -> id list -> Figure.box option
