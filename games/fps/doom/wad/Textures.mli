(* Textures: what a wall, a floor and the sky are painted with, and the
 * light (Doom's r_data.c, R_InitData). Every picture of Doom is the
 * palette's indices, a byte a pixel; its colours are PLAYPAL's 256, and
 * its light is COLORMAP's, 34 tables of 256 bytes: the colour an index
 * becomes at a light level, 0 the brightest, 31 nearly black.
 *
 *   PNAMES    the patches' names, numbered
 *   TEXTURE1  each texture: its size and its patches, each at an
 *             offset (a texture is put together of pictures, which
 *             the WAD stores once)
 *
 *     STARTAN3, 128 by 128         a patch is columns of posts (runs of
 *     +-------+-------+            opaque rows): made here a texture's
 *     | SW19_1| SW19_2|            column, a byte a row, the patches'
 *     |  0,0  | 64,0  |            posts copied into it in order
 *     +-------+-------+
 *
 *   flats     between F_START and F_END: 64 by 64 bytes, a floor's or
 *             a ceiling's picture, laid on the map's grid
 *
 * A texture's column is read as id's game read it, from memory laid
 * out as its was (R_GenerateLookup, R_GenerateComposite, R_GetColumn):
 * a column one patch covers is that patch's own bytes, from where its
 * first post's pixels start; the columns of more than one patch are put
 * together (composited), column after column; and a column's row is its
 * number & 127 (R_DrawColumn) wherever the texture ends. So a column
 * with a hole, or a texture not 128 high, shows what follows in
 * memory: the next posts' headers and pixels, the next column -- the
 * "tutti-frutti" and the "medusa" of Doom's levels, which the WADs of
 * the time were made to look right with, and a texture that does not
 * show them here would not be id's picture (a level's BROWNGRN, a lower
 * texture whose rows go past its patch, is green there, from the bytes
 * after). Past the last byte, zeros. id's one bug in compositing is
 * kept too: a patch above the texture's top (a negative offset) does
 * not lose its top rows but its bottom ones, the post starting at row 0
 * with its first pixel (R_DrawColumnInCache).
 *
 * id's game made a texture at its first use (the zone's cache); here
 * every texture is made at the start, a WAD's few being small.
 *
 * Where it stands in mini-doom: Level asks a name's number; Render reads
 * the columns, the flats and the colormaps; Play animates (the
 * translation of an animated texture or flat to its current frame,
 * P_UpdateSpecials) and turns switches. *)

type texture = {
  name : string;
  width : int;
  height : int;
  (* the largest power of 2 that is not wider: a column's number wraps
   * at it (Doom's texturewidthmask) *)
  width_mask : int;
  (* its bytes, and where each column's rows start in them *)
  source : Bytes.t;
  columns : int array;
}

type t = {
  palette : int array; (* each index's colour: red lsl 16, green lsl 8, blue *)
  colormaps : Bytes.t; (* 34 * 256 *)
  textures : texture array;
  flats : Bytes.t array; (* 4096 each *)
  flat_names : string array;
  (* what Render draws for a texture's or a flat's number: its frame
   * when it is animated, else itself *)
  texture_translation : int array;
  flat_translation : int array;
  sky_flat : int; (* F_SKY1: a ceiling that shows the sky *)
  sky : int; (* the sky's texture, SKY1 *)
  numbers : (string, int) Hashtbl.t;
}

(* [load wad]: the WAD's textures, flats and palette; Failure if it has
 * no PLAYPAL, COLORMAP or TEXTURE1 *)
val load : Wad.t -> t

(* a texture's number by its name, -1 if none *)
val texture : t -> string -> int

(* a flat's number by its name, -1 if none *)
val flat : t -> string -> int

(* [animate t tic]: the animated textures and flats at that tic (35 a
 * second), each frame 8 tics *)
val animate : t -> int -> unit

(* a switch's other texture (SW1... and SW2...), if there is one *)
val switch_of : t -> int -> int option
