(* Sound in a 3D world: heard from the camera (audio/Space.mli).

   The camera is the listener: its eye the ears, its target straight
   ahead, its right the right ear's side (the direction ahead crossed
   with its up). A sound made somewhere in the world is then

   - panned by the sine of its angle from straight ahead, and, played
     once, its far ear a little later (the time between the ears);
   - quieter with the distance, half as loud each time it doubles
     beyond [reference] (10 by default);
   - duller with the distance, the air taking its highs (a low-pass at
     Space.air_cutoff: nothing within 7.9, 4 kHz at 130);
   - higher coming, lower going (Doppler), when the listener or the
     source moves: their velocities, in world units a second.

   The world's units are taken as meters, and the speed of sound as 343
   of them a second, unless [speed_of_sound] says otherwise:

     let ears = Audio3d.listener ~velocity:(0., 0., -34.) camera in
     Audio.play (Audio.explosion |> Audio3d.heard ears (x, y, z))
     Audio.keep_playing "engine"
       (Audio.sawtooth 90. |> Audio3d.heard ears ~velocity:(vx, vy, vz) (x, y, z))

   (For a sound kept playing, its length and the Doppler's squeeze are
   ignored, its pitch shifted: Audio.pitched.) *)

(* ix: the author's playground's playground/apis/Audio3d.mli; ix has no
   Playground3d: the listener is made from the camera's eye, target and
   up ([listener]), or from an eye turned by a yaw in a world whose z is
   up ([facing]: Doom's, Quake's); the optional arguments are said *)

open Playground

type listener

(* [listener ~velocity ~eye ~target ~up]: the ears, from a camera
   looking from [eye] at [target], [up] its up; [velocity], (0, 0, 0) in
   the playground's default, the camera's own motion, for Doppler *)
val listener :
  velocity:number * number * number ->
  eye:number * number * number ->
  target:number * number * number ->
  up:number * number * number ->
  listener

(* [facing ~velocity eye angle]: the ears at [eye] turned [angle]
   radians from the x axis towards the y axis, the z axis up: Doom's and
   Quake's worlds, where a player turns and does not tilt its head
   (angle 0 looks along x, and the right is towards -y):
     let ears = Audio3d.facing ~velocity:(0., 0., 0.) (p.x, p.y, p.viewz) p.angle *)
val facing : velocity:number * number * number -> number * number * number -> number -> listener

(* [heard ears ~velocity ~reference ~speed_of_sound position s]: [s],
   made at [position] by a source moving at [velocity], as the listener
   hears it (see the top; the playground's defaults: (0, 0, 0), 10 and
   343) *)
val heard :
  listener ->
  velocity:number * number * number ->
  reference:number ->
  speed_of_sound:number ->
  number * number * number ->
  Audio.sound ->
  Audio.sound

(* [pan ears position]: the pan [heard] gives, -1 left to 1 right, for
   tests and displays *)
val pan : listener -> number * number * number -> number
