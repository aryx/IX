(* Edges: a face made edges of the screen (Quake's r_draw.c,
 * R_RenderFace, R_ClipEdge, R_EmitEdge), and the tables of a frame's
 * edges, surfaces and spans (r_edge.c's, r_shared.h's edge_t, surf_t,
 * espan_t).
 *
 * Quake does not draw a face as a polygon. Each of its edges is
 * clipped by the planes of the view, projected, and filed under the
 * first scanline it crosses, sorted by where it crosses it (newedges);
 * and under its last (removeedges). An edge going down the screen is
 * a face's right side (it trails: the face ends there), one going up
 * its left (it leads: the face starts):
 *
 *            v0 (lead: from v1 up to v0)
 *           /  \
 *          /    \  (trail: from v0 down to v1)
 *         /      \        a face, its edges clockwise as seen
 *        v2 ------v1      (a horizontal edge crosses no scanline:
 *                          none is made)
 *
 * The face itself becomes a surface: its key (the order the BSP's walk
 * reached it, front to back: smaller is nearer) and its 1/z's plane on
 * the screen (zistepu, zistepv, ziorigin: 1/z is linear in u and v).
 * Scan turns the edges into spans, each a surface's run of pixels on a
 * scanline; Spans draws them.
 *
 * An edge clipped by the left plane loses the face's left side on the
 * screen: a vertical edge along the left border is made for it, from
 * where the face left the view to where it came back. The right side
 * needs none (a face still open at the right border ends there).
 *
 * The edges are not shared between the two faces that have one, as
 * id's cache did (cachededgeoffset): each face makes its own; the same
 * spans, twice the edges.
 *
 * The tables are arrays of ints and floats indexed by an edge's, a
 * surface's or a span's number, linked by numbers, as id's arrays of
 * structs: a frame makes thousands and keeps none, and no allocation
 * is made while drawing. Edges 0 to 3 are the scan's own: the head
 * (the left border, starting the background), the tail (the right
 * border), the one after the tail and a sentinel; surface 1 is the
 * background, behind everything (key max_int).
 *
 * Fixed point: u is 16.16 here, where id's was 12.20 (a 31-bit int
 * holds 320 x 2^16, not x 2^20); a u_step is that of an edge that
 * crosses at least two scanlines, at most the screen's width. *)

type t = {
  (* the edges *)
  u : int array;
  u_step : int array;
  (* the surface it ends (trailing), the one it starts (leading); 0
   * none *)
  surf_trail : int array;
  surf_lead : int array;
  next : int array;
  prev : int array;
  next_remove : int array;
  mutable num_edges : int;
  (* each scanline's new edges and those it is the last of: -1 none *)
  newedges : int array;
  removeedges : int array;
  (* the surfaces *)
  key : int array;
  last_u : int array;
  spanstate : int array;
  snext : int array;
  sprev : int array;
  insubmodel : bool array;
  (* the face (Model's surface number), the entity (0 the world) *)
  face : int array;
  entity : int array;
  nearzi : float array;
  zistepu : float array;
  zistepv : float array;
  ziorigin : float array;
  (* the first of its spans; -1 none *)
  spans : int array;
  mutable num_surfaces : int;
  (* the spans *)
  span_u : int array;
  span_v : int array;
  span_count : int array;
  span_next : int array;
  mutable num_spans : int;
  (* what the next faces are: in a brush model, which entity *)
  mutable in_submodel : bool;
  mutable current_entity : int;
  (* a face's edges' state (r_draw.c's globals) *)
  mutable lastvertvalid : bool;
  mutable u1 : float;
  mutable v1 : float;
  mutable lzi1 : float;
  mutable ceilv1 : int;
  mutable nearzi_face : float;
  mutable nearzi_only : bool;
  mutable emitted : bool;
  mutable left_clipped : bool;
  mutable right_clipped : bool;
  mutable left_enter : Model.vec;
  mutable left_exit : Model.vec;
  mutable right_enter : Model.vec;
  mutable right_exit : Model.vec;
}

val head : int
val tail : int
val after_tail : int
val sentinel : int
val background : int

(* the fraction's bits of u *)
val shift : int

(* [create height]: the tables, empty *)
val create : int -> t

(* [clear e]: a frame's start: no edge, no surface but the background,
 * no span *)
val clear : t -> unit

(* [render_face e v m face clipflags key]: the face's edges filed, its
 * surface made (R_RenderFace); clipflags the planes (bits 0 to 3:
 * left, right, top, bottom) its node's box crosses; key the
 * surface's, or None for the next (v.currentkey) *)
val render_face :
  t -> View.t -> Model.t -> Model.surface -> int -> int option -> unit

(* [render_poly e v face clipflags iter key chained]: the same for a
 * piece of a face, its edges given by iter (a brush model's face cut
 * by the world's planes: R_RenderBmodelFace); chained if each edge
 * starts where the one before ended *)
val render_poly :
  t ->
  View.t ->
  Model.surface ->
  int ->
  ((Model.vec -> Model.vec -> unit) -> unit) ->
  int option ->
  bool ->
  unit
