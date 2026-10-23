(* Render: what the player sees, Doom's way (r_main.c, r_bsp.c,
 * r_segs.c, r_plane.c, r_draw.c, r_sky.c): a picture of the palette's
 * indices, a byte a pixel, 320 by 200, made column by column with no
 * polygon and no z-buffer.
 *
 * 1. The tree, nearest first (R_RenderBSPNode): at each node, the side
 *    the eye is on, then the other if its box can be seen at all
 *    (R_CheckBBox: its corners' angles within the view, and not in
 *    columns already closed). A subsector's segs come out in an order
 *    where nothing drawn later is in front of what is already there.
 *
 * 2. A seg (R_AddLine): its two ends' angles from the eye; seen from
 *    behind (more than half a turn between them) or out of the view's
 *    90 degrees, nothing; else the columns it covers, x1 to x2. A wall
 *    (one-sided, or a door closed) closes them; a seg between two
 *    sectors only narrows them, the next sector seen through it.
 *
 * 3. Its columns (R_StoreWallRange, R_RenderSegLoop), from the left,
 *    its scale (1 / distance: linear across the screen) stepped:
 *
 *        ceilingclip ---  .........   the ceiling's visplane: from the
 *                         |  top   |  clip down to the wall's top
 *            worldhigh -> |========|  an upper texture (the next
 *                         |        |  sector's ceiling is lower)
 *                         | (open) |  the next sector, drawn later
 *             worldlow -> |========|  a lower texture (a step)
 *                         | bottom |  the floor's visplane
 *          floorclip ---  .........
 *
 *    The texture's column at x is the seg's offset less the tangent of
 *    the ray's angle to the seg's normal times its distance; its rows
 *    are a step of 1 / scale texels a pixel (R_DrawColumn), through the
 *    colormap of its light.
 *
 * 4. The floors and ceilings (R_DrawPlanes): each wall marked, column
 *    by column, which rows of which visplane (a height, a flat, a
 *    light) show above and below it. A visplane's columns are then
 *    drawn as rows (R_MakeSpans): along a row of the screen a flat is
 *    at one distance, height * yslope, its texels a step of distance /
 *    projection a pixel (R_MapPlane, R_DrawSpan: Mode 7's idea). The
 *    sky is a texture by the view's angle, four times a turn, always
 *    bright.
 *
 * 5. The things and the see-through (R_DrawMasked, r_things.c): each
 *    seg drawn left a drawseg, its columns, its scales and the clips
 *    as they were; each thing in a sector the tree went through was
 *    projected (R_ProjectSprite: its picture's columns, its scale, the
 *    rotation seen). They are drawn farthest first, each clipped by the
 *    drawsegs nearer than it (their silhouettes: what is above a step's
 *    top, below a window's lintel); a two-sided line's middle texture
 *    (a grate, a platform's edge) is drawn the same way, its columns
 *    the posts of its patch, after the things behind it.
 *
 * 6. The light (R_InitLightTables): a sector's 0 to 255 is 16 levels;
 *    a wall's colormap is its level less its scale's half (48 steps), a
 *    flat's its level less 80 / distance's half (128 steps of 16 units);
 *    a wall along x a level darker, along y a level lighter (the "fake
 *    contrast" that shows the corners).
 *
 * What is id's and what is not: the order, the tables and the
 * formulas are r_*.c's, named in comments by their functions. Its
 * fixed point is 16.16 in 32 bits, which a map's coordinates overflow
 * on the Pi1's 31-bit ints: the geometry here is floats (a seg's
 * angles, its scale, a column's texture), the loops of pixels integers
 * (16.16 in a column, a flat's coordinates taken modulo 64 before). A
 * texture's height wraps where it is (id's wrapped at 128).
 * Not here: the player's weapon (psprites), the fuzz of a spectre, the
 * limits (MAXVISPLANES, MAXDRAWSEGS: none here).
 *
 * Its parts are id's files: View (r_main.c, r_draw.c: the state, the
 * tables, R_DrawColumn), Bsp (r_bsp.c: 1, 2), Segs (r_segs.c: 3),
 * Planes (r_plane.c: 4), Sprites (r_things.c: 5), and this one,
 * R_RenderView (r_main.c), the frame from the five.
 *
 * Where it stands in mini-doom: Doom.ml asks a frame of it with the
 * player's eye; Play's moves change what Level holds, which it draws as
 * it is.
 *
 * history:
 * The BSP is Henry Fuchs, Zvi Kedem and Bruce Naylor's ("On Visible
 * Surface Generation by A Priori Tree Structures", SIGGRAPH 1980);
 * John Carmack used it for Doom (1993) in its front-to-back order with
 * the clip arrays, after Wolfenstein 3D's raycaster. The playground's
 * TinyDoom (games/fps in ~/playground) draws the same order with
 * shapes and flat colours; ocamldoom (François Pessaux, 1997) with
 * textures, over its own BSP. *)

type t

(* [create width height]: a renderer of that picture (320 by 200 is
 * Doom's; any size, the view's 90 degrees across its width) *)
val create : int -> int -> t

(* the picture: width * height indices of the palette, row after row *)
val screen : t -> Bytes.t
val width : t -> int
val height : t -> int

(* [frame r level textures sprites things tic x y z angle]: the picture
 * of the eye at (x, y), height z, looking at angle (radians); the
 * things by their sectors' numbers, each at its frame of that tic *)
val frame : t -> Level.t -> Textures.t -> Things.sprites -> Things.mobj list array -> int -> float -> float -> float -> float -> unit

(* this frame's: the segs drawn, the visplanes *)
val segs_drawn : t -> int
val planes_drawn : t -> int

(* [set_extralight r n]: the next frames lit [n] levels more (a shot's
 * flash: Weapons' Light1, Light2) *)
val set_extralight : t -> int -> unit

(* [hand r textures sprites light psprites]: R_DrawPlayerSprites: the
 * weapon in hand and its flash, each a state and its place, over the
 * last frame, lit by [light] (the player's sector's) *)
val hand :
  t -> Textures.t -> Things.sprites -> int ->
  (Info.state * float * float) list -> unit
