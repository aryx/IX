(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sprites.mli *)

(* R_ProjectSprite: a thing's picture's columns and scale, if it can be
 * seen *)
let project_sprite (r : View.t) (sprites : Things.sprites) (tic : int) (m : Things.mobj) : unit =
  let tr_x = m.mx -. r.viewx and tr_y = m.my -. r.viewy in
  let viewcos = View.fcos r.viewangle and viewsin = View.fsin r.viewangle in
  let tz = (tr_x *. viewcos) +. (tr_y *. viewsin) in
  (* (behind the eye, or too near) *)
  if tz >= 4. then begin
    let xscale = r.projection /. tz in
    let tx = (tr_x *. viewsin) -. (tr_y *. viewcos) in
    if Float.abs tx <= 4. *. tz then
      match Things.frame sprites m tic with
      | None -> ()
      | Some (f, bright) ->
          (* (the rotation: the eye's angle to it less its own, in eighths
           * of a turn, the front's eighth centred on 0) *)
          let rot = if f.rotates then int_of_float (View.norm (View.point_to_angle r m.mx m.my -. m.mangle +. (9. *. View.pi /. 8.)) /. (View.pi /. 4.)) land 7 else 0 in
          let patch = f.lumps.(rot) and flip = f.flip.(rot) in
          if patch <> "" then begin
            let width = Wad.short patch 0 and left = Wad.short patch 4 and top = Wad.short patch 6 in
            let tx = tx -. float left in
            let x1 = View.ifloor (r.centerx +. (tx *. xscale)) in
            let x2 = View.ifloor (r.centerx +. ((tx +. float width) *. xscale)) - 1 in
            if x1 <= r.width && x2 >= 0 then begin
              let iscale = 1. /. xscale in
              let vx1 = max 0 x1 and vx2 = min (r.width - 1) x2 in
              let start, step = if flip then (float width -. (1. /. 65536.), -.iscale) else (0., iscale) in
              let lights = r.scalelight.(View.lit r m.sector.light) in
              r.vissprites <-
                ({ vx1; vx2; gx = m.mx; gy = m.my; gz = m.mz; gzt = m.mz +. float top; vscale = xscale; xiscale = step;
                  texturemid = m.mz +. float top -. r.viewz; startfrac = start +. (step *. float (vx1 - x1));
                  patch = Bytes.unsafe_of_string patch;
                  vcmap = (if bright then 0 else lights.(min (View.maxlightscale - 1) (int_of_float (xscale *. 16. *. 320. /. float r.width)))) }
                  : View.vissprite)
                :: r.vissprites
            end
          end
  end

(* R_DrawMaskedColumn: a picture's column, its posts from [ofs] in
 * [src], between the clips *)
let draw_masked_column (r : View.t) (x : int) (src : Bytes.t) (ofs : int) (texturemid : float) (scale : float) (colormaps : Bytes.t) (cmap : int)
    (ceiling : int) (floor : int) : unit =
  let cy = float r.centery in
  let sprtopscreen = cy -. (texturemid *. scale) in
  let i = ref ofs and n = Bytes.length src in
  while !i + 1 < n && Char.code (Bytes.get src !i) <> 0xff do
    let topdelta = Char.code (Bytes.get src !i) and length = Char.code (Bytes.get src (!i + 1)) in
    let topscreen = sprtopscreen +. (scale *. float topdelta) in
    let bottomscreen = topscreen +. (scale *. float length) in
    let yl = max (View.iceil topscreen) (ceiling + 1) and yh = min (View.iceil bottomscreen - 1) (floor - 1) in
    if yl <= yh && !i + 3 + length <= n then View.draw_column r x yl yh (texturemid -. float topdelta) scale src (!i + 3) colormaps cmap;
    i := !i + length + 4
  done

(* R_RenderMaskedSegRange: a two-sided line's middle texture, its
 * columns x1 to x2 not drawn yet *)
let render_masked_seg_range (r : View.t) (textures : Textures.t) (level : Level.t) (ds : View.drawseg) (x1 : int) (x2 : int) : unit =
  let seg = ds.dseg in
  match seg.back_sector with
  | None -> ()
  | Some back ->
      let front = seg.front_sector and line = level.lines.(seg.seg_line) in
      let tex = textures.textures.(textures.texture_translation.(seg.side.middle)) in
      let lightnum = View.light_level front.light + r.extralight + (if seg.sv1.y = seg.sv2.y then -1 else if seg.sv1.x = seg.sv2.x then 1 else 0) in
      let walllights = r.scalelight.(max 0 (min (View.lightlevels - 1) lightnum)) in
      let mid =
        (if line.flags land Level.lower_unpegged <> 0 then Float.max front.floor back.floor +. float tex.height -. r.viewz
         else Float.min front.ceiling back.ceiling -. r.viewz)
        +. seg.side.yoffset in
      let lightscale = 16. *. 320. /. float r.width in
      for x = x1 to x2 do
        let c = ds.maskedcol.(x - ds.dx1) in
        if c <> View.unset then begin
          let scale = ds.dscale1 +. (float (x - ds.dx1) *. ds.dscalestep) in
          let cmap = walllights.(max 0 (min (View.maxlightscale - 1) (int_of_float (scale *. lightscale)))) in
          (* (the column's posts: 3 bytes before its pixels, id's
           * R_GetColumn - 3; a composited column has none, and shows
           * what is there: the "medusa") *)
          draw_masked_column r x tex.source (tex.columns.(c land tex.width_mask) - 3) mid scale textures.colormaps cmap
            ds.sprtopclip.(x - ds.sprtopoff) ds.sprbottomclip.(x - ds.sprbottomoff);
          ds.maskedcol.(x - ds.dx1) <- View.unset
        end
      done

(* R_DrawSprite: the parts of the walls in front of it clip it; the
 * masked middle textures behind it are drawn first *)
let draw_sprite (r : View.t) (textures : Textures.t) (level : Level.t) (spr : View.vissprite) : unit =
  let clipbot = Array.make r.width (-2) and cliptop = Array.make r.width (-2) in
  List.iter
    (fun (ds : View.drawseg) ->
      if not (ds.dx1 > spr.vx2 || ds.dx2 < spr.vx1 || (ds.silhouette = 0 && Array.length ds.maskedcol = 0)) then begin
        let r1 = max ds.dx1 spr.vx1 and r2 = min ds.dx2 spr.vx2 in
        let scale = Float.max ds.dscale1 ds.dscale2 and lowscale = Float.min ds.dscale1 ds.dscale2 in
        let seg = ds.dseg in
        if
          scale < spr.vscale
          || (lowscale < spr.vscale && Level.side_of spr.gx spr.gy seg.sv1.x seg.sv1.y (seg.sv2.x -. seg.sv1.x) (seg.sv2.y -. seg.sv1.y) = 0)
        then (if Array.length ds.maskedcol > 0 then render_masked_seg_range r textures level ds r1 r2)
        else begin
          let sil = ref ds.silhouette in
          if spr.gz >= ds.bsilheight then sil := !sil land 2;
          if spr.gzt <= ds.tsilheight then sil := !sil land 1;
          for x = r1 to r2 do
            if !sil land 1 <> 0 && clipbot.(x) = -2 then clipbot.(x) <- ds.sprbottomclip.(x - ds.sprbottomoff);
            if !sil land 2 <> 0 && cliptop.(x) = -2 then cliptop.(x) <- ds.sprtopclip.(x - ds.sprtopoff)
          done
        end
      end)
    r.drawsegs;
  (* R_DrawVisSprite *)
  let frac = ref spr.startfrac and width = Wad.short (Bytes.unsafe_to_string spr.patch) 0 in
  for x = spr.vx1 to spr.vx2 do
    let col = max 0 (min (width - 1) (View.ifloor !frac)) in
    let ofs = Wad.int32 (Bytes.unsafe_to_string spr.patch) (8 + (4 * col)) in
    draw_masked_column r x spr.patch ofs spr.texturemid spr.vscale textures.colormaps spr.vcmap
      (if cliptop.(x) = -2 then -1 else cliptop.(x)) (if clipbot.(x) = -2 then r.height else clipbot.(x));
    frac := !frac +. spr.xiscale
  done

(* R_DrawMasked: the things, farthest first, then the masked middle
 * textures left *)
let draw_masked (r : View.t) (textures : Textures.t) (level : Level.t) : unit =
  let sorted = List.stable_sort (fun (a : View.vissprite) (b : View.vissprite) -> compare a.vscale b.vscale) r.vissprites in
  List.iter (draw_sprite r textures level) sorted;
  List.iter (fun (ds : View.drawseg) -> if Array.length ds.maskedcol > 0 then render_masked_seg_range r textures level ds ds.dx1 ds.dx2) r.drawsegs

(* R_DrawPSprite: a picture of the hand, at (sx, sy) of a screen of 320
 * by 200 (the weapon's top at 32 held, 128 lowered), as many times
 * larger as the view is wider; over everything, unclipped; lit by the
 * player's sector (full light if bright) *)
let draw_psprite (r : View.t) (textures : Textures.t) (sprites : Things.sprites)
    (light : int) ((st, sx, sy) : Info.state * float * float) : unit =
  let name = st.sprite ^ String.make 1 (Char.chr (Char.code 'A' + st.frame)) in
  match Things.find sprites name with
  | None -> ()
  | Some f ->
      let patch = f.lumps.(0) in
      if patch <> "" then begin
        let width = Wad.short patch 0 and left = Wad.short patch 4 in
        let top = Wad.short patch 6 in
        let scale = float r.width /. 320. in
        let tx = sx -. 160. -. float left in
        let x1 = View.ifloor (r.centerx +. (tx *. scale)) in
        let x2 = View.ifloor (r.centerx +. ((tx +. float width) *. scale)) - 1 in
        let texturemid = (float r.centery /. scale) -. (sy -. float top) in
        let cmap =
          if st.bright then 0
          else r.scalelight.(View.lit r light).(View.maxlightscale - 1) in
        let src = Bytes.unsafe_of_string patch in
        let step = 1. /. scale in
        for x = max 0 x1 to min (r.width - 1) x2 do
          let frac = float (x - x1) *. step in
          let col = max 0 (min (width - 1) (View.ifloor frac)) in
          let col = if f.flip.(0) then width - 1 - col else col in
          let ofs = Wad.int32 patch (8 + (4 * col)) in
          draw_masked_column r x src ofs texturemid scale textures.colormaps
            cmap (-1) r.height
        done
      end
