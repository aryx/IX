(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Planes.mli *)

(* a new visplane of this frame, its columns none *)
let new_plane (r : View.t) (height : float) (pic : int) (light : int) : View.plane =
  if r.nplanes = Array.length r.planes then
    r.planes <-
      Array.append r.planes
        (Array.init (max 16 r.nplanes) (fun (_ : int) ->
             ({ pheight = 0.; pic = 0; plight = 0; minx = 0; maxx = 0; top = Array.make (r.width + 2) View.unset; bottom = Array.make (r.width + 2) 0 } : View.plane)));
  let p = r.planes.(r.nplanes) in
  r.nplanes <- r.nplanes + 1;
  p.pheight <- height;
  p.pic <- pic;
  p.plight <- light;
  p.minx <- r.width;
  p.maxx <- -1;
  Array.fill p.top 0 (r.width + 2) View.unset;
  p

(* R_FindPlane: this frame's plane of that height, flat and light, or a
 * new one (the sky's height and light are none: one plane for it) *)
let find_plane (r : View.t) (textures : Textures.t) (height : float) (pic : int) (light : int) : View.plane =
  let height, light = if pic = textures.sky_flat then (0., 0) else (height, light) in
  let rec look (k : int) : View.plane option =
    if k >= r.nplanes then None
    else
      let p = r.planes.(k) in
      if p.pheight = height && p.pic = pic && p.plight = light then Some p else look (k + 1) in
  match look 0 with Some p -> p | None -> new_plane r height pic light

(* R_CheckPlane: the plane, to mark columns start to stop in; another of
 * the same kind when some of those are marked already *)
let check_plane (r : View.t) (p : View.plane) (start : int) (stop : int) : View.plane =
  let intrl = max start p.minx and intrh = min stop p.maxx in
  let x = ref intrl in
  while !x <= intrh && p.top.(!x + 1) = View.unset do incr x done;
  if !x > intrh then begin
    p.minx <- min start p.minx;
    p.maxx <- max stop p.maxx;
    p
  end
  else begin
    let q = new_plane r p.pheight p.pic p.plight in
    q.minx <- start;
    q.maxx <- stop;
    q
  end

(* R_MapPlane: row y from x1 to x2 of a flat at [height] from the eye *)
let map_plane (r : View.t) (height : float) (flat : Bytes.t) (colormaps : Bytes.t) (zlight : int array) (y : int) (x1 : int) (x2 : int) : unit =
  let distance = height *. r.yslope.(y) in
  (* basexscale, baseyscale: a pixel's step along the row, the view's
   * right; the flat's y is the map's upside down *)
  let right = r.viewangle -. View.half_pi in
  let xstep = distance *. View.fcos right /. r.centerx and ystep = -.distance *. View.fsin right /. r.centerx in
  let length = distance *. r.distscale.(x1) in
  let angle = r.viewangle +. r.xtoviewangle.(x1) in
  let xf = r.viewx +. (View.fcos angle *. length) and yf = -.r.viewy -. (View.fsin angle *. length) in
  (* (modulo 64, the flat's size, so that 16.16 holds them) *)
  let xf = xf -. (64. *. floor (xf /. 64.)) and yf = yf -. (64. *. floor (yf /. 64.)) in
  let xfrac = ref (int_of_float (xf *. 65536.)) and yfrac = ref (int_of_float (yf *. 65536.)) in
  let dx = int_of_float (xstep *. 65536.) and dy = int_of_float (ystep *. 65536.) in
  let cmap = zlight.(max 0 (min (View.maxlightz - 1) (int_of_float (distance /. 16.)))) in
  let screen = r.screen in
  let ofs = ref ((y * r.width) + x1) in
  (* R_DrawSpan *)
  for _n = x1 to x2 do
    let spot = ((!yfrac asr 10) land 4032) + ((!xfrac asr 16) land 63) in
    Bytes.unsafe_set screen !ofs (Bytes.unsafe_get colormaps (cmap + Char.code (Bytes.unsafe_get flat spot)));
    xfrac := !xfrac + dx;
    yfrac := !yfrac + dy;
    incr ofs
  done

(* R_MakeSpans: column x's rows t2 to b2, where the column before had t1
 * to b1: the rows that end are drawn, the rows that start are noted *)
let make_spans (r : View.t) (draw : int -> int -> int -> unit) (x : int) (t1 : int) (b1 : int) (t2 : int) (b2 : int) : unit =
  let t1 = ref t1 and b1 = ref b1 and t2 = ref t2 and b2 = ref b2 in
  while !t1 < !t2 && !t1 <= !b1 do draw !t1 r.spanstart.(!t1) (x - 1); incr t1 done;
  while !b1 > !b2 && !b1 >= !t1 do draw !b1 r.spanstart.(!b1) (x - 1); decr b1 done;
  while !t2 < !t1 && !t2 <= !b2 do r.spanstart.(!t2) <- x; incr t2 done;
  while !b2 > !b1 && !b2 >= !t2 do r.spanstart.(!b2) <- x; decr b2 done

(* R_DrawPlanes *)
let draw_planes (r : View.t) (textures : Textures.t) : unit =
  let colormaps = textures.colormaps in
  for k = 0 to r.nplanes - 1 do
    let p = r.planes.(k) in
    if p.minx <= p.maxx then begin
      if p.pic = textures.sky_flat then begin
        (* R_DrawSky: a column of the sky by the ray's angle, 1024 columns
         * a turn (ANGLETOSKYSHIFT), its row 100 at the view's middle,
         * as tall as at 320 wide, the brightest colormap *)
        let sky = textures.textures.(textures.texture_translation.(textures.sky)) in
        let scale = float r.width /. 320. in
        for x = p.minx to p.maxx do
          let a = View.norm (r.viewangle +. r.xtoviewangle.(x)) in
          let col = int_of_float (a *. 1024. /. View.two_pi) land sky.width_mask in
          View.draw_column r x p.top.(x + 1) p.bottom.(x + 1) 100. scale sky.source sky.columns.(col) colormaps 0
        done
      end
      else begin
        let flat = textures.flats.(textures.flat_translation.(p.pic)) in
        let height = Float.abs (p.pheight -. r.viewz) in
        let zlight = r.zlight.(View.lit r p.plight) in
        let draw = map_plane r height flat colormaps zlight in
        p.top.(p.maxx + 2) <- View.unset;
        p.top.(p.minx) <- View.unset;
        for x = p.minx to p.maxx + 1 do
          make_spans r draw x p.top.(x) p.bottom.(x) p.top.(x + 1) p.bottom.(x + 1)
        done
      end
    end
  done
