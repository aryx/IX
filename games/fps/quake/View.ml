(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See View.mli *)

open Model

type clip = { mutable cnormal : vec; mutable cdist : float }

type t = {
  width : int;
  height : int;
  screen : Bytes.t;
  zbuffer : int array;
  colormap : string;
  xcenter : float;
  ycenter : float;
  xscale : float;
  yscale : float;
  xscaleinv : float;
  yscaleinv : float;
  screenedge : vec array;
  mutable origin : vec;
  mutable vpn : vec;
  mutable vright : vec;
  mutable vup : vec;
  mutable modelorg : vec;
  clips : clip array;
  frustum_indexes : int array array;
  mutable framecount : int;
  mutable visframecount : int;
  mutable oldviewleaf : int;
  mutable currentkey : int;
  lightstyles : int array;
  mutable time : float;
}

let deg (a : float) : float = a *. 4. *. atan 1. /. 180.

let angle_vectors (pitch : float) (yaw : float) : vec * vec * vec =
  let sy = sin (deg yaw)
  and cy = cos (deg yaw)
  and sp = sin (deg pitch)
  and cp = cos (deg pitch) in
  (* (no roll) *)
  ( { x = cp *. cy; y = cp *. sy; z = -.sp },
    { x = sy; y = -.cy; z = 0. },
    { x = sp *. cy; y = sp *. sy; z = cp } )

let create (colormap : string) (width : int) (height : int) : t =
  (* (90 degrees across) *)
  let hfov = 2. *. tan (deg 45.) in
  let xscale = float width /. hfov in
  let yscale = xscale in
  let vfov = hfov /. (float width /. float height) in
  let edge (x : float) (y : float) : vec = normalize { x; y; z = 1. } in
  {
    width;
    height;
    screen = Bytes.make (width * height) '\000';
    zbuffer = Array.make (width * height) 0;
    colormap;
    xcenter = (float width /. 2.) -. 0.5;
    ycenter = (float height /. 2.) -. 0.5;
    xscale;
    yscale;
    xscaleinv = 1. /. xscale;
    yscaleinv = 1. /. yscale;
    screenedge =
      [|
        edge (-1. /. (0.5 *. hfov)) 0.;
        edge (1. /. (0.5 *. hfov)) 0.;
        edge 0. (-1. /. (0.5 *. vfov));
        edge 0. (1. /. (0.5 *. vfov));
      |];
    origin = zero;
    vpn = zero;
    vright = zero;
    vup = zero;
    modelorg = zero;
    clips = Array.init 4 (fun _ -> { cnormal = zero; cdist = 0. });
    frustum_indexes = Array.make_matrix 4 6 0;
    framecount = 0;
    visframecount = 0;
    oldviewleaf = -1;
    currentkey = 0;
    lightstyles = Array.make 256 264;
    time = 0.;
  }

let transform (v : t) (p : vec) : vec =
  { x = dot p v.vright; y = dot p v.vup; z = dot p v.vpn }

let transform_frustum (v : t) : unit =
  Array.iteri
    (fun (i : int) (n : vec) ->
      (* (into the world: the view's y up, z forward, and its x the
       * other way, as id's screenedge has it) *)
      let w =
        add (scale (-.n.x) v.vright) (add (scale n.y v.vup) (scale n.z v.vpn))
      in
      v.clips.(i).cnormal <- w;
      v.clips.(i).cdist <- dot v.modelorg w)
    v.screenedge

let minmax (mins : vec) (maxs : vec) (k : int) : float =
  match k with
  | 0 -> mins.x
  | 1 -> mins.y
  | 2 -> mins.z
  | 3 -> maxs.x
  | 4 -> maxs.y
  | _ -> maxs.z

let setup (v : t) (origin : vec) (pitch : float) (yaw : float) : unit =
  let f, r, u = angle_vectors pitch yaw in
  v.origin <- origin;
  v.modelorg <- origin;
  v.vpn <- f;
  v.vright <- r;
  v.vup <- u;
  v.framecount <- v.framecount + 1;
  transform_frustum v;
  (* for each plane, the box's corner farthest out of it first (if it
   * is out, so is the box) then the farthest in (if it is in, the box
   * needs no clip by that plane) *)
  Array.iteri
    (fun (i : int) (c : clip) ->
      let idx = v.frustum_indexes.(i) in
      List.iteri
        (fun (j : int) (n : float) ->
          if n < 0. then begin
            idx.(j) <- j;
            idx.(j + 3) <- j + 3
          end
          else begin
            idx.(j) <- j + 3;
            idx.(j + 3) <- j
          end)
        [ c.cnormal.x; c.cnormal.y; c.cnormal.z ])
    v.clips

let styles =
  [
    (0, "m");
    (1, "mmnmmommommnonmmonqnmmo");
    (2, "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba");
    (3, "mmmmmaaaaammmmmaaaaaabcdefgabcdefg");
    (4, "mamamamamama");
    (5, "jklmnopqrstuvwxyzyxwvutsrqponmlkj");
    (6, "nmonqnmomnmomomno");
    (7, "mmmaaaabcdefgmmmmaaaammmaamm");
    (8, "mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa");
    (9, "aaaaaaaazzzzzzzz");
    (10, "mmamammmmammamamaaamammma");
    (11, "abcdefghijklmnopqrrqponmlkjihgfedcba");
    (63, "a");
  ]

let animate_lights (v : t) (strings : string array) : unit =
  let i = int_of_float (v.time *. 10.) in
  Array.iteri
    (fun (j : int) (s : string) ->
      if s = "" then v.lightstyles.(j) <- 256
      else
        v.lightstyles.(j) <-
          (Char.code s.[i mod String.length s] - Char.code 'a') * 22)
    strings
