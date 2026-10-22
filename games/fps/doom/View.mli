(* View: the renderer's state and what all its parts share (Doom's
 * r_main.c, r_draw.c, r_defs.h, tables.c): the screen, the eye, the
 * tables, the clips of the columns, the visplanes, drawsegs and
 * vissprites of a frame, and R_DrawColumn, the loop every wall, sky
 * and sprite ends in.
 *
 * The tables (R_InitTextureMapping, R_InitLightTables, tables.c): a
 * turn is 8,192 fine angles and a sine or a tangent is the table's at
 * the fine angle's middle; the view's 90 degrees across the width are
 * a focal length of 159.76 at 320 wide (the table's tangent at 45
 * degrees is a bit more than 1); xtoviewangle is each column's left
 * edge's angle, viewangletox each fine angle's column. id's angles
 * are those quantized ones, and so are a texel's place and a light's
 * level: with the exact sine, a few pixels in every hundred are
 * another texel (Render.mli, plan_doom.md's table).
 *
 *   the light: a sector's 0-255 is 16 levels; level i starts at
 *   colormap (15 - i) * 4 and darkens
 *     scalelight.(i).(j): by a wall's scale (j = scale * 16), 48 of them
 *     zlight.(i).(j): by a flat's distance (j = distance / 16), 128
 *
 * Where it stands in mini-doom: Render makes one (create) and draws a
 * frame through Planes, Segs and Sprites, which all read and write it. *)

val pi : float
val two_pi : float
val half_pi : float

(* an angle in [0, 2 pi) (id's angles are unsigned, a turn 2^32), and
 * in [-pi, pi) *)
val norm : float -> float
val signed : float -> float

(* an angle's sine and cosine, the table's at its fine angle *)
val fsin : float -> float
val fcos : float -> float

(* the tangent of (an angle given plus 90 degrees) less 90 degrees:
 * finetangent[a >> ANGLETOFINESHIFT], a from 0 to 180 degrees *)
val ftan90 : float -> float

(* floor and ceiling, to ints *)
val ifloor : float -> int
val iceil : float -> int

(* the light's numbers (r_main.h) *)
val lightlevels : int
val maxlightscale : int
val maxlightz : int

(* a visplane (r_plane.c): a height, a flat and a light, and for each of
 * its columns the rows it shows, top to bottom (top > bottom: none).
 * Its arrays are a column more at each end (R_DrawPlanes reads them) *)
type plane = {
  mutable pheight : float;
  mutable pic : int;
  mutable plight : int;
  mutable minx : int;
  mutable maxx : int;
  top : int array;
  bottom : int array;
}

(* a visplane's column without rows; a masked column drawn *)
val unset : int

(* a drawseg (r_defs.h): a seg drawn, kept for the sprites and the
 * masked middle textures drawn after (R_DrawMasked): its columns and
 * scales, which of its sides hides what is behind (the silhouette: 1
 * below, 2 above, 3 both) and from which heights, the clips at that
 * moment (the value at column x is clip.(x - off)), and a masked
 * texture's columns *)
type drawseg = {
  dx1 : int;
  dx2 : int;
  dscale1 : float;
  dscale2 : float;
  dscalestep : float;
  mutable silhouette : int;
  mutable bsilheight : float;
  mutable tsilheight : float;
  mutable sprtopclip : int array;
  mutable sprtopoff : int;
  mutable sprbottomclip : int array;
  mutable sprbottomoff : int;
  maskedcol : int array; (* x - dx1: the texture's column, or unset once drawn; empty: none *)
  dseg : Level.seg;
}

(* a vissprite (r_defs.h): a thing projected, to draw after the walls *)
type vissprite = {
  vx1 : int;
  vx2 : int;
  gx : float;
  gy : float;
  gz : float;
  gzt : float;
  vscale : float;
  xiscale : float;
  texturemid : float;
  startfrac : float;
  patch : Bytes.t;
  vcmap : int;
}

type t = {
  width : int;
  height : int;
  centerx : float;
  centery : int;
  projection : float;
  (* a column's left edge's angle from the view's middle, and a fine
   * angle's column (R_InitTextureMapping) *)
  xtoviewangle : float array;
  viewangletox : int array;
  distscale : float array; (* 1 / cos of it *)
  yslope : float array; (* a row's distance for a plane 1 unit away *)
  scalelight : int array array; (* by level, by scale: a colormap's offset *)
  zlight : int array array; (* by level, by distance *)
  screen : Bytes.t;
  (* the columns closed: id's solidsegs, ranges first to last, sorted,
   * none touching another (Bsp) *)
  mutable solidsegs : (int * int) list;
  ceilingclip : int array;
  floorclip : int array;
  (* the visplanes: those of this frame are the first [nplanes] *)
  mutable planes : plane array;
  mutable nplanes : int;
  spanstart : int array;
  mutable drawsegs : drawseg list; (* the last drawn first *)
  mutable vissprites : vissprite list;
  mutable sector_seen : int array; (* a sector's things projected at this frame *)
  mutable frame_number : int;
  negonearray : int array;
  screenheightarray : int array;
  (* the eye *)
  mutable viewx : float;
  mutable viewy : float;
  mutable viewz : float;
  mutable viewangle : float;
  mutable segs : int;
}

(* what a subsector's segs are drawn with: its sector's planes, if they
 * can be seen (R_Subsector) *)
type planes = { mutable floorplane : plane option; mutable ceilingplane : plane option }

(* [create width height]: a renderer of that picture, its tables *)
val create : int -> int -> t

(* a sector's light level, 0 to 15 *)
val light_level : int -> int

(* the view's half angle: an angle past it from the view's middle is
 * not seen *)
val clipangle : t -> float

(* an angle from the view's middle (within the view's) to a column:
 * the first column whose left edge is to its right (viewangletox) *)
val x_of_angle : t -> float -> int

(* R_PointToAngle: a point's angle from the eye (2,048 slopes an
 * octant, as id's tantoangle); R_PointToDist: its distance *)
val point_to_angle : t -> float -> float -> float
val point_to_dist : t -> float -> float -> float

(* [draw_column r x yl yh mid scale source base colormaps cmap]
 * (R_DrawColumn): rows yl to yh of column x, the pixels at [base] in
 * [source] (a texture's column, a picture's post) from [mid] (its row
 * at the view's height) a step of 1 / scale, through the colormap at
 * [cmap]; its row & 127, as id's *)
val draw_column : t -> int -> int -> int -> float -> float -> Bytes.t -> int -> Bytes.t -> int -> unit
