(* Segs: a seg's columns drawn (Doom's r_segs.c), the walls.
 *
 * The seg's scale (1 / distance, times the projection) at its first
 * and last columns (R_ScaleFromGlobalAngle), stepped linearly between
 * (1 / z is linear across the screen); in each column, from the
 * ceiling down:
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
 * A one-sided seg (a wall) draws its middle texture and closes the
 * column; a two-sided one draws its upper and lower textures and
 * narrows the clips, through which what is behind is seen. The
 * texture's column at x is the seg's offset less the tangent of the
 * ray's angle to the seg's normal times its distance; its rows are
 * pegged to the ceiling or the floor by the line's flags; its light is
 * the sector's, darker with the distance, a level less along x and
 * more along y (the "fake contrast").
 *
 * Each seg leaves a drawseg: its columns, scales, the clips as they
 * were, what of the things behind it it hides (its silhouette), and a
 * two-sided line's middle texture's columns, drawn last (Sprites).
 *
 * Where it stands in mini-doom: Render's walk of the tree calls it for
 * each run of open columns a seg covers. *)

(* [store_wall_range r textures level planes seg angle1 start stop]
 * (R_StoreWallRange): the seg's columns start to stop; [angle1] its
 * first end's angle from the eye *)
val store_wall_range : View.t -> Textures.t -> Level.t -> View.planes -> Level.seg -> float -> int -> int -> unit
