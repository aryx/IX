(* Bsp: the level's tree walked front to back, what the eye may see
 * made edges (Quake's r_bsp.c, R_RenderWorld, R_RecursiveWorldNode;
 * r_main.c, R_MarkLeaves).
 *
 * First the PVS, vis's work (Model.pvs): the leaves seen from the
 * eye's leaf, wherever in it the eye stands, are marked with the
 * frame's number, and so are their parents up to the root; the walk
 * goes only into marked nodes. In a level of rooms and corridors most
 * of the tree is cut there, before any test of the view:
 *
 *              root*                * marked: a leaf seen, or a node
 *             /     \                 above one
 *          n1*       n2             the walk never enters n2: nothing
 *         /   \     /  \            under it can be seen from here,
 *      leaf*  leaf leaf leaf        whatever the way the eye looks
 *
 * Then the walk (R_RecursiveWorldNode): at each node, its box against
 * the four planes of the view (a box wholly out is skipped, wholly in
 * one plane needs no clipping by it: clipflags); the side of its plane
 * the eye is on first, then the node's faces that look at the eye,
 * then the other side. A leaf reached marks its faces (they may be
 * drawn, from the node they lie on) and takes the next key. So the
 * faces come front to back, each with a key larger than any in front
 * of it: Scan sorts by that.
 *
 * A face facing away (the eye behind its plane) is not drawn: a
 * level's faces are one-sided, the inside of the rock never seen.
 *
 * history:
 * Doom walked its 2D tree front to back (mini-doom's Bsp); Quake's is
 * of 3D space, and the PVS is what is new (Seth Teller's thesis,
 * Berkeley 1992, on visibility in architectural models; Carmack's vis
 * computed it over the portals between the leaves). Abrash, Black
 * Book chapters 59-64.
 *
 * Where it stands in mini-quake: Render's frame calls mark_leaves, then
 * render_world, then render_bmodels, then Scan. *)

(* [mark_leaves v m leaf]: the PVS of the eye's leaf marked
 * (v.visframecount) *)
val mark_leaves : View.t -> Model.t -> Model.leaf -> unit

(* [render_world e v m]: the world's visible faces made edges *)
val render_world : Edges.t -> View.t -> Model.t -> unit

(* [render_bmodels e v m entities]: the brush models (doors, lifts),
 * each (number, its model, its origin), made edges with the key of
 * the leaf they are in (R_DrawBEntitiesOnList) *)
val render_bmodels :
  Edges.t -> View.t -> Model.t -> (int * int * Model.vec) list -> unit

(* the leaves marked in the last mark_leaves (the PVS's count) *)
val marked : int ref
