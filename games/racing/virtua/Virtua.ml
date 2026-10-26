(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-virtuaracing: Virtua Racing (Yu Suzuki, Sega AM2, 1992), the
 * arcade's first great polygon racer, as a program of ix's playground,
 * drawn by a renderer of its own: flat faces, a depth for each pixel,
 * a byte a pixel (docs/plans/plan_virtuaracing.md). The author's
 * playground's TinyVirtuaRacing is its inspiration: its courses, its
 * cars, its rules.
 *
 * Stage 1 of the plan, the course still: Big Forest, its road, land and
 * landmarks, the sixteen cars on the grid, seen from the player's car
 * as the countdown would show it. No race yet.
 *
 *   the keys: v the view (behind and above, high overhead, in the
 *   cockpit, close behind: V.R.'s four buttons)
 *
 *   usage: mini-virtuaracing [view=close|behind|overhead|cockpit]
 *                            [picture=WxH] [scale=n] [stats] [cull=off]
 *     view=     the view at the start (default: close)
 *     picture=  the picture's size in pixels (default: 320x240), each
 *               made n by n on the screen (scale=, 1 to 4; 2 by
 *               default; on Plan 9 the window's largest whole n)
 *     stats     each frame's faces drawn and the race (its time, the
 *               clock, the car's distance, speed, place, lap), on the
 *               standard error
 *     cull=off  the faces turned away drawn too (Render.cull)
 *
 * A frame:
 *
 *    the course's meshes near the eye            the picture
 *    (Course: land tiles, road chunks,  --> Render: cull, turn, cut,
 *     landmarks; what moves; the cars)      project, fill by spans
 *                                                  |
 *          Bitmap <-- the course's Palette <-- width x height bytes
 *
 * history:
 * Virtua Racing ran on Sega's Model 1 board: a V60 processor for the
 * game, and five DSPs of Fujitsu's for the geometry, 180,000 polygons
 * a second at 30 frames. Its home version (the Mega Drive's, 1994) had
 * a chip in the cartridge for the same work (the SVP), at a fraction of
 * the polygons and of the frames; the Saturn's and the 32X's
 * followed. Here, a Pi 2's processor alone (plan_virtuaracing.md: the
 * budget of a frame). *)

module P = Playground

type view = Close | Behind | Overhead | Cockpit

let next_view (v : view) : view =
  match v with
  | Close -> Behind
  | Behind -> Overhead
  | Overhead -> Cockpit
  | Cockpit -> Close

type model = {
  course : Course.t;
  palette : Palette.t;
  render : Render.t;
  (* the player's car, and braking; each rival's, as Rivals.grid *)
  player_car : Mesh.t * Mesh.t;
  rival_cars : Mesh.t array;
  mutable race : Race.t;
  mutable braking : bool;
  (* two pictures' bytes, one a frame in turn (mini-doom's screens: the
   * platform keeps a picture it has shown by the value) *)
  screens : Bytes.t array;
  mutable frames : int;
  mutable view : view;
  mutable v_held : bool;
  (* stats: each frame's faces said there *)
  stats : (string -> unit) option;
}

let radians (d : float) : float = d *. Float.pi /. 180.

(* Camera3d.behind: [back] behind the car and [height] above it,
 * looking at [look] above the road [ahead] of it; a wider angle at
 * speed (the fraction of the top speed): the road rushes past the
 * edges *)
let camera (view : view) (speed : float) (((x, y, z), heading) : Vec3.t * float)
    : Camera.t =
  let back, height, ahead, look =
    match view with
    | Cockpit -> (0.1, 1.3, 20., 0.4)
    | Close -> (7.5, 2.6, 8., 1.)
    | Behind -> (14., 6.5, 12., 1.)
    | Overhead -> (22., 34., 16., 0.)
  in
  let fx = sin (radians heading) and fz = -.cos (radians heading) in
  {
    eye = (x -. (back *. fx), y +. height, z -. (back *. fz));
    target = (x +. (ahead *. fx), y +. look, z +. (ahead *. fz));
    up = Camera.up_hint;
    fov = 60. +. (10. *. speed);
    ortho = 0.;
    near = 0.1;
    far = 2000.;
  }

let lit (m : model) (shape : Mesh.shape) : Mesh.t =
  let mesh = Mesh.make shape in
  Mesh.light mesh (Palette.index m.palette);
  mesh

let draw_scene (m : model) (time : float) : unit =
  let c = m.course and race = m.race in
  let d = race.drive in
  let (x, y, z), heading = Driving.world c d in
  (* the camera follows the car's heading, not its spin; off the road,
   * and against the rail, it shakes with the car *)
  let follow = if d.spin > 0 then 90. -. d.car.heading else heading in
  let cam =
    camera m.view
      (Float.abs d.car.speed /. Driving.top_speed)
      ((x, y, z), follow)
  in
  let shake =
    (if Float.abs d.offset > 1.15 *. Course.road_width then
       0.12 *. Float.abs d.car.speed /. Driving.top_speed
     else 0.)
    +. if d.bump < 12 then 0.3 *. float_of_int (12 - d.bump) /. 12. else 0.
  in
  let cam : Camera.t =
    let ex, ey, ez = cam.eye in
    {
      cam with
      eye = (ex, ey +. (shake *. sin (float_of_int race.time *. 2.1)), ez);
    }
  in
  let r = m.render in
  let sky = lit m (Course.sky m.course cam) in
  Render.frame r cam (Char.code (Bytes.get sky.shades 1));
  Render.draw r sky;
  List.iter (Render.draw r) (Course.land_near m.course cam.eye);
  List.iter (Render.draw r) (Course.road_near m.course d.s cam.eye);
  List.iter (Render.draw r) m.course.landmarks;
  List.iter
    (fun (s : Mesh.shape) -> Render.draw r (lit m s))
    (m.course.animated time);
  let index = Palette.index m.palette in
  (* (the player's own car not drawn from its cockpit) *)
  if m.view <> Cockpit then
    Render.draw_at r
      (if m.braking then snd m.player_car else fst m.player_car)
      (-.heading) (x, y, z) index;
  let ex, _, ez = cam.eye in
  List.iteri
    (fun (k : int) (rv : Rivals.t) ->
      let ((rx, _, rz) as at), h = Rivals.place c rv in
      if Float.hypot (rx -. ex) (rz -. ez) <= 350. then
        Render.draw_at r m.rival_cars.(k) (-.h) at index)
    race.rivals

let view (computer : P.computer) (m : model) : P.shape list =
  let (P.Time now) = computer.time in
  draw_scene m now;
  Option.iter
    (fun (say : string -> unit) ->
      say
        (let r = m.race in
         Printf.sprintf
           "frame %d: %d faces; time %d, clock %d, %.1f m, %.0f km/h, %s, lap \
            %d%s\n"
           m.frames
           (Render.faces_drawn m.render)
           r.time r.clock r.drive.s
           (Driving.kmh r.drive.car.speed)
           (Rivals.ordinal (Rivals.position r.drive r.rivals))
           (Race.lap m.course r.drive + 1)
           (if r.over then ", over" else if r.finished then ", goal" else "")))
    m.stats;
  m.frames <- m.frames + 1;
  let src = Render.pixels m.render and dst = m.screens.(m.frames land 1) in
  Bytes.blit src 0 dst 0 (Bytes.length src);
  let screen = computer.screen in
  let pw = float (Render.width m.render)
  and ph = float (Render.height m.render) in
  let w = Float.min screen.width (screen.height *. pw /. ph) in
  let h = w *. ph /. pw in
  (if h < screen.height || w < screen.width then
     [ P.rectangle (P.rgb 96 96 96) screen.width screen.height ]
   else [])
  @ [
      P.pixels w h
        {
          pwidth = Render.width m.render;
          pheight = Render.height m.render;
          indices = dst;
          palette = Palette.colors m.palette;
        };
    ]

let update (computer : P.computer) (m : model) : model =
  let k = computer.keyboard in
  let v = Set_.mem "v" k.keys in
  if v && not m.v_held then m.view <- next_view m.view;
  m.v_held <- v;
  let keys : Race.keys =
    { up = k.kup; down = k.kdown; left = k.kleft; right = k.kright }
  in
  (* (the race's events are the sound's, stage 4) *)
  let race, _ = Race.step m.course keys m.race in
  m.race <- race;
  m.braking <- k.kdown || race.finished;
  m

(* the course, its palette made from its faces and the cars', its
 * meshes lit *)
let start (view : view) (width : int) (height : int)
    (stats : (string -> unit) option) : model =
  let course = Course.big_forest () in
  let race = Race.start course in
  let red = Mesh.rgb 220 30 40 in
  let player_car =
    (Mesh.make (Cars.model red false), Mesh.make (Cars.model red true))
  in
  let rival_cars =
    Array.of_list
      (List.map
         (fun (rv : Rivals.t) -> Mesh.make (Cars.model rv.livery false))
         race.rivals)
  in
  let palette = Palette.create () in
  let statics = Course.meshes course in
  List.iter (Palette.add_mesh palette) statics;
  List.iter
    (fun (s : Mesh.shape) -> Palette.add_mesh palette (Mesh.make s))
    (course.animated 0.);
  Palette.add_mesh palette
    (Mesh.make
       (Course.sky course (camera view 0. (Driving.world course race.drive))));
  List.iter
    (fun (mesh : Mesh.t) ->
      Array.iter (Palette.add_all_levels palette) mesh.colors)
    (fst player_car :: snd player_car :: Array.to_list rival_cars);
  Palette.make palette;
  List.iter
    (fun (mesh : Mesh.t) -> Mesh.light mesh (Palette.index palette))
    statics;
  {
    course;
    palette;
    render = Render.create width height;
    player_car;
    rival_cars;
    race;
    braking = false;
    screens = [| Bytes.create (width * height); Bytes.create (width * height) |];
    frames = 0;
    view;
    v_held = false;
    stats;
  }

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch
      @@ fun () ->
      (try
         let flags = Playground_platform.flags caps in
         let flag (name : string) : string option = List.assoc_opt name flags in
         let first =
           match flag "view" with
           | Some "behind" -> Behind
           | Some "overhead" -> Overhead
           | Some "cockpit" -> Cockpit
           | Some "close" | None -> Close
           | Some v -> failwith ("no view " ^ v)
         in
         let width, height =
           match Option.map (String.split_on_char 'x') (flag "picture") with
           | Some [ w; h ] -> (int_of_string w, int_of_string h)
           | Some _ -> failwith "picture=WxH"
           | None -> (320, 240)
         in
         let scale =
           match Option.bind (flag "scale") int_of_string_opt with
           | Some n when n >= 1 && n <= 4 -> Some n
           | _ -> if Sys.os_type = "Plan9" then None else Some 2
         in
         let stats =
           if flag "stats" <> None then Some (Console.eprint caps) else None
         in
         if flag "cull" = Some "off" then Render.cull := false;
         let model = start first width height stats in
         (* the window the picture's size, a unit a pixel; or, without
          * scale, the window whatever its size (mini-doom's) *)
         let flags =
           match (flag "window", scale) with
           | Some _, _ -> flags
           | None, Some n ->
               ("window", Printf.sprintf "%dx%d" (width * n) (height * n))
               :: flags
           | None, None -> ("window", "") :: flags
         in
         let side =
           match scale with
           | Some n -> width * n
           | None -> width
         in
         let flags =
           if flag "size" = None then ("size", string_of_int side) :: flags
           else flags
         in
         Playground_platform.run_app caps
           (("heap", "modest") :: flags)
           (P.game view update model)
       with Failure msg ->
         Console.eprint caps ("mini-virtuaracing: " ^ msg ^ "\n");
         CapStdlib.exit caps 1);
      Exit.OK)
