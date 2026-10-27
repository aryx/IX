(* Alias: Quake's models, the monsters and items (an .mdl, "alias"
 * models: id's model.c Mod_LoadAliasModel, r_alias.c, d_polyse.c,
 * r_light.c's R_LightPoint).
 *
 * The world is drawn without a z-buffer (Scan sorts its spans), but
 * the things that move cannot be in the BSP. So the world's spans
 * write 1/z of each pixel as they draw it (D_DrawZSpans), and the
 * models are drawn after, a triangle at a time, each pixel kept only
 * where it is nearer than what is there:
 *
 *    the world's spans: the picture, and 1/z at each pixel
 *    a model's triangles: s, t, light and 1/z interpolated across;
 *    a pixel drawn if its 1/z >= the buffer's (nearer), and the
 *    buffer then its own (so the model's triangles hide each other)
 *
 * The mapping is affine, not perspective (no division a pixel): a
 * model's triangles are small on the screen, the error not seen; the
 * world's large faces needed the division every 8 pixels (Spans).
 *
 * A model is a skin (a picture, its front half and its back half, the
 * vertices on the seam taking the back half's texels when their
 * triangle faces back), triangles over vertices given as bytes in a
 * box scaled to the model's size, and frames: the vertices again for
 * each pose (a monster's stand1 to stand8). An animation is its frames
 * one after the other, ten a second, no in-between.
 *
 * A model is lit by the world's lightmap where it stands: the light of
 * the face under its origin (R_LightPoint: a ray straight down, the
 * lightmap's sample where it hits), plus a light from one direction
 * shading the vertices whose normals look away from it. id's vertex
 * normals were indices into a table of 162 directions; here each
 * frame's normals are computed from its triangles (the average of the
 * faces around a vertex): no table copied.
 *
 * Where it stands in mini-quake: Things lists the level's models;
 * Render draws them after the world, each with the z-buffer. *)

(* a pose: its vertices' x y z, bytes, and their normals, x y z a
 * vertex, made when it is first drawn *)
type frame = { fname : string; verts : Bytes.t; mutable normals : float array }

type t = {
  scale : Model.vec;
  scale_origin : Model.vec;
  skinwidth : int;
  skinheight : int;
  (* each skin's picture (a group's first) *)
  skins : string array;
  (* a vertex's texel, and whether it is on the seam *)
  onseam : bool array;
  s : int array;
  t : int array;
  (* a triangle's three vertices, and whether it faces front *)
  tris : int array;
  facesfront : bool array;
  (* (a frame group's frames, one after the other) *)
  frames : frame array;
  (* the model's flags: 8 rotates (EF_ROTATE: the items) *)
  flags : int;
}

(* [load bytes]: an .mdl's model; Failure if it is none *)
val load : string -> t

(* [frames_named m prefix]: the frames whose name starts with prefix
 * (stand: stand1 ...) *)
val frames_named : t -> string -> int list

(* [light_point m v p]: the world's light under p, 0 to 255 x 2
 * (R_LightPoint) *)
val light_point : Model.t -> View.t -> Model.vec -> int

(* the triangles' values by their steps along x and y, computed once a
 * triangle (id's D_PolysetCalcGradients); false: along each row's
 * edges, the first way (mini-quake's models=simple) *)
val gradients : bool ref

(* [draw v m model origin yaw frame skin light]: the model's triangles
 * into v.screen, against v.zbuffer *)
val draw : View.t -> t -> Model.vec -> float -> int -> int -> int -> unit

(* [draw_pitched v m origin pitch yaw frame skin light]: the same,
 * turned up or down too (a rocket's flight, the weapon in hand) *)
val draw_pitched :
  View.t -> t -> Model.vec -> float -> float -> int -> int -> int -> unit
