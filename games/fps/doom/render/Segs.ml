(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Segs.mli *)

(* R_StoreWallRange: the seg's columns start to stop, which are open;
 * [angle1] its first end's angle (rw_angle1) *)
let store_wall_range (r : View.t) (textures : Textures.t) (level : Level.t) (pl : View.planes) (seg : Level.seg) (angle1 : float) (start : int)
    (stop : int) : unit =
  r.segs <- r.segs + 1;
  let side = seg.side and line = level.lines.(seg.seg_line) and front = seg.front_sector in
  let normalangle = View.norm (seg.angle +. View.half_pi) in
  let offsetangle = Float.min View.half_pi (Float.abs (View.signed (normalangle -. angle1))) in
  let distangle = View.half_pi -. offsetangle in
  let hyp = View.point_to_dist r seg.sv1.x seg.sv1.y in
  let distance = hyp *. View.fsin distangle in
  (* R_ScaleFromGlobalAngle *)
  let scale_at (visangle : float) : float =
    let sinea = View.fsin (View.half_pi +. (visangle -. r.viewangle)) and sineb = View.fsin (View.half_pi +. (visangle -. normalangle)) in
    let num = r.projection *. sineb and den = distance *. sinea in
    if den > num /. 65536. then Float.max (1. /. 256.) (Float.min 64. (num /. den)) else 64. in
  let scale1 = scale_at (r.viewangle +. r.xtoviewangle.(start)) in
  let scalestep = if stop > start then (scale_at (r.viewangle +. r.xtoviewangle.(stop)) -. scale1) /. float (stop - start) else 0. in
  let worldtop0 = front.ceiling -. r.viewz and worldbottom = front.floor -. r.viewz in
  let theight (k : int) : float = if k < 0 then 0. else float textures.textures.(k).height in
  let midtexture = ref (-1) and toptexture = ref (-1) and bottomtexture = ref (-1) in
  let midmid = ref 0. and topmid = ref 0. and bottommid = ref 0. in
  let worldtop = ref worldtop0 and worldhigh = ref 0. and worldlow = ref 0. in
  let markfloor = ref true and markceiling = ref true in
  (match seg.back_sector with
  | None ->
      midtexture := side.middle;
      midmid := (if line.flags land Level.lower_unpegged <> 0 then front.floor +. theight side.middle -. r.viewz else worldtop0) +. side.yoffset
  | Some back ->
      worldhigh := back.ceiling -. r.viewz;
      worldlow := back.floor -. r.viewz;
      (* (a sky above both: no wall between, the sky goes on) *)
      if front.ceilingpic = textures.sky_flat && back.ceilingpic = textures.sky_flat then worldtop := !worldhigh;
      markfloor := !worldlow <> worldbottom || back.floorpic <> front.floorpic || back.light <> front.light;
      markceiling := !worldhigh <> !worldtop || back.ceilingpic <> front.ceilingpic || back.light <> front.light;
      (* (a door closed) *)
      if back.ceiling <= front.floor || back.floor >= front.ceiling then begin markceiling := true; markfloor := true end;
      if !worldhigh < !worldtop then begin
        toptexture := side.top;
        topmid := (if line.flags land Level.upper_unpegged <> 0 then !worldtop else back.ceiling +. theight side.top -. r.viewz) +. side.yoffset
      end;
      if !worldlow > worldbottom then begin
        bottomtexture := side.bottom;
        bottommid := (if line.flags land Level.lower_unpegged <> 0 then !worldtop else !worldlow) +. side.yoffset
      end);
  let worldtop = !worldtop and worldhigh = !worldhigh and worldlow = !worldlow in
  (* the drawseg: what this seg hides of the things behind it *)
  let masked = match seg.back_sector with Some _ -> side.middle >= 0 | None -> false in
  let ds : View.drawseg =
    { dx1 = start; dx2 = stop; dscale1 = scale1; dscale2 = scale1 +. (scalestep *. float (stop - start)); dscalestep = scalestep;
      silhouette = 0; bsilheight = 0.; tsilheight = 0.; sprtopclip = [||]; sprtopoff = 0; sprbottomclip = [||]; sprbottomoff = 0;
      maskedcol = (if masked then Array.make (stop - start + 1) View.unset else [||]); dseg = seg } in
  (match seg.back_sector with
  | None ->
      ds.silhouette <- 3;
      ds.sprtopclip <- r.screenheightarray;
      ds.sprbottomclip <- r.negonearray;
      ds.bsilheight <- infinity;
      ds.tsilheight <- neg_infinity
  | Some back ->
      if front.floor > back.floor then begin ds.silhouette <- 1; ds.bsilheight <- front.floor end
      else if back.floor > r.viewz then begin ds.silhouette <- 1; ds.bsilheight <- infinity end;
      if front.ceiling < back.ceiling then begin ds.silhouette <- ds.silhouette lor 2; ds.tsilheight <- front.ceiling end
      else if back.ceiling < r.viewz then begin ds.silhouette <- ds.silhouette lor 2; ds.tsilheight <- neg_infinity end;
      if back.ceiling <= front.floor then begin ds.sprbottomclip <- r.negonearray; ds.bsilheight <- infinity; ds.silhouette <- ds.silhouette lor 1 end;
      if back.floor >= front.ceiling then begin ds.sprtopclip <- r.screenheightarray; ds.tsilheight <- neg_infinity; ds.silhouette <- ds.silhouette lor 2 end);
  r.drawsegs <- ds :: r.drawsegs;
  (* the texture's first column, and the lights *)
  let rel = View.signed (normalangle -. angle1) in
  let offset = hyp *. View.fsin (Float.min View.half_pi (Float.abs rel)) in
  let offset = (if rel > 0. then -.offset else offset) +. side.xoffset +. seg.offset in
  let lightnum =
    View.light_level front.light + r.extralight + (if seg.sv1.y = seg.sv2.y then -1 else if seg.sv1.x = seg.sv2.x then 1 else 0) in
  let walllights = r.scalelight.(max 0 (min (View.lightlevels - 1) lightnum)) in
  (* (a plane on the eye's other side is not seen) *)
  if front.floor >= r.viewz then markfloor := false;
  if front.ceiling <= r.viewz && front.ceilingpic <> textures.sky_flat then markceiling := false;
  let markfloor = !markfloor && pl.floorplane <> None and markceiling = !markceiling && pl.ceilingplane <> None in
  let cy = float r.centery in
  let topfrac = ref (cy -. (worldtop *. scale1)) and topstep = -.(scalestep *. worldtop) in
  let bottomfrac = ref (cy -. (worldbottom *. scale1)) and bottomstep = -.(scalestep *. worldbottom) in
  let pixhigh = ref (cy -. (worldhigh *. scale1)) and pixhighstep = -.(scalestep *. worldhigh) in
  let pixlow = ref (cy -. (worldlow *. scale1)) and pixlowstep = -.(scalestep *. worldlow) in
  let ceilingplane = match pl.ceilingplane with Some p when markceiling -> Some (Planes.check_plane r p start stop) | p -> p in
  let floorplane = match pl.floorplane with Some p when markfloor -> Some (Planes.check_plane r p start stop) | p -> p in
  pl.ceilingplane <- ceilingplane;
  pl.floorplane <- floorplane;
  let tex (k : int) : Textures.texture = textures.textures.(textures.texture_translation.(k)) in
  let colormaps = textures.colormaps in
  let lightscale = 16. *. 320. /. float r.width in
  let centerangle = View.half_pi +. r.viewangle -. normalangle in
  let scale = ref scale1 in
  let ceilingclip = r.ceilingclip and floorclip = r.floorclip in
  (* R_RenderSegLoop *)
  for x = start to stop do
    let yl = max (View.iceil !topfrac) (ceilingclip.(x) + 1) in
    (match ceilingplane with
    | Some p when markceiling ->
        let top = ceilingclip.(x) + 1 and bottom = min (yl - 1) (floorclip.(x) - 1) in
        if top <= bottom then begin p.top.(x + 1) <- top; p.bottom.(x + 1) <- bottom end
    | _ -> ());
    let yh = min (View.ifloor !bottomfrac) (floorclip.(x) - 1) in
    (match floorplane with
    | Some p when markfloor ->
        let top = max (yh + 1) (ceilingclip.(x) + 1) and bottom = floorclip.(x) - 1 in
        if top <= bottom then begin p.top.(x + 1) <- top; p.bottom.(x + 1) <- bottom end
    | _ -> ());
    let sc = !scale in
    let texturecolumn = View.ifloor (offset -. (View.ftan90 (centerangle +. r.xtoviewangle.(x)) *. distance)) in
    let column (t : Textures.texture) : int = texturecolumn land t.width_mask in
    if masked then ds.maskedcol.(x - start) <- texturecolumn;
    let cmap = walllights.(max 0 (min (View.maxlightscale - 1) (int_of_float (sc *. lightscale)))) in
    if !midtexture >= 0 then begin
      let t = tex !midtexture in
      View.draw_column r x yl yh !midmid sc t.source t.columns.(column t) colormaps cmap;
      ceilingclip.(x) <- r.height;
      floorclip.(x) <- -1
    end
    else begin
      if !toptexture >= 0 then begin
        let mid = min (View.ifloor !pixhigh) (floorclip.(x) - 1) in
        if mid >= yl then begin
          let t = tex !toptexture in
          View.draw_column r x yl mid !topmid sc t.source t.columns.(column t) colormaps cmap;
          ceilingclip.(x) <- mid
        end
        else ceilingclip.(x) <- yl - 1
      end
      else if markceiling then ceilingclip.(x) <- yl - 1;
      if !bottomtexture >= 0 then begin
        let mid = max (View.iceil !pixlow) (ceilingclip.(x) + 1) in
        if mid <= yh then begin
          let t = tex !bottomtexture in
          View.draw_column r x mid yh !bottommid sc t.source t.columns.(column t) colormaps cmap;
          floorclip.(x) <- mid
        end
        else floorclip.(x) <- yh + 1
      end
      else if markfloor then floorclip.(x) <- yh + 1
    end;
    scale := sc +. scalestep;
    topfrac := !topfrac +. topstep;
    bottomfrac := !bottomfrac +. bottomstep;
    pixhigh := !pixhigh +. pixhighstep;
    pixlow := !pixlow +. pixlowstep
  done;
  (* the clips as they are now, for the things behind *)
  if (ds.silhouette land 2 <> 0 || masked) && Array.length ds.sprtopclip = 0 then begin
    ds.sprtopclip <- Array.sub ceilingclip start (stop - start + 1);
    ds.sprtopoff <- start
  end;
  if (ds.silhouette land 1 <> 0 || masked) && Array.length ds.sprbottomclip = 0 then begin
    ds.sprbottomclip <- Array.sub floorclip start (stop - start + 1);
    ds.sprbottomoff <- start
  end;
  if masked && ds.silhouette land 2 = 0 then begin ds.silhouette <- ds.silhouette lor 2; ds.tsilheight <- neg_infinity end;
  if masked && ds.silhouette land 1 = 0 then begin ds.silhouette <- ds.silhouette lor 1; ds.bsilheight <- infinity end
