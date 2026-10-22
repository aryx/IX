(* Spans: the surfaces' spans drawn (Quake's d_edge.c, D_DrawSurfaces;
 * d_scan.c, D_DrawSpans8 and Turbulent8; d_sky.c; r_sky.c).
 *
 * A span is a run of pixels of one surface on a scanline. Its texture
 * (the surface cache's, Surfcache) is mapped with perspective: s and t
 * are not linear on the screen, but s/z, t/z and 1/z are
 * (D_CalcGradients makes their planes from the face's texinfo and the
 * eye). A true s and t need a division, z = 1/(1/z); Quake divides
 * every 8 pixels and steps linearly between (the assembly's 16, the
 * divide of the next 16 running on the Pentium's FPU while its integer
 * unit drew these: Abrash's chapter 70):
 *
 *   pixels:  |0 . . . . . . 7|8 . . . . . 15|16 ...
 *   exact:    ^ s, t          ^ s, t          ^      (a division)
 *   between:    s += sstep, t += tstep: 16.16 integers
 *
 * The error between is small enough not to be seen; an affine map
 * across the whole span, as the PlayStation's, wobbles.
 *
 * Water, slime and lava (textures named *...) are not lit nor cached:
 * the texture itself, its s and t pushed by a sine of the other and of
 * the time (D_DrawTurbulent8Span): the liquids' swirl.
 *
 * The sky is no face's texture either: two layers of 128 by 128, the
 * clouds with holes scrolling over the back at another speed, seen in
 * the direction of each pixel (D_Sky_uv_To_st), squashed vertically:
 * a dome far away, the same wherever the eye stands.
 *
 * Where it stands in mini-quake: Scan calls [draw] when its spans'
 * table is full and at the end of a frame. *)

type t

(* [create m]: for the level's sky texture *)
val create : Model.t -> t

(* [draw sp e v m cache origins frames]: every surface's spans drawn
 * into v.screen; origins.(k) and frames.(k) entity k's (0 the world) *)
val draw :
  t ->
  Edges.t ->
  View.t ->
  Model.t ->
  Surfcache.t ->
  Model.vec array ->
  int array ->
  unit
