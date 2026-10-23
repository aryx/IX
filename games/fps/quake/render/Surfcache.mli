(* Surfcache: a face's texture lit, made once and kept (Quake's
 * r_surf.c, d_surf.c, r_light.c's R_AnimateLight): the trick that
 * made a lightmap free at each pixel.
 *
 * A face's lightmap has a sample every 16 texels (light, tools/Light.ml
 * made them); texture times light, computed at each pixel while
 * drawing, was too slow for a Pentium. So before a face is drawn, its
 * surface is made: the texture tiled over the face's extents, each
 * texel through the colormap's row for its light, the light
 * interpolated across each 16 by 16 block between the four samples at
 * its corners (R_DrawSurfaceBlock8):
 *
 *        sample            sample          a texel's light is the
 *          a ------------- b               samples' bilinear mix;
 *          |  . . . . . .  |               light 0 to 63 is the
 *          |  . texel  . . |               colormap's row: the
 *          |  . . . . . .  |               texel's colour as lit is
 *          c ------------- d               colormap[row * 256 + texel]
 *
 * The surface is then a texture of its own, the face drawn with it as
 * any texture (Spans), and it is kept: the next frames draw the same
 * bytes. It is made again only when what made it changed: the texture
 * (an animation's frame), or the value of one of its light styles (a
 * flickering light: only the faces it reaches are remade).
 *
 * A surface is made at the mip level the face is seen at (1/z of its
 * nearest point): far faces are half, a quarter, an eighth of the
 * size, from the texture's smaller mips, and so are their lightmaps'
 * blocks (8, 4, 2 texels). The light is the samples' sum, each times
 * its style's value (256 the light as baked), then 255 x 256 less it,
 * shifted to a row of the colormap (R_BuildLightMap): bright is row 0.
 *
 * The cache: id's was a ring of blocks in a memory of fixed size, the
 * oldest surfaces made again when it wrapped around (D_SCAlloc). Here
 * each face's mip is an entry, and the oldest entries are dropped
 * when their bytes pass a budget (a megabyte): the same order of
 * eviction, without the ring's arithmetic.
 *
 * history:
 * Carmack's idea for Quake (1996), told by Abrash in the Black Book's
 * chapter 68 ("Quake's Lighting Model"), the one that answers why a
 * lightmap rather than Gouraud's shading: the shadows are sharp and
 * cost nothing at drawing. Hardware's multitexturing (GLQuake, 1997;
 * the Voodoo 2's two units) drew texture times lightmap at each pixel
 * at last, and the surface cache went. *)

type t
type surface = { data : Bytes.t; width : int }

(* [create ()] *)
val create : unit -> t

(* [surface c v m face mip frame]: the face lit at that mip (0 to 3),
 * made or kept; frame: the entity's (1: a brush model's other set of
 * animations, a button pressed) *)
val surface : t -> View.t -> Model.t -> Model.surface -> int -> int -> surface

(* [animation texture time frame]: the frame of an animated texture at
 * that time (R_TextureAnimation) *)
val animation : Model.texture -> float -> int -> Model.texture

(* [made c]: how many surfaces were made since the start (a frame's
 * count: the difference) *)
val made : t -> int

(* the lightmaps alone: every texture a mid grey (the flag lightmaps) *)
val grey : bool ref
