(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Alias.mli *)

open Model

type frame = { fname : string; verts : Bytes.t; mutable normals : float array }

type t = {
  scale : vec;
  scale_origin : vec;
  skinwidth : int;
  skinheight : int;
  skins : string array;
  onseam : bool array;
  s : int array;
  t : int array;
  tris : int array;
  facesfront : bool array;
  frames : frame array;
  flags : int;
}

(*****************************************************************************)
(* Loading (Mod_LoadAliasModel) *)
(*****************************************************************************)

(* each vertex's normal: the faces' around it, in the model's space *)
let normals (scale : vec) (numverts : int) (tris : int array) (verts : Bytes.t)
    : float array =
  let pos (i : int) : vec =
    let c (k : int) (s : float) : float =
      float (Char.code (Bytes.get verts ((4 * i) + k))) *. s
    in
    { x = c 0 scale.x; y = c 1 scale.y; z = c 2 scale.z }
  in
  let acc = Array.make (3 * numverts) 0. in
  for k = 0 to (Array.length tris / 3) - 1 do
    let a = tris.(3 * k)
    and b = tris.((3 * k) + 1)
    and c = tris.((3 * k) + 2) in
    (* (id's triangles turn clockwise seen from outside) *)
    let n = cross (sub (pos c) (pos a)) (sub (pos b) (pos a)) in
    List.iter
      (fun (i : int) ->
        acc.(3 * i) <- acc.(3 * i) +. n.x;
        acc.((3 * i) + 1) <- acc.((3 * i) + 1) +. n.y;
        acc.((3 * i) + 2) <- acc.((3 * i) + 2) +. n.z)
      [ a; b; c ]
  done;
  for i = 0 to numverts - 1 do
    let n =
      normalize
        { x = acc.(3 * i); y = acc.((3 * i) + 1); z = acc.((3 * i) + 2) }
    in
    acc.(3 * i) <- n.x;
    acc.((3 * i) + 1) <- n.y;
    acc.((3 * i) + 2) <- n.z
  done;
  acc

let load (d : string) : t =
  if
    String.length d < 84 || String.sub d 0 4 <> "IDPO" || Bspfile.int32 d 4 <> 6
  then failwith "not an .mdl of version 6";
  let i32 (o : int) : int = Bspfile.int32 d o
  and f32 (o : int) : float = Bspfile.float32 d o in
  let v3 (o : int) : vec = { x = f32 o; y = f32 (o + 4); z = f32 (o + 8) } in
  let scale = v3 8 and scale_origin = v3 20 in
  let numskins = i32 48
  and sw = i32 52
  and sh = i32 56
  and numverts = i32 60
  and numtris = i32 64
  and numframes = i32 68 in
  let flags = i32 76 in
  let o = ref 84 in
  let skins =
    Array.init numskins (fun _ ->
        if i32 !o = 0 then begin
          let s = String.sub d (!o + 4) (sw * sh) in
          o := !o + 4 + (sw * sh);
          s
        end
        else begin
          (* a group: its count, its intervals, its pictures; the first *)
          let n = i32 (!o + 4) in
          let first = !o + 8 + (4 * n) in
          o := first + (n * sw * sh);
          String.sub d first (sw * sh)
        end)
  in
  let onseam =
    Array.init numverts (fun (k : int) -> i32 (!o + (12 * k)) <> 0)
  in
  let s = Array.init numverts (fun (k : int) -> i32 (!o + (12 * k) + 4)) in
  let t = Array.init numverts (fun (k : int) -> i32 (!o + (12 * k) + 8)) in
  o := !o + (12 * numverts);
  let facesfront =
    Array.init numtris (fun (k : int) -> i32 (!o + (16 * k)) <> 0)
  in
  let tris =
    Array.init (3 * numtris) (fun (k : int) ->
        i32 (!o + (16 * (k / 3)) + 4 + (4 * (k mod 3))))
  in
  o := !o + (16 * numtris);
  let frames = ref [] in
  let simple () : unit =
    (* (its box, 8 bytes, then its name and its vertices) *)
    let fname = Bspfile.name d (!o + 8) 16 in
    let verts = Bytes.of_string (String.sub d (!o + 24) (4 * numverts)) in
    (* (the normals made when the frame is first drawn: most frames of
     * a model never are) *)
    frames := { fname; verts; normals = [||] } :: !frames;
    o := !o + 24 + (4 * numverts)
  in
  for _f = 1 to numframes do
    let kind = i32 !o in
    o := !o + 4;
    if kind = 0 then simple ()
    else begin
      let n = i32 !o in
      o := !o + 12 + (4 * n);
      for _k = 1 to n do
        simple ()
      done
    end
  done;
  {
    scale;
    scale_origin;
    skinwidth = sw;
    skinheight = sh;
    skins;
    onseam;
    s;
    t;
    tris;
    facesfront;
    frames = Array.of_list (List.rev !frames);
    flags;
  }

let frames_named (m : t) (prefix : string) : int list =
  let n = String.length prefix in
  List.filter
    (fun (k : int) ->
      let f = m.frames.(k).fname in
      String.length f >= n && String.sub f 0 n = prefix)
    (List.init (Array.length m.frames) (fun (k : int) -> k))

(*****************************************************************************)
(* The light under it (R_LightPoint) *)
(*****************************************************************************)

let light_point (m : Model.t) (v : View.t) (p : vec) : int =
  if m.lighting = "" then 255
  else begin
    let rec walk (c : child) (start : vec) (stop : vec) : int =
      match c with
      | Leaf _ -> -1
      | Node n ->
          let pl = n.nplane in
          let front = dot start pl.normal -. pl.dist
          and back = dot stop pl.normal -. pl.dist in
          let side = if front < 0. then 1 else 0 in
          if back < 0. = (side = 1) then walk n.children.(side) start stop
          else begin
            let mid =
              add start (scale (front /. (front -. back)) (sub stop start))
            in
            let r = walk n.children.(side) start mid in
            if r >= 0 then r
            else begin
              (* the faces of this node under the mid point *)
              let found = ref (-2) in
              for k = n.first_surface to n.first_surface + n.num_surfaces - 1 do
                let f = m.surfaces.(k) in
                if !found = -2 && f.kind = Normal then begin
                  let ti = f.texinfo in
                  let s = int_of_float (dot mid ti.s +. ti.s_offset)
                  and t = int_of_float (dot mid ti.t +. ti.t_offset) in
                  let smin, tmin = f.texturemins and ew, eh = f.extents in
                  let ds = s - smin and dt = t - tmin in
                  if ds >= 0 && dt >= 0 && ds <= ew && dt <= eh then
                    if f.samples < 0 then found := 0
                    else begin
                      let w = (ew lsr 4) + 1 and h = (eh lsr 4) + 1 in
                      let r = ref 0 and maps = ref 0 in
                      while !maps < 4 && f.styles.(!maps) <> 255 do
                        let o =
                          f.samples
                          + (!maps * w * h)
                          + ((dt lsr 4) * w)
                          + (ds lsr 4)
                        in
                        r :=
                          !r
                          + Char.code m.lighting.[o]
                            * v.lightstyles.(f.styles.(!maps));
                        incr maps
                      done;
                      found := !r asr 8
                    end
                end
              done;
              if !found <> -2 then !found
              else walk n.children.(1 - side) mid stop
            end
          end
    in
    max 0 (walk (submodel_root m 0) p { p with z = p.z -. 2048. })
  end

(*****************************************************************************)
(* Drawing (r_alias.c, d_polyse.c) *)
(*****************************************************************************)

(* a vertex on the screen: u, v, 1/z (x 2^24), s, t (16.16), light *)
type screen_vert = {
  su : float;
  sv : float;
  zi : float;
  ss : float;
  st : float;
  light : float;
}

(* one triangle, its pixels nearer than the z-buffer's drawn: rows
 * top to bottom, the left and right edges' values interpolated, then
 * stepped across (D_PolysetDraw's work, without its edge tables) *)
let triangle (v : View.t) (skin : string) (sw : int) (a : screen_vert)
    (b : screen_vert) (c : screen_vert) : unit =
  let sorted =
    List.sort
      (fun (p : screen_vert) (q : screen_vert) -> compare p.sv q.sv)
      [ a; b; c ]
  in
  match sorted with
  | [ p0; p1; p2 ] when p2.sv > p0.sv ->
      let screen = v.screen
      and zbuf = v.zbuffer
      and colormap = v.colormap
      and width = v.width in
      let y0 = max 0 (int_of_float (Float.ceil p0.sv))
      and y1 = min (v.height - 1) (int_of_float (Float.ceil p2.sv) - 1) in
      (* a value along the edge from p to q at row y *)
      let at (p : screen_vert) (q : screen_vert) (y : float)
          (f : screen_vert -> float) : float =
        if q.sv = p.sv then f p
        else f p +. ((f q -. f p) *. (y -. p.sv) /. (q.sv -. p.sv))
      in
      for y = y0 to y1 do
        let fy = float y in
        let long (f : screen_vert -> float) : float = at p0 p2 fy f in
        let short (f : screen_vert -> float) : float =
          if fy < p1.sv then at p0 p1 fy f else at p1 p2 fy f
        in
        let xa = long (fun (p : screen_vert) -> p.su)
        and xb = short (fun (p : screen_vert) -> p.su) in
        let l, r, sel = if xa <= xb then (xa, xb, true) else (xb, xa, false) in
        let left (f : screen_vert -> float) : float =
          if sel then long f else short f
        in
        let right (f : screen_vert -> float) : float =
          if sel then short f else long f
        in
        let x0 = max 0 (int_of_float (Float.ceil l))
        and x1 = min (width - 1) (int_of_float (Float.ceil r) - 1) in
        if x1 >= x0 then begin
          let span = r -. l in
          let fixed (f : screen_vert -> float) : int * int =
            let lv = left f and rv = right f in
            let step = if span > 0. then (rv -. lv) /. span else 0. in
            let start = lv +. ((float x0 -. l) *. step) in
            (int_of_float (start *. 65536.), int_of_float (step *. 65536.))
          in
          let zi, zistep =
            let lv = left (fun (p : screen_vert) -> p.zi)
            and rv = right (fun (p : screen_vert) -> p.zi) in
            let step = if span > 0. then (rv -. lv) /. span else 0. in
            ( ref (int_of_float (lv +. ((float x0 -. l) *. step))),
              int_of_float step )
          in
          let s, sstep = fixed (fun (p : screen_vert) -> p.ss)
          and t, tstep = fixed (fun (p : screen_vert) -> p.st) in
          let li, listep = fixed (fun (p : screen_vert) -> p.light) in
          let s = ref s and t = ref t and li = ref li in
          let o = y * width in
          for x = x0 to x1 do
            if !zi >= zbuf.(o + x) then begin
              zbuf.(o + x) <- !zi;
              let texel =
                Char.code
                  (String.unsafe_get skin (((!t asr 16) * sw) + (!s asr 16)))
              in
              Bytes.unsafe_set screen (o + x)
                (String.unsafe_get colormap
                   (((!li asr 16) land 0xFF00) + texel))
            end;
            zi := !zi + zistep;
            s := !s + sstep;
            t := !t + tstep;
            li := !li + listep
          done
        end
      done
  | _ -> ()

let draw (v : View.t) (m : t) (origin : vec) (yaw : float) (frame : int)
    (skin : int) (light : int) : unit =
  let fr = m.frames.(frame mod Array.length m.frames) in
  if fr.normals = [||] then
    fr.normals <- normals m.scale (Array.length m.onseam) m.tris fr.verts;
  let skin = m.skins.(skin mod Array.length m.skins) in
  let forward, right, up = View.angle_vectors 0. yaw in
  (* the light (R_AliasSetupLighting): an ambient part, at least 5, at
   * most 128, and a shade from one side, as colormap rows x 256 *)
  let ambient = max 5 (min 128 light) in
  let shade = max 0 (min light (192 - ambient)) in
  let r_ambient = float ((255 - ambient) lsl 6)
  and r_shade = float (shade * 64) in
  (* (the light comes along -x in the world: in the model's space) *)
  let lv = { x = -1.; y = 0.; z = 0. } in
  let plv = { x = dot lv forward; y = -.dot lv right; z = dot lv up } in
  let n = Array.length m.onseam in
  let verts =
    Array.init n (fun (i : int) ->
        let c (k : int) : float =
          float (Char.code (Bytes.get fr.verts ((4 * i) + k)))
        in
        let p =
          {
            x = (c 0 *. m.scale.x) +. m.scale_origin.x;
            y = (c 1 *. m.scale.y) +. m.scale_origin.y;
            z = (c 2 *. m.scale.z) +. m.scale_origin.z;
          }
        in
        (* the model's x forward, y left, z up *)
        let w =
          add origin
            (add (scale p.x forward) (add (scale (-.p.y) right) (scale p.z up)))
        in
        let t = View.transform v (sub w v.origin) in
        let z = Float.max t.z 0.01 in
        let lightcos =
          (fr.normals.(3 * i) *. plv.x)
          +. (fr.normals.((3 * i) + 1) *. plv.y)
          +. (fr.normals.((3 * i) + 2) *. plv.z)
        in
        let l =
          if lightcos < 0. then Float.max 0. (r_ambient +. (r_shade *. lightcos))
          else r_ambient
        in
        ( t.z,
          {
            su = v.xcenter +. (v.xscale *. t.x /. z);
            sv = v.ycenter -. (v.yscale *. t.y /. z);
            zi = 16777216. /. z;
            ss = float m.s.(i);
            st = float m.t.(i);
            light = l;
          } ))
  in
  for k = 0 to Array.length m.facesfront - 1 do
    let ia = m.tris.(3 * k)
    and ib = m.tris.((3 * k) + 1)
    and ic = m.tris.((3 * k) + 2) in
    let za, a = verts.(ia) and zb, b = verts.(ib) and zc, c = verts.(ic) in
    (* (a triangle with a corner behind the eye is left out: id's clips
     * it; a model that near is rare) *)
    if za > 1. && zb > 1. && zc > 1. then begin
      (* facing the eye (d_xdenom < 0) *)
      let denom =
        ((a.sv -. b.sv) *. (a.su -. c.su)) -. ((a.su -. b.su) *. (a.sv -. c.sv))
      in
      if denom < 0. then begin
        (* the back half of the skin for a back triangle's seam vertices *)
        let seam (i : int) (p : screen_vert) : screen_vert =
          if (not m.facesfront.(k)) && m.onseam.(i) then
            { p with ss = p.ss +. float (m.skinwidth / 2) }
          else p
        in
        let clamp (p : screen_vert) : screen_vert =
          {
            p with
            ss = Float.max 0. (Float.min (float m.skinwidth -. 1.) p.ss);
            st = Float.max 0. (Float.min (float m.skinheight -. 1.) p.st);
          }
        in
        triangle v skin m.skinwidth
          (clamp (seam ia a))
          (clamp (seam ib b))
          (clamp (seam ic c))
      end
    end
  done
