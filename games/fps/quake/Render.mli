(* Render: a frame of Quake's software renderer (r_main.c,
 * R_RenderView, R_EdgeDrawing): what the eye sees, 320 by 200 bytes of
 * the palette.
 *
 *   the eye's leaf --> Bsp.mark_leaves: the PVS marked
 *        |
 *   Bsp.render_world: the tree front to back, faces made edges
 *   Bsp.render_bmodels: the doors' and lifts' faces, cut by the leaves
 *        |                                         (Edges)
 *   Scan.scan_edges: the edges sorted on each scanline, spans
 *        |
 *   Spans.draw: each span textured with its surface (Surfcache:
 *               the texture lit by its lightmaps, kept), or the
 *               water, or the sky
 *
 * Each pixel of the world is drawn once. The models (monsters, items)
 * are drawn after, over it, by a z-buffer the spans filled (Alias,
 * Things).
 *
 * Where it stands in mini-quake: the game (Quake.ml) makes one, and
 * asks a frame of it at each frame of the playground. *)

type t = {
  view : View.t;
  edges : Edges.t;
  spans : Spans.t;
  cache : Surfcache.t;
}

(* [create m colormap] *)
val create : Model.t -> string -> t

(* [frame r m eye pitch yaw time styles bmodels things]: the picture
 * into r.view.screen; styles the light styles' strings; bmodels the
 * brush models drawn, each (its entity's number, its model, its
 * origin, its frame); things the models *)
val frame :
  t ->
  Model.t ->
  Model.vec ->
  float ->
  float ->
  float ->
  string array ->
  (int * int * Model.vec * int) list ->
  Things.thing list ->
  unit
