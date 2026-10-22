(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See View.mli *)

let pi = 4. *. atan 1.
let two_pi = 2. *. pi
let half_pi = pi /. 2.

(* an angle in [0, 2 pi): id's angles are unsigned, a turn 2^32 *)
let norm (a : float) : float = if a >= 0. && a < two_pi then a else a -. (two_pi *. floor (a /. two_pi))

(* the same in [-pi, pi) *)
let signed (a : float) : float = let a = norm a in if a >= pi then a -. two_pi else a

(* id's tables (tables.c): a turn is 8192 fine angles, an angle's sine
 * and tangent the table's at its fine angle's middle; angles are
 * quantized there, which is where a texel lands (floats with the exact
 * sine put a few in every hundred pixels a texel apart) *)
let fineangles = 8192
let finestep = two_pi /. float fineangles
let finesine = Array.init (fineangles + (fineangles / 4)) (fun (i : int) -> sin ((float i +. 0.5) *. finestep))
let finetangent = Array.init (fineangles / 2) (fun (i : int) -> tan ((float (i - (fineangles / 4)) +. 0.5) *. finestep))

(* an angle's fine angle (angle >> ANGLETOFINESHIFT) *)
let fine (a : float) : int = int_of_float (norm a /. finestep) land (fineangles - 1)
let fsin (a : float) : float = finesine.(fine a)
let fcos (a : float) : float = finesine.(fine a + (fineangles / 4))

(* the tangent of an angle given plus 90 degrees (finetangent[(a +
 * ANG90) >> ANGLETOFINESHIFT]: a in -90 to 90) *)
let ftan90 (a : float) : float = finetangent.(min (fineangles / 2 - 1) (fine a))

let ifloor (v : float) : int = let i = int_of_float v in if float i > v then i - 1 else i
let iceil (v : float) : int = let i = int_of_float v in if float i < v then i + 1 else i

(* the light's constants (r_main.h) *)
let lightlevels = 16
let numcolormaps = 32
let maxlightscale = 48
let maxlightz = 128

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

let unset = 0x7fff

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
  (* the columns closed (id's solidsegs), and how many are open *)
  solid : int array;
  mutable open_columns : int;
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

(*****************************************************************************)
(* The tables *)
(*****************************************************************************)

let create (width : int) (height : int) : t =
  let centerx = float (width / 2) and centery = height / 2 in
  let projection = centerx in
  (* (the view's 90 degrees across the width: its edges' tangent is
   * the table's, a bit more than 1, so the focal length a bit less
   * than half the width) *)
  let focallength = centerx /. finetangent.((fineangles / 4) + (fineangles / 8)) in
  let viewangletox =
    Array.init (fineangles / 2) (fun (i : int) ->
        let t = finetangent.(i) in
        if t > 2. then -1 else if t < -2. then width + 1 else max (-1) (min (width + 1) (iceil (centerx -. (t *. focallength))))) in
  let xtoviewangle =
    Array.init (width + 1) (fun (x : int) ->
        let i = ref 0 in
        while viewangletox.(!i) > x do incr i done;
        (float !i *. finestep) -. half_pi) in
  let viewangletox = Array.map (fun (x : int) -> max 0 (min width x)) viewangletox in
  (* R_InitLightTables, R_ExecuteSetViewSize: a level's first colormap,
   * then darker by the distance; the scale's steps as a 320 wide
   * screen's *)
  let startmap (i : int) : int = (lightlevels - 1 - i) * 2 * numcolormaps / lightlevels in
  let clampmap (l : int) : int = 256 * max 0 (min (numcolormaps - 1) l) in
  { width; height; centerx; centery; projection; xtoviewangle; viewangletox;
    distscale = Array.map (fun (a : float) -> 1. /. Float.abs (fcos a)) xtoviewangle;
    yslope = Array.init height (fun (y : int) -> (float width /. 2.) /. Float.abs (float (y - centery) +. 0.5));
    scalelight = Array.init lightlevels (fun (i : int) -> Array.init maxlightscale (fun (j : int) -> clampmap (startmap i - (j / 2))));
    zlight =
      Array.init lightlevels (fun (i : int) ->
          Array.init maxlightz (fun (j : int) -> clampmap (startmap i - ((655360 / (j + 1)) lsr 12 / 2))));
    screen = Bytes.make (width * height) '\000';
    solid = Array.make width 0; open_columns = width;
    ceilingclip = Array.make width (-1); floorclip = Array.make width height;
    planes = [||]; nplanes = 0; spanstart = Array.make height 0;
    drawsegs = []; vissprites = []; sector_seen = [||]; frame_number = 0;
    negonearray = Array.make width (-1); screenheightarray = Array.make width height;
    viewx = 0.; viewy = 0.; viewz = 0.; viewangle = 0.; segs = 0 }

(* a sector's light level, 0 to 15 *)
let light_level (light : int) : int = max 0 (min (lightlevels - 1) (light asr 4))

let clipangle (r : t) : float = r.xtoviewangle.(0)

(* an angle from the view's middle (within the view's) to a column:
 * the first column whose left edge is to its right (viewangletox) *)
let x_of_angle (r : t) (a : float) : int = r.viewangletox.(min (fineangles / 2 - 1) (fine (a +. half_pi)))

(* R_PointToAngle: a point's angle from the eye by its octant and the
 * slope in it, 2048 slopes an octant (SlopeDiv: truncated, as its
 * integers are; tantoangle: their angles) *)
let slope_div (num : float) (den : float) : float =
  let d = floor (den *. 256.) in
  if d < 2. then 2048. else Float.min 2048. (floor (num *. 524288. /. d))

let tantoangle (slope : float) : float = atan (slope /. 2048.)

let point_to_angle (r : t) (x : float) (y : float) : float =
  let x = x -. r.viewx and y = y -. r.viewy in
  if x = 0. && y = 0. then 0.
  else
    let a =
      if x >= 0. then
        if y >= 0. then (if x > y then tantoangle (slope_div y x) else half_pi -. tantoangle (slope_div x y))
        else
          let y = -.y in
          if x > y then -.tantoangle (slope_div y x) else (3. *. half_pi) +. tantoangle (slope_div x y)
      else
        let x = -.x in
        if y >= 0. then (if x > y then pi -. tantoangle (slope_div y x) else half_pi +. tantoangle (slope_div x y))
        else
          let y = -.y in
          if x > y then pi +. tantoangle (slope_div y x) else (3. *. half_pi) -. tantoangle (slope_div x y) in
    norm a

(* R_PointToDist: the larger side over the sine of the angle the slope
 * says *)
let point_to_dist (r : t) (x : float) (y : float) : float =
  let dx = Float.abs (x -. r.viewx) and dy = Float.abs (y -. r.viewy) in
  let dx, dy = if dy > dx then (dy, dx) else (dx, dy) in
  if dx = 0. then 0. else dx /. fsin (tantoangle (Float.min 2048. (floor (dy /. dx *. 2048.))) +. half_pi)

(*****************************************************************************)
(* The columns *)
(*****************************************************************************)

(* R_DrawColumn: rows yl to yh of column x, a column of pixels at [base]
 * in [source] (a texture's, a picture's post) from [mid] (its row at
 * the view's height) a step of 1 / scale, its pixels through the
 * colormap at [cmap]; its row & 127, as id's *)
let draw_column (r : t) (x : int) (yl : int) (yh : int) (mid : float) (scale : float) (source : Bytes.t) (base : int)
    (colormaps : Bytes.t) (cmap : int) : unit =
  if yl <= yh then begin
    let step = int_of_float (65536. /. scale) in
    let frac = ref (int_of_float (mid *. 65536.) + ((yl - r.centery) * step)) in
    let screen = r.screen and w = r.width in
    let ofs = ref ((yl * w) + x) in
    for _n = yl to yh do
      Bytes.unsafe_set screen !ofs (Bytes.unsafe_get colormaps (cmap + Char.code (Bytes.unsafe_get source (base + ((!frac asr 16) land 127)))));
      frac := !frac + step;
      ofs := !ofs + w
    done
  end

(* what a subsector's segs are drawn with: its sector's planes, if they
 * can be seen (R_Subsector) *)
type planes = { mutable floorplane : plane option; mutable ceilingplane : plane option }
