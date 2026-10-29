(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Spans.mli *)

open Model

type t = {
  (* the sky (R_InitSky): the back layer, and the front's colours and
   * where it has a hole, 128 by 128; the two made one at each frame
   * (R_MakeSky) *)
  back : Bytes.t;
  front : Bytes.t;
  hole : Bytes.t;
  sky : Bytes.t;
  mutable sky_time : float;
  (* the water's swirl: 128 values of a sine, 0 to 16 texels (16.16) *)
  sintable : int array;
}

let create (m : Model.t) : t =
  let back = Bytes.make (128 * 128) '\000'
  and front = Bytes.make (128 * 128) '\000'
  and hole = Bytes.make (128 * 128) '\001' in
  (match
     Array.to_list m.textures
     |> List.find_map (fun (t : texture option) ->
         match t with
         | Some t
           when String.length t.tname >= 3
                && String.sub t.tname 0 3 = "sky"
                && t.width = 256 ->
             Some t
         | _ -> None)
   with
  | Some t ->
      let src = t.mips.(0) in
      for i = 0 to 127 do
        for j = 0 to 127 do
          (* (the texture's right half the back, its left the front, its
           * colour 0 a hole) *)
          Bytes.set back ((i * 128) + j) src.[(i * 256) + j + 128];
          let c = src.[(i * 256) + j] in
          Bytes.set front ((i * 128) + j) c;
          Bytes.set hole ((i * 128) + j) (if c = '\000' then '\001' else '\000')
        done
      done
  | None -> ());
  {
    back;
    front;
    hole;
    sky = Bytes.create (128 * 128);
    sky_time = -1.;
    sintable =
      Array.init 128 (fun (i : int) ->
          int_of_float
            (8. *. 65536.
            *. (1. +. sin (float i *. 2. *. 4. *. atan 1. /. 128.))));
  }

(*****************************************************************************)
(* The gradients (D_CalcGradients) *)
(*****************************************************************************)

(* a surface's s/z, t/z, 1/z planes on the screen, at a mip *)
type gradients = {
  mutable sdivzstepu : float;
  mutable tdivzstepu : float;
  mutable sdivzstepv : float;
  mutable tdivzstepv : float;
  mutable sdivzorigin : float;
  mutable tdivzorigin : float;
  mutable zistepu : float;
  mutable zistepv : float;
  mutable ziorigin : float;
  mutable sadjust : int;
  mutable tadjust : int;
  (* the last texel, 16.16 (- 1: never past the surface's edge) *)
  mutable bbextents : int;
  mutable bbextentt : int;
}

let g : gradients =
  {
    sdivzstepu = 0.;
    tdivzstepu = 0.;
    sdivzstepv = 0.;
    tdivzstepv = 0.;
    sdivzorigin = 0.;
    tdivzorigin = 0.;
    zistepu = 0.;
    zistepv = 0.;
    ziorigin = 0.;
    sadjust = 0;
    tadjust = 0;
    bbextents = 0;
    bbextentt = 0;
  }

let calc_gradients (v : View.t) (face : Model.surface) (mip : int) (turb : bool)
    : unit =
  let ti = face.texinfo in
  let mipscale = 1. /. float (1 lsl mip) in
  let saxis = View.transform v ti.s and taxis = View.transform v ti.t in
  let t = v.xscaleinv *. mipscale in
  g.sdivzstepu <- saxis.x *. t;
  g.tdivzstepu <- taxis.x *. t;
  let t = v.yscaleinv *. mipscale in
  g.sdivzstepv <- -.saxis.y *. t;
  g.tdivzstepv <- -.taxis.y *. t;
  g.sdivzorigin <-
    (saxis.z *. mipscale)
    -. (v.xcenter *. g.sdivzstepu)
    -. (v.ycenter *. g.sdivzstepv);
  g.tdivzorigin <-
    (taxis.z *. mipscale)
    -. (v.xcenter *. g.tdivzstepu)
    -. (v.ycenter *. g.tdivzstepv);
  (* the eye's own s and t, less where the surface starts: s = s/z x z
   * + sadjust *)
  let org = View.transform v v.modelorg in
  let smin, tmin = if turb then (0, 0) else face.texturemins in
  let ew, eh = face.extents in
  g.sadjust <-
    int_of_float (((dot org saxis +. ti.s_offset) *. mipscale *. 65536.) +. 0.5)
    - ((smin lsl 16) asr mip);
  g.tadjust <-
    int_of_float (((dot org taxis +. ti.t_offset) *. mipscale *. 65536.) +. 0.5)
    - ((tmin lsl 16) asr mip);
  if not turb then begin
    g.bbextents <- ((ew lsl 16) asr mip) - 1;
    g.bbextentt <- ((eh lsl 16) asr mip) - 1
  end

(*****************************************************************************)
(* The spans (D_DrawSpans8) *)
(*****************************************************************************)

let clamp (lo : int) (hi : int) (x : int) : int =
  if x > hi then hi else if x < lo then lo else x

let draw_spans (e : Edges.t) (v : View.t) (first : int) (src : Bytes.t)
    (cachewidth : int) : unit =
  let screen = v.screen and width = v.width in
  let sdivz8 = g.sdivzstepu *. 8.
  and tdivz8 = g.tdivzstepu *. 8.
  and zi8 = g.zistepu *. 8. in
  let bbs = g.bbextents and bbt = g.bbextentt in
  let k = ref first in
  while !k >= 0 do
    let sp = !k in
    let pdest = ref ((e.span_v.(sp) * width) + e.span_u.(sp)) in
    let count = ref e.span_count.(sp) in
    let du = float e.span_u.(sp) and dv = float e.span_v.(sp) in
    let sdivz =
      ref (g.sdivzorigin +. (dv *. g.sdivzstepv) +. (du *. g.sdivzstepu))
    in
    let tdivz =
      ref (g.tdivzorigin +. (dv *. g.tdivzstepv) +. (du *. g.tdivzstepu))
    in
    let zi = ref (g.ziorigin +. (dv *. g.zistepv) +. (du *. g.zistepu)) in
    let z = 65536. /. !zi in
    let s = ref (clamp 0 bbs (int_of_float (!sdivz *. z) + g.sadjust)) in
    let t = ref (clamp 0 bbt (int_of_float (!tdivz *. z) + g.tadjust)) in
    while !count > 0 do
      let spancount = if !count >= 8 then 8 else !count in
      count := !count - spancount;
      (* s and t, and their steps, each a value of its own, not a tuple
       * of the four: a block every 8 pixels otherwise ([@@zero_alloc]
       * refused it). old:
       *   let snext, tnext, sstep, tstep =
       *     if !count > 0 then begin ... (snext, tnext, ...) end
       *     else begin ... end *)
      let more = !count > 0 in
      if more then begin
        (* the exact s and t 8 pixels on *)
        sdivz := !sdivz +. sdivz8;
        tdivz := !tdivz +. tdivz8;
        zi := !zi +. zi8
      end
      else begin
        (* the last pixel's, so as not to step off the surface *)
        let n1 = float (spancount - 1) in
        sdivz := !sdivz +. (g.sdivzstepu *. n1);
        tdivz := !tdivz +. (g.tdivzstepu *. n1);
        zi := !zi +. (g.zistepu *. n1)
      end;
      let z = 65536. /. !zi in
      (* (at least 8: a step back past 0 by rounding would run off the
       * texture) *)
      let snext = clamp 8 bbs (int_of_float (!sdivz *. z) + g.sadjust) in
      let tnext = clamp 8 bbt (int_of_float (!tdivz *. z) + g.tadjust) in
      let sstep =
        if more then (snext - !s) asr 3
        else if spancount > 1 then (snext - !s) / (spancount - 1)
        else 0
      and tstep =
        if more then (tnext - !t) asr 3
        else if spancount > 1 then (tnext - !t) / (spancount - 1)
        else 0
      in
      let ss = ref !s and tt = ref !t and o = !pdest in
      for i = 0 to spancount - 1 do
        Bytes.unsafe_set screen (o + i)
          (Bytes.unsafe_get src ((!ss asr 16) + ((!tt asr 16) * cachewidth)));
        ss := !ss + sstep;
        tt := !tt + tstep
      done;
      pdest := o + spancount;
      s := snext;
      t := tnext
    done;
    k := e.span_next.(sp)
  done
[@@zero_alloc]

(*****************************************************************************)
(* The liquids (Turbulent8) *)
(*****************************************************************************)

let turbulent (sp_ : t) (e : Edges.t) (v : View.t) (first : int) (src : string)
    : unit =
  let screen = v.screen and width = v.width in
  (* (the sine's phase: 20 of its 128 steps a second) *)
  let phase = int_of_float (v.time *. 20.) land 127 in
  let turb = sp_.sintable in
  let sdivz16 = g.sdivzstepu *. 16.
  and tdivz16 = g.tdivzstepu *. 16.
  and zi16 = g.zistepu *. 16. in
  let st (sdivz : float) (tdivz : float) (zi : float) : int * int =
    let z = 65536. /. zi in
    ( int_of_float (sdivz *. z) + g.sadjust,
      int_of_float (tdivz *. z) + g.tadjust )
  in
  let k = ref first in
  while !k >= 0 do
    let sp = !k in
    let pdest = ref ((e.span_v.(sp) * width) + e.span_u.(sp)) in
    let count = ref e.span_count.(sp) in
    let du = float e.span_u.(sp) and dv = float e.span_v.(sp) in
    let sdivz =
      ref (g.sdivzorigin +. (dv *. g.sdivzstepv) +. (du *. g.sdivzstepu))
    in
    let tdivz =
      ref (g.tdivzorigin +. (dv *. g.tdivzstepv) +. (du *. g.tdivzstepu))
    in
    let zi = ref (g.ziorigin +. (dv *. g.zistepv) +. (du *. g.zistepu)) in
    let s0, t0 = st !sdivz !tdivz !zi in
    let s = ref s0 and t = ref t0 in
    while !count > 0 do
      let spancount = if !count >= 16 then 16 else !count in
      count := !count - spancount;
      let n = if !count > 0 then 16. else float (spancount - 1) in
      sdivz := !sdivz +. if !count > 0 then sdivz16 else g.sdivzstepu *. n;
      tdivz := !tdivz +. if !count > 0 then tdivz16 else g.tdivzstepu *. n;
      zi := !zi +. if !count > 0 then zi16 else g.zistepu *. n;
      let snext, tnext = st !sdivz !tdivz !zi in
      let sstep, tstep =
        if !count > 0 then ((snext - !s) asr 4, (tnext - !t) asr 4)
        else if spancount > 1 then
          ((snext - !s) / (spancount - 1), (tnext - !t) / (spancount - 1))
        else (0, 0)
      in
      (* (no extents: s and t taken modulo the 64 by 64 texture, the
       * swirl a cycle of 128 texels) *)
      let ss = ref (!s land ((128 lsl 16) - 1))
      and tt = ref (!t land ((128 lsl 16) - 1))
      and o = !pdest in
      for i = 0 to spancount - 1 do
        let sturb =
          ((!ss + turb.(((!tt asr 16) + phase) land 127)) asr 16) land 63
        in
        let tturb =
          ((!tt + turb.(((!ss asr 16) + phase) land 127)) asr 16) land 63
        in
        Bytes.unsafe_set screen (o + i)
          (String.unsafe_get src ((tturb lsl 6) + sturb));
        ss := !ss + sstep;
        tt := !tt + tstep
      done;
      pdest := o + spancount;
      s := snext;
      t := tnext
    done;
    k := e.span_next.(sp)
  done

(*****************************************************************************)
(* The sky (d_sky.c, r_sky.c) *)
(*****************************************************************************)

(* the two layers made one: the front moved by the time, the back seen
 * through its holes (R_MakeSky) *)
let make_sky (sp_ : t) (shift : int) : unit =
  for y = 0 to 127 do
    for x = 0 to 127 do
      let ofs = ((y + shift) land 127 * 128) + ((x + shift) land 127) in
      let c =
        if Bytes.get sp_.hole ofs = '\001' then
          Bytes.get sp_.back ((y * 128) + x)
        else Bytes.get sp_.front ofs
      in
      Bytes.set sp_.sky ((y * 128) + x) c
    done
  done

(* a pixel's direction, flattened, made s and t of the sky (16.16)
 * (D_Sky_uv_To_st) *)
let sky_st (v : View.t) (time : float) (u : int) (w : int) : int * int =
  let temp = float (max v.width v.height) in
  let wu = 8192. *. float (u - (v.width / 2)) /. temp
  and wv = 8192. *. float ((v.height / 2) - w) /. temp in
  let e = add (scale 4096. v.vpn) (add (scale wu v.vright) (scale wv v.vup)) in
  let e = normalize { e with z = e.z *. 3. } in
  ( int_of_float ((time +. (6. *. 63. *. e.x)) *. 65536.),
    int_of_float ((time +. (6. *. 63. *. e.y)) *. 65536.) )

let draw_sky (sp_ : t) (e : Edges.t) (v : View.t) (first : int) : unit =
  (* (the back at 8 texels a second, the front at 16) *)
  let time = v.time *. 8. in
  let shift = int_of_float time in
  if float shift <> sp_.sky_time then begin
    make_sky sp_ shift;
    sp_.sky_time <- float shift
  end;
  let screen = v.screen and sky = sp_.sky in
  let k = ref first in
  while !k >= 0 do
    let sp = !k in
    let u = ref e.span_u.(sp)
    and w = e.span_v.(sp)
    and count = ref e.span_count.(sp) in
    let pdest = ref ((w * v.width) + !u) in
    let s0, t0 = sky_st v time !u w in
    let s = ref s0 and t = ref t0 in
    while !count > 0 do
      (* (the direction exact every 32 pixels) *)
      let spancount = if !count >= 32 then 32 else !count in
      count := !count - spancount;
      let n = if !count > 0 then spancount else spancount - 1 in
      let snext, tnext = if n > 0 then sky_st v time (!u + n) w else (!s, !t) in
      u := !u + spancount;
      let sstep = if n > 0 then (snext - !s) / n else 0
      and tstep = if n > 0 then (tnext - !t) / n else 0 in
      let o = !pdest in
      for i = 0 to spancount - 1 do
        Bytes.unsafe_set screen (o + i)
          (Bytes.unsafe_get sky
             (((!t asr 16) land 127 * 128) + ((!s asr 16) land 127)));
        s := !s + sstep;
        t := !t + tstep
      done;
      pdest := o + spancount;
      s := snext;
      t := tnext
    done;
    k := e.span_next.(sp)
  done

(*****************************************************************************)
(* The z-buffer (D_DrawZSpans) *)
(*****************************************************************************)

(* each pixel's 1/z, for the models drawn after: the surface's plane of
 * 1/z, stepped along the span *)
let draw_zspans (e : Edges.t) (v : View.t) (first : int) : unit =
  let zbuf = v.zbuffer and width = v.width in
  let one = 16777216. in
  let step = int_of_float (g.zistepu *. one) in
  let k = ref first in
  while !k >= 0 do
    let sp = !k in
    let du = float e.span_u.(sp) and dv = float e.span_v.(sp) in
    let izi =
      ref
        (int_of_float
           ((g.ziorigin +. (dv *. g.zistepv) +. (du *. g.zistepu)) *. one))
    in
    let o = (e.span_v.(sp) * width) + e.span_u.(sp) in
    for i = 0 to e.span_count.(sp) - 1 do
      Array.unsafe_set zbuf (o + i) !izi;
      izi := !izi + step
    done;
    k := e.span_next.(sp)
  done
[@@zero_alloc]

(*****************************************************************************)
(* The surfaces (D_DrawSurfaces) *)
(*****************************************************************************)

(* the mip level for a face's nearest 1/z (D_MipLevelForScale): its
 * texels' size on the screen, 1 or more mip 0, 0.4 mip 1, 0.2 mip 2 *)
let mip_level (v : View.t) (face : Model.surface) (nearzi : float) : int =
  let ti = face.texinfo in
  let len = (length ti.s +. length ti.t) /. 2. in
  let mipadjust =
    if len < 0.32 then 4.
    else if len < 0.49 then 3.
    else if len < 0.99 then 2.
    else 1. /. Float.floor (len +. 0.1)
  in
  let scale = nearzi *. Float.max v.xscale v.yscale *. mipadjust in
  if scale >= 1. then 0
  else if scale >= 0.4 then 1
  else if scale >= 0.2 then 2
  else 3

let draw (sp_ : t) (e : Edges.t) (v : View.t) (m : Model.t)
    (cache : Surfcache.t) (origins : vec array) (frames : int array) : unit =
  let world_org = v.modelorg in
  for s = 1 to e.num_surfaces - 1 do
    let first = e.spans.(s) in
    if first >= 0 then begin
      g.zistepu <- e.zistepu.(s);
      g.zistepv <- e.zistepv.(s);
      g.ziorigin <- e.ziorigin.(s);
      if s = Edges.background then begin
        (* (r_clearcolor: what shows where the level has a hole) *)
        let k = ref first in
        while !k >= 0 do
          Bytes.fill v.screen
            ((e.span_v.(!k) * v.width) + e.span_u.(!k))
            e.span_count.(!k) '\002';
          Array.fill v.zbuffer
            ((e.span_v.(!k) * v.width) + e.span_u.(!k))
            e.span_count.(!k) 0;
          k := e.span_next.(!k)
        done
      end
      else begin
        let face = m.surfaces.(e.face.(s)) in
        let ent = e.entity.(s) in
        if e.insubmodel.(s) then v.modelorg <- sub v.origin origins.(ent);
        (match face.kind with
        | Sky -> draw_sky sp_ e v first
        | Turbulent ->
            calc_gradients v face 0 true;
            turbulent sp_ e v first
              (Surfcache.animation face.texinfo.texture v.time frames.(ent))
                .mips.(0)
        | Normal ->
            let mip = mip_level v face e.nearzi.(s) in
            let surf = Surfcache.surface cache v m face mip frames.(ent) in
            calc_gradients v face mip false;
            draw_spans e v first surf.data surf.width);
        draw_zspans e v first;
        v.modelorg <- world_org
      end
    end
  done;
  (* (the spans drawn: the table emptied by Scan) *)
  ()
