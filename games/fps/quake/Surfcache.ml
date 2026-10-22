(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Surfcache.mli *)

open Model

type surface = { data : Bytes.t; width : int }

type entry = {
  mutable etexture : texture;
  lightadj : int array;
  surf : surface;
}

type t = {
  entries : (int, entry) Hashtbl.t;
  (* the entries' keys in the order they were made: the oldest first
   * out *)
  order : int Queue.t;
  mutable bytes : int;
  mutable made : int;
  (* a face's light at each sample, then its colormap's row x 256
   * (blocklights) *)
  blocklights : int array;
}

let budget = 1_000_000
let grey = ref false

let create () : t =
  {
    entries = Hashtbl.create 1024;
    order = Queue.create ();
    bytes = 0;
    made = 0;
    blocklights = Array.make (18 * 18) 0;
  }

let made (c : t) : int = c.made

let animation (base : texture) (time : float) (frame : int) : texture =
  let base =
    match base.alternate with Some a when frame <> 0 -> a | _ -> base
  in
  if base.anim_total = 0 then base
  else begin
    let rel = int_of_float (time *. 10.) mod base.anim_total in
    let t = ref base and count = ref 0 in
    while !t.anim_min > rel || !t.anim_max <= rel do
      (match !t.anim_next with
      | Some n -> t := n
      | None -> failwith ("a broken animation: " ^ base.tname));
      incr count;
      if !count > 100 then failwith ("an endless animation: " ^ base.tname)
    done;
    !t
  end

(* the light at each sample, as a row of the colormap times 256
 * (R_BuildLightMap) *)
let build_lightmap (c : t) (m : Model.t) (face : Model.surface)
    (lightadj : int array) : unit =
  let ew, eh = face.extents in
  let size = ((ew lsr 4) + 1) * ((eh lsr 4) + 1) in
  let bl = c.blocklights in
  Array.fill bl 0 size 0;
  if face.samples >= 0 && m.lighting <> "" then begin
    let maps = ref 0 in
    while !maps < 4 && face.styles.(!maps) <> 255 do
      (* (8.8: 256 the light as baked) *)
      let scale = lightadj.(!maps) and base = face.samples + (!maps * size) in
      for i = 0 to size - 1 do
        bl.(i) <-
          bl.(i) + (Char.code (String.unsafe_get m.lighting (base + i)) * scale)
      done;
      incr maps
    done
  end;
  (* (bright is a low row: 255 x 256 less it, 6 bits of row, at least
   * row 0.25) *)
  for i = 0 to size - 1 do
    let t = ((255 * 256) - bl.(i)) asr 2 in
    bl.(i) <- (if t < 64 then 64 else t)
  done

(* the texture tiled over the face, lit block by block (R_DrawSurface,
 * R_DrawSurfaceBlock8_mip0 to 3) *)
let draw_surface (c : t) (v : View.t) (face : Model.surface) (tex : texture)
    (mip : int) (dst : Bytes.t) (width : int) (height : int) : unit =
  let src = tex.mips.(mip) in
  let colormap = v.colormap in
  let texw = tex.width lsr mip and texh = tex.height lsr mip in
  let blocksize = 16 lsr mip and blockshift = 4 - mip in
  let lightwidth = (fst face.extents lsr 4) + 1 in
  let hblocks = width lsr blockshift and vblocks = height lsr blockshift in
  let smin, tmin = face.texturemins in
  (* (where the face starts in the texture, the texture repeating) *)
  let soffset = (((smin asr mip) mod texw) + texw) mod texw in
  let toffset = (((tmin asr mip) mod texh) + texh) mod texh in
  let bl = c.blocklights in
  let grey = !grey in
  for u = 0 to hblocks - 1 do
    let s = (soffset + (u * blocksize)) mod texw in
    for b = 0 to vblocks - 1 do
      let lp = (b * lightwidth) + u in
      let lightleft = ref bl.(lp) and lightright = ref bl.(lp + 1) in
      let leftstep = (bl.(lp + lightwidth) - !lightleft) asr blockshift in
      let rightstep = (bl.(lp + lightwidth + 1) - !lightright) asr blockshift in
      for i = 0 to blocksize - 1 do
        let t = (toffset + (b * blocksize) + i) mod texh in
        let row = t * texw in
        let step = (!lightleft - !lightright) asr blockshift in
        let light = ref !lightright in
        let o = (((b * blocksize) + i) * width) + (u * blocksize) in
        (* (right to left, as id's) *)
        for x = blocksize - 1 downto 0 do
          let pix =
            if grey then 9 else Char.code (String.unsafe_get src (row + s + x))
          in
          Bytes.unsafe_set dst (o + x)
            (String.unsafe_get colormap ((!light land 0xFF00) + pix));
          light := !light + step
        done;
        lightleft := !lightleft + leftstep;
        lightright := !lightright + rightstep
      done
    done
  done

let surface (c : t) (v : View.t) (m : Model.t) (face : Model.surface)
    (mip : int) (frame : int) : surface =
  let tex = animation face.texinfo.texture v.time frame in
  let adj (k : int) : int =
    let s = face.styles.(k) in
    if s = 255 then 0 else v.lightstyles.(s)
  in
  let key = (face.index * 4) + mip in
  let fresh (e : entry) : bool =
    e.etexture == tex
    && e.lightadj.(0) = adj 0
    && e.lightadj.(1) = adj 1
    && e.lightadj.(2) = adj 2
    && e.lightadj.(3) = adj 3
  in
  match Hashtbl.find_opt c.entries key with
  | Some e when fresh e -> e.surf
  | found ->
      let ew, eh = face.extents in
      let width = ew lsr mip and height = eh lsr mip in
      let e =
        match found with
        | Some e -> e
        | None ->
            (* the oldest out, until it fits *)
            while
              c.bytes + (width * height) > budget
              && not (Queue.is_empty c.order)
            do
              let k = Queue.pop c.order in
              match Hashtbl.find_opt c.entries k with
              | Some old ->
                  Hashtbl.remove c.entries k;
                  c.bytes <- c.bytes - Bytes.length old.surf.data
              | None -> ()
            done;
            let e =
              {
                etexture = tex;
                lightadj = Array.make 4 0;
                surf = { data = Bytes.create (width * height); width };
              }
            in
            Hashtbl.replace c.entries key e;
            Queue.push key c.order;
            c.bytes <- c.bytes + (width * height);
            e
      in
      e.etexture <- tex;
      for k = 0 to 3 do
        e.lightadj.(k) <- adj k
      done;
      build_lightmap c m face e.lightadj;
      draw_surface c v face tex mip e.surf.data width height;
      c.made <- c.made + 1;
      e.surf
