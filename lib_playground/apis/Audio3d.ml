(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Audio3d.mli *)

(* ix: the author's playground's playground/apis/Audio3d.ml; the listener from an eye, a target and an up, or a yaw ([facing]), where from a Playground3d.camera; the optional arguments said *)

open Playground

type listener = { position : Space.vec; right : Space.vec; velocity : Space.vec }

let vec ((x, y, z) : number * number * number) : Space.vec = Space.vec x y z

let normalize (v : Space.vec) : Space.vec =
  let n = sqrt ((v.x *. v.x) +. (v.y *. v.y) +. (v.z *. v.z)) in
  if n = 0. then v else Space.vec (v.x /. n) (v.y /. n) (v.z /. n)

(* ahead x up: the right, for a camera looking along -z with +y up, +x *)
let cross (a : Space.vec) (b : Space.vec) : Space.vec =
  Space.vec ((a.y *. b.z) -. (a.z *. b.y)) ((a.z *. b.x) -. (a.x *. b.z)) ((a.x *. b.y) -. (a.y *. b.x))

let listener ~(velocity : number * number * number) ~(eye : number * number * number)
    ~(target : number * number * number) ~(up : number * number * number) : listener =
  let eye = vec eye and target = vec target in
  let ahead = normalize (Space.vec (target.x -. eye.x) (target.y -. eye.y) (target.z -. eye.z)) in
  { position = eye; right = normalize (cross ahead (vec up)); velocity = vec velocity }

(* (ahead (cos a, sin a, 0) crossed with up (0, 0, 1): (sin a, -cos a, 0)) *)
let facing ~(velocity : number * number * number) (eye : number * number * number) (angle : number) : listener =
  { position = vec eye; right = Space.vec (sin angle) (-.cos angle) 0.; velocity = vec velocity }

let pan (ears : listener) (position : number * number * number) : number =
  Space.direction ~listener:ears.position ~right:ears.right (vec position)

let heard (ears : listener) ~(velocity : number * number * number) ~(reference : number)
    ~(speed_of_sound : number) (position : number * number * number) (s : Audio.sound) : Audio.sound =
  let source = vec position in
  let d = Space.distance ears.position source in
  let doppler =
    Space.doppler ~speed_of_sound ~listener:ears.position ~listener_velocity:ears.velocity ~source
      ~source_velocity:(vec velocity)
  in
  let cutoff = Space.air_cutoff d in
  (if cutoff < 20000. then Audio.low_pass cutoff s else s)
  |> Audio.pitched doppler |> Audio.faster doppler
  |> Audio.louder (Space.attenuation ~reference d)
  |> Audio.pan (pan ears position)
