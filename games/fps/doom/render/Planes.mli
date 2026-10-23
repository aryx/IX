(* Planes: the floors and the ceilings (Doom's r_plane.c), and the sky.
 *
 * A wall drawn marks, column by column, the rows above it that are
 * its sector's ceiling and those below that are its floor, in a
 * visplane: a height, a flat and a light, and for each column a run of
 * rows. When the walls are done, each visplane is drawn by rows, not
 * columns (R_MakeSpans: a row's span ends where the next column's rows
 * no longer include it): along a row of the screen a flat is at one
 * distance, height * yslope, so its texels are a fixed step apart,
 * distance / projection a pixel (R_MapPlane, R_DrawSpan), the step
 * along the view's right, from the point the row's first column's ray
 * meets the plane:
 *
 *       the screen                the floor, from above
 *     +--------------+          eye  \    |    /
 *     |              |                 \   |   /   a row's span: the
 *     |   ........   | <- row y         \..|../    points where the
 *     |  ..........  |                 the floor   rays of its columns
 *     +--------------+                             meet the floor
 *
 * The sky is a visplane too, F_SKY1's: not a flat but the sky's
 * texture drawn as walls are, a column by the ray's angle (1,024
 * columns a turn: the texture of 256 four times), row 100 at the
 * view's middle, at full light (R_DrawSky in R_DrawPlanes).
 *
 * Where it stands in mini-doom: Render finds a subsector's planes,
 * Segs marks them, Render draws them after the walls. *)

(* R_FindPlane: this frame's plane of that height, flat and light, or a
 * new one (the sky's: one for all its heights and lights) *)
val find_plane : View.t -> Textures.t -> float -> int -> int -> View.plane

(* [check_plane r plane start stop] (R_CheckPlane): the plane, to mark
 * columns start to stop in; another of the same kind when some of them
 * are marked already *)
val check_plane : View.t -> View.plane -> int -> int -> View.plane

(* R_DrawPlanes: every visplane of the frame, by spans; the sky's by
 * columns *)
val draw_planes : View.t -> Textures.t -> unit
