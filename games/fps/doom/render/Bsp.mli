(* Bsp: the tree walked, nearest first, and the columns it closes
 * (Doom's r_bsp.c). The tree is not made here: the node builder made
 * it from the map (idbsp then, ZDBSP or Freedoom's now) and the WAD
 * has it (Level: NODES, SSECTORS, SEGS).
 *
 * A node is a line that splits the level in two, each side a box and
 * a child: another node, or a subsector, a convex piece whose segs
 * cannot hide one another. From the eye, the side it is on first:
 *
 *     the map, from above              the tree
 *                   A                         A
 *          1        |      3                /   \
 *     -------B------|                      B     3
 *          2   e    |                     / \
 *                   |                    1   2
 *
 *   the eye e is left of A and below B: 2 first, then 1 (B's far
 *   side), then 3 (A's), each far side only if its box shows in a
 *   column still open (R_CheckBBox)
 *
 * So the segs come nearest first, and a column is done as soon as a
 * wall covers it: nothing behind is drawn there. Doom draws each pixel
 * of the walls once, with no z-buffer; the floors and the things are
 * drawn after, in what the walls left (Planes, Sprites).
 *
 * The columns closed are solidsegs, ranges of them, sorted, merged
 * when they touch: a wall's columns are drawn in the gaps between the
 * ranges, then added to them (R_ClipSolidWallSegment); a window's or a
 * step's are drawn in the gaps, and close nothing
 * (R_ClipPassWallSegment):
 *
 *   before   [0..40]          [120..200]          [290..319]
 *   a wall          60..250
 *   drawn              ^ 60..119       ^ 201..250
 *   after    [0..40]  [60..250]                   [290..319]
 *
 * A box is seen if its columns are not all in one range; at the end
 * the ranges are one, 0 to the width, and no box is.
 *
 * history:
 * The BSP is Henry Fuchs, Zvi Kedem and Bruce Naylor's ("On Visible
 * Surface Generation by A Priori Tree Structures", SIGGRAPH 1980), for
 * drawing back to front; John Carmack walked it front to back for
 * Doom (1993), with the closed columns, after Wolfenstein 3D's rays.
 * Fabien Sanglard's Game Engine Black Book: DOOM (2018) tells it, with
 * id's code: its renderer's chapter is this module and Segs.
 *
 * Where it stands in mini-doom: Render's frame starts the walk at the
 * root; a seg in view goes to Segs (its columns), a subsector's
 * things to Sprites, its floor and ceiling to Planes. *)

(* [render_node r textures level sprites things tic child]: the subtree
 * drawn (R_RenderBSPNode), its things by their sectors' numbers *)
val render_node :
  View.t -> Textures.t -> Level.t -> Things.sprites -> Things.mobj list array -> int -> Level.child -> unit
