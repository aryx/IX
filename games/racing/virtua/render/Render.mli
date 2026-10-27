(* Render: the meshes drawn as a picture of a byte a pixel, each face
 * flat, with a depth for each pixel: how a polygon game drew without a
 * 3D processor.
 *
 * A frame, for each mesh the game gives:
 *
 *   1. cull: the sphere around the mesh (Mesh) outside the view's
 *      pyramid, or beyond its far plane: nothing of it is drawn;
 *   2. turn: its corners to the eye's coordinates (Camera.view: x
 *      right, y up, z ahead), once each;
 *   3. for each face: cut by the near plane where it crosses it
 *      (Sutherland and Hodgman: a corner behind the eye has no place
 *      on the screen), then projected:
 *
 *           sx = width / 2 + s * x / z      s = the focal length in
 *           sy = height / 2 - s * y / z         pixels (Camera.focal
 *                                               times height / 2)
 *
 *   4. filled by spans, a row at a time, from its left edge to its
 *      right one: a span is one colour, and 1/z, which is linear on
 *      the screen for a flat face, a start and a step in whole
 *      numbers; a pixel is drawn where it is nearer than what is
 *      there, its depth kept:
 *
 *            row y:     . . . [####=====####] . . .
 *                              x0          x1
 *            1/z:              d, d + step, d + 2 step, ...
 *            a pixel:   if d >= depth.(i) then
 *                         (depth.(i) <- d; pixel.(i) <- colour)
 *
 * A pixel is the face's when its center is inside (the rows and
 * columns from ceil (edge - 0.5)): two faces that share an edge share
 * no pixel and leave none between them. A tie in depth goes to the
 * face drawn last: a road's line, drawn after its tarmac and in its
 * plane, is seen.
 *
 * Where it stands: the game (Virtua) gives the meshes near the eye
 * each frame, [frame] then [draw] for each, and shows [pixels] with
 * the course's Palette.
 *
 * Steps 1 to 3 are the front, 4 the back; a face goes from one to the
 * other in one place, the front's corners on the screen (sx, sy) and
 * 1/z handed to [fill]. The Pi 2's 3D processor takes faces so (its
 * vertices placed by the program: the "NV" state, plan_gpu.md): a
 * back of its own would replace [fill], the front the same
 * (plan_virtuaracing.md, decision 9). Keep the two apart.
 *
 * cs-history: the z-buffer is Edwin Catmull's (his thesis, Utah,
 * 1974); a memory the size of the screen was too dear for a game until
 * the 1990s, and the arcade's Model 1 (Virtua Racing, 1992) had one
 * among its processors. The PC's polygon games of the time sorted
 * their faces instead (the painter's algorithm): fewer instructions a
 * pixel, wrong where faces cross. Quake (1996) drew its world's spans
 * without one and wrote the depth for its models only (Spans,
 * Edges).
 *
 * What is ours: every face drawn whole, both its sides (the game's
 * cables, wheels and sails are seen from both; its sky from below):
 * the faces turned away are not dropped yet (plan_virtuaracing.md's
 * stage 2 measures). The depth is 1/z times 2^26, so the eye's near
 * plane at 0.1 fits a 31-bit integer (mini-ml's on arm). *)

type t

(* [create width height] *)
val create : int -> int -> t

val width : t -> int
val height : t -> int

(* the picture: a byte a pixel, the palette's index *)
val pixels : t -> Bytes.t

(* [frame r camera background]: a new frame seen by [camera], every
 * pixel [background] and as far as can be *)
val frame : t -> Camera.t -> int -> unit

(* [draw r m]: a mesh that does not move, its faces' shades its own *)
val draw : t -> Mesh.t -> unit

(* how the faces hidden by nearer ones are hidden: [Depth], a depth for
 * each pixel (the default), or [Painter], the painter's algorithm: the
 * frame's faces kept, sorted by their distance and drawn from the
 * farthest (mini-virtuaracing's render=painter) *)
type algorithm = Depth | Painter

val algorithm : algorithm ref

(* [finish r]: the frame drawn, before [pixels] is shown: the
 * painter's faces filled (nothing to do with the depth) *)
val finish : t -> unit

(* [draw_at r m angle position index]: a mesh turned [angle] degrees
 * about y (as Mesh.rotate3d 0. angle 0.), then moved to [position];
 * each face lit as it is then, [index] the palette's (Palette.index) *)
val draw_at : t -> Mesh.t -> float -> Vec3.t -> (Mesh.color -> float -> int) -> unit

(* a face turned away from the eye not drawn, unless it is seen from
 * both sides (Mesh.two_sided): true, unless mini-virtuaracing's
 * cull=off *)
val cull : bool ref

(* the faces drawn (or a part of them) since [frame] *)
val faces_drawn : t -> int
