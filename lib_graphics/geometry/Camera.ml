(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/graphics/3d/geometry/
 * Camera.ml (docs/plans/plan_virtuaracing.md);
 * [basis]'s [up] not optional (mini-ml has no optional arguments) *)

(* See Camera.mli *)

type t = {
  eye : Vec3.t;
  target : Vec3.t;
  up : Vec3.t;
  fov : float;
  ortho : float;
  near : float;
  far : float;
}

(* the world's "up" *)
let up_hint : Vec3.t = (0., 1., 0.)

let basis ~(up : Vec3.t) ~(eye : Vec3.t) ~(target : Vec3.t) :
    Vec3.t * Vec3.t * Vec3.t =
  let forward = Vec3.normalize (Vec3.sub target eye) in
  let right = Vec3.normalize (Vec3.cross forward up) in
  let up = Vec3.cross right forward in
  (right, up, forward)

let view (camera : t) (point : Vec3.t) : Vec3.t =
  let right, up, forward =
    basis ~up:camera.up ~eye:camera.eye ~target:camera.target in
  let relative = Vec3.sub point camera.eye in
  ( Vec3.dot relative right,
    Vec3.dot relative up,
    Vec3.dot relative forward )

let focal (camera : t) : float =
  1. /. tan (camera.fov *. Float.pi /. 180. /. 2.)

let ndc (camera : t) ~(aspect : float) ((x, y, z) : Vec3.t) :
    (float * float) option =
  if z < camera.near || z >= camera.far then None
  else if camera.ortho > 0. then
    (* no perspective at all: the depth is used to decide what is drawn
     * and what is in front, and for nothing else *)
    let h = camera.ortho /. 2. in
    Some (x /. aspect /. h, y /. h)
  else
    let f = focal camera in
    Some (f *. x /. aspect /. z, f *. y /. z)
