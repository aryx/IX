(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-light: a level's lightmaps baked, id's light (qutils' light.c,
 * ltface.c, trace.c, 1996), the last of the three tools a Quake map
 * went through (qbsp, vis, light). It reads the .bsp qbsp made, and
 * writes it again with its LIGHTING lump and each face's light styles
 * and lightmaps' offset.
 *
 * Quake's light is computed here, once, for hours on id's machines;
 * the game only reads it (Surfcache). For each face:
 *
 * 1. Its samples: a point every 16 texels of its texture's s and t,
 *    from its extents (Model), a grid of (w + 1) by (h + 1) points
 *    lifted 1 unit off the face (CalcFaceVectors, CalcPoints). A
 *    point inside the rock (a face's corner against a wall) is moved
 *    towards the face's middle until a ray from the middle reaches it.
 *
 *        +---------------+      x  a sample; the face's texture
 *        x   x   x   x   x         is 64 texels wide, the samples
 *        |               |         16 apart: 5 of them a row
 *        x   x   x   x   x
 *        +---------------+
 *
 * 2. For each light of the map's entities (light, light_torch_..., its
 *    "light" value, 300 by default), each sample asks: does a straight
 *    line from the light reach me through the empty leaves of the BSP
 *    (trace: the tree's walk of the segment, split at each plane it
 *    crosses)? If so, it adds
 *
 *         (light - distance) x (0.5 + 0.5 cos angle)
 *
 *    linear in the distance, a light of 300 reaches 300 units; the
 *    angle between the face's normal and the light (half of it a
 *    constant: id's scalecos, so a wall in grazing light is not black).
 *    A shadow is only that: a sample the line does not reach.
 *
 * 3. Each light has a style (0 the steady light; 1 to 12 flicker,
 *    pulse, strobe: world.qc's strings; 32 and up a light switched by
 *    a trigger). A face keeps a lightmap a style that reaches it, up to
 *    4: the game adds them, each scaled by its style's value at the
 *    time. That is how Quake's lights flicker with lightmaps baked
 *    once: the flickering part is a map of its own.
 *
 * 4. The sums halved (id's rangescale) and clamped to 255, a byte a
 *    sample: 128 is the texture as painted (the colormap's row 32).
 *
 * Beyond id's, what LibreQuake's map asks of ericw-tools, where it is
 * small: "wait" (the falloff's scale: light - distance x wait),
 * "mangle" (a spotlight, its cone "angle", 40 degrees), "_sunlight"
 * (a sample whose ray towards the sun, "_sun_mangle", ends in a sky
 * face is lit, by the angle only) and "_sunlight2" (the same from 32
 * directions of the sky's dome, the light shared among them), the
 * worldspawn's "light" (the least a sample gets), and "_bounce": the
 * light the walls send back, after the direct light and before the
 * sums are halved (section 2 below: a radiosity of a few passes;
 * "_bouncescale" scales it). Not: "_dirt" (corners darkened), colours
 * (a .lit file), "delay" (other falloffs), surface lights.
 *
 * history:
 * id's light (1996) had the direct light only: Quake's rooms are dark
 * where no lamp sees, their corners black. Radiosity (Goral, Torrance,
 * Greenberg and Battaile, "Modeling the Interaction of Light Between
 * Diffuse Surfaces", SIGGRAPH 1984) was what offline renderers did; id
 * baked it for Quake II's lightmaps (qrad3, 1997), and ericw-tools
 * gave Quake's maps a bounce in the 2010s.
 *
 * usage: mini-light in.bsp out.bsp [palette.lmp]
 *   palette: the textures' colours, for how much they reflect (half,
 *   without it) *)

let usage = "usage: mini-light in.bsp out.bsp [palette.lmp]"

open Model

(*****************************************************************************)
(* The trace (trace.c) *)
(*****************************************************************************)

(* the contents where the segment p1 -> p2 first stops: -2 the rock, -6
 * the sky; -1 if it goes through (water and slime let light through) *)
let rec first_hit (h : hull) (num : int) (p1 : vec) (p2 : vec) : int =
  if num < 0 then if num = -2 || num = -6 then num else -1
  else begin
    let pl = h.cplanes.(num) in
    let d1 = dot pl.normal p1 -. pl.dist and d2 = dot pl.normal p2 -. pl.dist in
    if d1 >= -0.1 && d2 >= -0.1 then first_hit h h.front.(num) p1 p2
    else if d1 < 0.1 && d2 < 0.1 then first_hit h h.back.(num) p1 p2
    else begin
      (* split where it crosses: the side of p1 first *)
      let f = d1 /. (d1 -. d2) in
      let mid = add p1 (scale f (sub p2 p1)) in
      let near, far =
        if d1 >= 0. then (h.front.(num), h.back.(num))
        else (h.back.(num), h.front.(num))
      in
      let c = first_hit h near p1 mid in
      if c <> -1 then c else first_hit h far mid p2
    end
  end

(*****************************************************************************)
(* The lights *)
(*****************************************************************************)

type light = {
  origin : vec;
  value : float;
  style : int;
  wait : float;
  (* a spotlight's direction, and the cosine of its cone's half *)
  spot : (vec * float) option;
}

let deg (a : float) : float = a *. 4. *. atan 1. /. 180.

(* yaw pitch roll: a direction (pitch 90 is up) *)
let direction (s : string) : vec =
  let a = vec_of_string s in
  let yaw = deg a.x and pitch = deg a.y in
  { x = cos pitch *. cos yaw; y = cos pitch *. sin yaw; z = sin pitch }

let float_value (e : (string * string) list) (k : string) (default : float) :
    float =
  match value e k with
  | Some v -> (
      match float_of_string_opt (String.trim v) with
      | Some f -> f
      | None -> default)
  | None -> default

let lights_of (entities : (string * string) list list) : light list =
  (* a light switched by a trigger: a style of 32 and up a name *)
  let named = Hashtbl.create 16 in
  List.filter_map
    (fun (e : (string * string) list) ->
      match value e "classname" with
      | Some c when String.length c >= 5 && String.sub c 0 5 = "light" -> (
          match value e "origin" with
          | None -> None
          | Some o ->
              let style = int_of_float (float_value e "style" 0.) in
              let style =
                match value e "targetname" with
                | Some t when style = 0 && t <> "" -> (
                    match Hashtbl.find_opt named t with
                    | Some s -> s
                    | None ->
                        let s = 32 + Hashtbl.length named in
                        Hashtbl.add named t s;
                        s)
                | _ -> style
              in
              let spot =
                Option.map
                  (fun (m : string) ->
                    (direction m, cos (deg (float_value e "angle" 40. /. 2.))))
                  (value e "mangle")
              in
              Some
                {
                  origin = vec_of_string o;
                  value = float_value e "light" 300.;
                  style;
                  wait = float_value e "wait" 1.;
                  spot;
                })
      | _ -> None)
    entities

(* the entities again, each switched light with its style written (as
 * id's light did: the game's light.qc reads it, lightstyle(style, "a")) *)
let with_styles (entities : (string * string) list list) : string =
  let named = Hashtbl.create 16 in
  let b = Buffer.create 65536 in
  List.iter
    (fun (e : (string * string) list) ->
      let e =
        match (value e "classname", value e "targetname") with
        | Some c, Some t
          when String.length c >= 5
               && String.sub c 0 5 = "light"
               && t <> ""
               && int_of_float (float_value e "style" 0.) = 0 ->
            let s =
              match Hashtbl.find_opt named t with
              | Some s -> s
              | None ->
                  let s = 32 + Hashtbl.length named in
                  Hashtbl.add named t s;
                  s
            in
            List.filter (fun ((k, _) : string * string) -> k <> "style") e
            @ [ ("style", string_of_int s) ]
        | _ -> e
      in
      Buffer.add_string b "{\n";
      List.iter
        (fun ((k, v) : string * string) ->
          Buffer.add_string b (Printf.sprintf "\"%s\" \"%s\"\n" k v))
        e;
      Buffer.add_string b "}\n")
    entities;
  (* (the lump ends with a zero, as qbsp's) *)
  Buffer.add_char b '\000';
  Buffer.contents b

(* the sky's dome: 32 directions above, by a golden spiral *)
let dome : vec list =
  List.init 32 (fun (k : int) ->
      let z = (float k +. 0.5) /. 32. in
      let r = sqrt (1. -. (z *. z)) and a = float k *. 2.39996 in
      { x = r *. cos a; y = r *. sin a; z })

(*****************************************************************************)
(* A face (ltface.c) *)
(*****************************************************************************)

(* the face's samples, in the world, (w + 1) by (h + 1) *)
let points (m : Model.t) (f : surface) : vec array * int * int =
  let ti = f.texinfo in
  let normal = if f.back then scale (-1.) f.plane.normal else f.plane.normal in
  let dist = if f.back then -.f.plane.dist else f.plane.dist in
  (* from texture space back to the world (CalcFaceVectors): along the
   * texture's normal, a point keeps its s and t *)
  let texnormal = normalize (cross ti.t ti.s) in
  let distscale = dot texnormal normal in
  let texnormal = if distscale < 0. then scale (-1.) texnormal else texnormal in
  let distscale = 1. /. Float.abs distscale in
  let back_of (v : vec) : vec =
    let len = length v in
    let d = dot v normal *. distscale in
    scale (1. /. (len *. len)) (sub v (scale d texnormal))
  in
  let tw_s = back_of ti.s and tw_t = back_of ti.t in
  let org = add (scale (-.ti.s_offset) tw_s) (scale (-.ti.t_offset) tw_t) in
  (* (on the face's plane, then 1 unit off it) *)
  let d = (dot org normal -. dist -. 1.) *. distscale in
  let org = sub org (scale d texnormal) in
  let at (s : float) (t : float) : vec =
    add org (add (scale s tw_s) (scale t tw_t))
  in
  let smin, tmin = f.texturemins and ew, eh = f.extents in
  let w = ew / 16 and h = eh / 16 in
  let mids = float smin +. (float ew /. 2.)
  and midt = float tmin +. (float eh /. 2.) in
  let mid = at mids midt in
  let hull = m.hulls.(0) and root = m.submodels.(0).headnode.(0) in
  let pts =
    Array.init
      ((w + 1) * (h + 1))
      (fun (k : int) ->
        let us = ref (float (smin + (k mod (w + 1) * 16)))
        and ut = ref (float (tmin + (k / (w + 1) * 16))) in
        (* (towards the middle, 8 texels a try, until the middle sees it) *)
        let rec try_ (i : int) : vec =
          let p = at !us !ut in
          if i = 5 || first_hit hull root mid p = -1 then p
          else begin
            let toward (u : float ref) (mid : float) : unit =
              if !u > mid then u := Float.max mid (!u -. 8.)
              else u := Float.min mid (!u +. 8.)
            in
            if i land 1 = 1 then toward us mids else toward ut midt;
            try_ (i + 1)
          end
        in
        try_ 0)
  in
  (pts, w, h)

(* a face being lit: its samples, its side, its sums a style *)
type lit = {
  face : surface;
  pts : vec array;
  (* the grid's columns: w + 1 *)
  cols : int;
  normal : vec;
  mutable maps : (int * float array) list;
}

(* 1. the direct light: each light, the sun, the sky's dome *)
let direct (m : Model.t) (lights : light list) (sun : (vec * float) list)
    (f : surface) : lit =
  let pts, w, _ = points m f in
  let n = Array.length pts in
  let normal = if f.back then scale (-1.) f.plane.normal else f.plane.normal in
  let dist = if f.back then -.f.plane.dist else f.plane.dist in
  let hull = m.hulls.(0) and root = m.submodels.(0).headnode.(0) in
  (* a lightmap a style, in the order they came *)
  let maps : (int * float array) list ref = ref [] in
  let map_of (style : int) : float array =
    match List.assoc_opt style !maps with
    | Some a -> a
    | None ->
        let a = Array.make n 0. in
        maps := !maps @ [ (style, a) ];
        a
  in
  List.iter
    (fun (l : light) ->
      let d = dot l.origin normal -. dist in
      (* (behind the face, or too far for its light) *)
      if d > 0. && d *. l.wait < l.value then begin
        let acc = Array.make n 0. and hit = ref false in
        Array.iteri
          (fun (k : int) (p : vec) ->
            let incoming = sub l.origin p in
            let dist = length incoming in
            let incoming = scale (1. /. Float.max dist 1.) incoming in
            let in_cone =
              match l.spot with
              | None -> true
              | Some (dir, cone) -> -.dot dir incoming >= cone
            in
            let add =
              (l.value -. (dist *. l.wait))
              *. (0.5 +. (0.5 *. dot incoming normal))
            in
            if in_cone && add > 0. && first_hit hull root l.origin p = -1 then begin
              acc.(k) <- add;
              if add > 1. then hit := true
            end)
          pts;
        if !hit then begin
          let a = map_of l.style in
          Array.iteri (fun (k : int) (v : float) -> a.(k) <- a.(k) +. v) acc
        end
      end)
    lights;
  (* the sun, and the sky's dome *)
  List.iter
    (fun ((dir, value) : vec * float) ->
      let towards = scale (-1.) dir in
      let c = dot towards normal in
      if c > 0. then begin
        let a = map_of 0 in
        Array.iteri
          (fun (k : int) (p : vec) ->
            if first_hit hull root p (add p (scale 16384. towards)) = -6 then
              a.(k) <- a.(k) +. (value *. (0.5 +. (0.5 *. c))))
          pts
      end)
    sun;
  { face = f; pts; cols = w + 1; normal; maps = !maps }

(*****************************************************************************)
(* 2. The bounce (ericw-tools' _bounce) *)
(*****************************************************************************)

(* A wall lit sends part of its light back: what makes a room lit
 * from one lamp not black where the lamp does not see. The faces' own
 * samples are the senders, by 4 by 4 (a patch of 64 by 64 texels,
 * its light their mean, as much as its texture's colour reflects), and
 * the receivers: what a receiver gets of a patch falls with the square
 * of the distance, and by the cosines at both ends (a patch seen
 * edge-on sends nothing):
 *
 *     received = light x reflectivity x area x cos e x cos r / (pi d^2)
 *
 * so a sample before a wide wall of light L gets about L times its
 * reflectivity, as a sample would in the real world. The patch must
 * see the sample (a trace) from a leaf that may (the PVS). Each pass
 * sends what the pass before received: the map's _bounce says how
 * many. Only the steady light (style 0) bounces. *)

type patch = {
  pos : vec;
  pnormal : vec;
  flux : float;
  reach2 : float;
  leaf : int;
}

(* a texture's reflectivity: its mean colour, 0 to 1 (0.5 without the
 * palette) *)
let reflectivity (palette : string option) (t : texture) : float =
  match palette with
  | None -> 0.5
  | Some pal ->
      let mip = t.mips.(3) in
      let sum = ref 0 in
      String.iter
        (fun (c : char) ->
          let i = 3 * Char.code c in
          sum :=
            !sum
            + Char.code pal.[i]
            + Char.code pal.[i + 1]
            + Char.code pal.[i + 2])
        mip;
      float !sum /. (3. *. 255. *. float (String.length mip))

let pi = 4. *. atan 1.

(* the light a sample must get from a patch to count: a quarter of a
 * level of the lightmap's 256 (before id's halving) *)
let least = 0.05

let bounce (m : Model.t) (lits : lit array) (palette : string option)
    (passes : int) (bouncescale : float) : unit =
  let hull = m.hulls.(0) and root = m.submodels.(0).headnode.(0) in
  let pvs_rows = Hashtbl.create 256 in
  let row (leaf : int) : Bytes.t =
    match Hashtbl.find_opt pvs_rows leaf with
    | Some r -> r
    | None ->
        let r = Model.pvs m m.leaves.(leaf) in
        Hashtbl.add pvs_rows leaf r;
        r
  in
  (* each receiver: its middle, its radius, its leaf (a little off it:
   * not the rock's) *)
  let middle (l : lit) : vec =
    scale (1. /. float (Array.length l.pts)) (Array.fold_left add zero l.pts)
  in
  let mids = Array.map middle lits in
  let radius =
    Array.mapi
      (fun (i : int) (l : lit) ->
        Array.fold_left
          (fun (r : float) (p : vec) -> Float.max r (length (sub p mids.(i))))
          0. l.pts)
      lits
  in
  let leaves =
    Array.mapi
      (fun (i : int) (l : lit) ->
        (Model.leaf_at m (add mids.(i) (scale 4. l.normal))).lindex)
      lits
  in
  let sent =
    ref
      (Array.map
         (fun (l : lit) ->
           match List.assoc_opt 0 l.maps with
           | Some a -> a
           | None -> Array.make (Array.length l.pts) 0.)
         lits)
  in
  for _pass = 1 to passes do
    (* the patches of what was received last *)
    let patches =
      List.concat
        (Array.to_list
           (Array.mapi
              (fun (i : int) (l : lit) ->
                let ti = l.face.texinfo in
                let refl = bouncescale *. reflectivity palette ti.texture in
                (* (a sample's area: 16 texels each way, in units) *)
                let area = 16. /. length ti.s *. (16. /. length ti.t) in
                let a = !sent.(i) in
                let groups = Hashtbl.create 16 in
                Array.iteri
                  (fun (k : int) (p : vec) ->
                    let key = (k mod l.cols / 4, k / l.cols / 4) in
                    let sp, sl, n =
                      match Hashtbl.find_opt groups key with
                      | Some g -> g
                      | None -> (zero, 0., 0)
                    in
                    Hashtbl.replace groups key (add sp p, sl +. a.(k), n + 1))
                  l.pts;
                Hashtbl.fold
                  (fun _ ((sp, sl, n) : vec * float * int) (acc : patch list) ->
                    let flux = sl *. refl *. area in
                    if flux <= 0. then acc
                    else
                      let pos = scale (1. /. float n) sp in
                      {
                        pos;
                        pnormal = l.normal;
                        flux;
                        (* (at most 1,024 units: the time bounded) *)
                        reach2 =
                          Float.min (1024. *. 1024.) (flux /. (pi *. least));
                        leaf =
                          (Model.leaf_at m (add pos (scale 4. l.normal))).lindex;
                      }
                      :: acc)
                  groups []
                |> List.sort compare)
              lits))
    in
    let got =
      Array.map (fun (l : lit) -> Array.make (Array.length l.pts) 0.) lits
    in
    List.iter
      (fun (pa : patch) ->
        let vis = row pa.leaf in
        let reach = sqrt pa.reach2 in
        Array.iteri
          (fun (i : int) (l : lit) ->
            let r = leaves.(i) in
            (* in a leaf the patch's may see; near enough; each in
             * front of the other *)
            let seen =
              r > 0
              && Char.code (Bytes.get vis ((r - 1) lsr 3))
                 land (1 lsl ((r - 1) land 7))
                 <> 0
            in
            let to_mid = sub mids.(i) pa.pos in
            if
              seen
              && length to_mid -. radius.(i) < reach
              && dot to_mid pa.pnormal > -.radius.(i)
              && -.dot to_mid l.normal > -.radius.(i)
            then
              Array.iteri
                (fun (k : int) (p : vec) ->
                  let d = sub p pa.pos in
                  let d2 = dot d d in
                  if d2 < pa.reach2 then begin
                    let dl = sqrt d2 in
                    let ce = dot d pa.pnormal /. dl
                    and cr = -.dot d l.normal /. dl in
                    if ce > 0. && cr > 0. then begin
                      (* (no nearer than a patch's size: no infinity
                       * where it touches) *)
                      let e =
                        pa.flux *. ce *. cr /. (pi *. Float.max d2 1024.)
                      in
                      if e > least && first_hit hull root pa.pos p = -1 then
                        got.(i).(k) <- got.(i).(k) +. e
                    end
                  end)
                l.pts)
          lits)
      patches;
    (* what each face got, added to its steady light, and sent next *)
    Array.iteri
      (fun (i : int) (l : lit) ->
        match List.assoc_opt 0 l.maps with
        | Some a ->
            Array.iteri
              (fun (k : int) (v : float) -> a.(k) <- a.(k) +. v)
              got.(i)
        | None ->
            if Array.exists (fun (v : float) -> v > 1.) got.(i) then
              l.maps <- (0, Array.copy got.(i)) :: l.maps)
      lits;
    sent := got
  done

(* 3. the sums made bytes: the least light, style 0 first, 4 at most,
 * halved (id's rangescale), clamped *)
let finish (minlight : float) (l : lit) : (int * string) list =
  let n = Array.length l.pts in
  let maps = ref l.maps in
  let map_of (style : int) : float array =
    match List.assoc_opt style !maps with
    | Some a -> a
    | None ->
        let a = Array.make n 0. in
        maps := !maps @ [ (style, a) ];
        a
  in
  if minlight > 0. then begin
    let a = map_of 0 in
    Array.iteri
      (fun (k : int) (v : float) -> if v < minlight then a.(k) <- minlight)
      a
  end;
  (* (style 0 first, as the game reads them; 4 at most) *)
  let sorted =
    List.filter (fun ((s, _) : int * float array) -> s = 0) !maps
    @ List.filter (fun ((s, _) : int * float array) -> s <> 0) !maps
  in
  let kept = List.filteri (fun (i : int) _ -> i < 4) sorted in
  List.map
    (fun ((style, a) : int * float array) ->
      ( style,
        String.init n (fun (k : int) ->
            Char.chr (max 0 (min 255 (int_of_float (a.(k) *. 0.5))))) ))
    kept

(*****************************************************************************)
(* The level *)
(*****************************************************************************)

let make (caps : < Cap.open_in ; Cap.open_out ; Cap.stdout ; .. >)
    (input : string) (output : string) (palette : string option) : unit =
  let bsp = Bspfile.parse (FS.read caps (Fpath.v input)) in
  let m = Model.load bsp in
  let world = match m.entities with w :: _ -> w | [] -> [] in
  let lights = lights_of m.entities in
  let sun =
    (let v = float_value world "_sunlight" 0. in
     if v = 0. then []
     else
       [
         ( (match value world "_sun_mangle" with
           | Some s -> direction s
           | None -> { x = 0.; y = 0.; z = -1. }),
           v );
       ])
    @
    let v = float_value world "_sunlight2" 0. in
    if v = 0. then []
    else List.map (fun (d : vec) -> (scale (-1.) d, v /. 32.)) dome
  in
  let minlight = float_value world "light" 0. in
  let lits =
    Array.of_list
      (List.filter_map
         (fun (f : surface) ->
           if f.texinfo.special then None else Some (direct m lights sun f))
         (Array.to_list m.surfaces))
  in
  let passes = int_of_float (float_value world "_bounce" 0.) in
  let bouncescale = float_value world "_bouncescale" 1. in
  if passes > 0 then bounce m lits palette passes bouncescale;
  let by_face = Array.make (Array.length m.surfaces) None in
  Array.iter (fun (l : lit) -> by_face.(l.face.index) <- Some l) lits;
  let data = Buffer.create 1_000_000 in
  let faces = Bytes.of_string bsp.lumps.(Bspfile.faces) in
  let lit = ref 0 in
  Array.iter
    (fun (f : surface) ->
      let o = f.index * 20 in
      let maps =
        match by_face.(f.index) with Some l -> finish minlight l | None -> []
      in
      List.iteri
        (fun (i : int) ((s, _) : int * string) ->
          Bytes.set faces (o + 12 + i) (Char.chr s))
        maps;
      for i = List.length maps to 3 do
        Bytes.set faces (o + 12 + i) '\255'
      done;
      let ofs = if maps = [] then -1 else Buffer.length data in
      let b = Buffer.create 4 in
      Bspfile.add_int32 b ofs;
      Bytes.blit_string (Buffer.contents b) 0 faces (o + 16) 4;
      if maps <> [] then incr lit;
      List.iter (fun ((_, s) : int * string) -> Buffer.add_string data s) maps)
    m.surfaces;
  let lumps = Array.copy bsp.lumps in
  lumps.(Bspfile.entities) <- with_styles m.entities;
  lumps.(Bspfile.faces) <- Bytes.to_string faces;
  lumps.(Bspfile.lighting) <- Buffer.contents data;
  FS.write caps (Fpath.v output) (Bspfile.write { bsp with lumps });
  Console.print caps
    (Printf.sprintf "%s: %d lights, %d faces of %d lit, %d bytes of lightmaps\n"
       output (List.length lights) !lit (Array.length m.surfaces)
       (Buffer.length data))

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch
      @@ fun () ->
      (match Array.to_list (CapSys.argv caps) with
      | [ _; i; o ] -> make caps i o None
      | [ _; i; o; p ] -> make caps i o (Some (FS.read caps (Fpath.v p)))
      | _ -> failwith usage);
      Exit.OK)
