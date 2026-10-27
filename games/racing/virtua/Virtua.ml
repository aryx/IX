(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-virtuaracing: Virtua Racing (Yu Suzuki, Sega AM2, 1992), the
 * arcade's first great polygon racer, as a program of ix's playground,
 * drawn by a renderer of its own: flat faces, a depth for each pixel,
 * a byte a pixel (docs/plans/plan_virtuaracing.md). The author's
 * playground's TinyVirtuaRacing is its inspiration: its courses, its
 * cars, its rules.
 *
 * Stage 3 of the plan, under way: the title (the grid, a camera going
 * round the player's car), the course select (the course's miniature
 * turning on a table), the race on Big Forest (the countdown, fifteen
 * rivals, the clock and its checkpoints, five laps, the race's display)
 * and its end (GOAL!, or GAME OVER when the clock runs out); the
 * sound (Sound: the V12 through its gears, the tyres, the countdown,
 * the checkpoints' jingles). Not yet the coast.
 *
 *   the keys: space (from the title, to race, after it), left and right
 *   (the course; the wheel), up (the gas), down (the brake), v the view
 *   (close behind, behind and above, high overhead, in the cockpit:
 *   V.R.'s four buttons)
 *
 *   usage: mini-virtuaracing [view=close|behind|overhead|cockpit]
 *                            [picture=WxH] [scale=n] [stats] [cull=off]
 *                            [course=n] [sound=off] [lod=off]
 *     view=     the view at the start (default: close)
 *     picture=  the picture's size in pixels (default: 320x240), each
 *               made n by n on the screen (scale=, 1 to 4; 2 by
 *               default; on Plan 9 the window's largest whole n)
 *     stats     each frame's faces drawn and the race (its time, the
 *               clock, the car's distance, speed, place, lap), on the
 *               standard error
 *     cull=off  the faces turned away drawn too (Render.cull)
 *     course=n  a race on the n-th course at once (0: Big Forest), not
 *               the title (the frames' sessions)
 *     sound=off no sound made (Sound.on)
 *     lod=off   the far road chunks drawn whole too (Course.lod)
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

type scene = Title | Select of int | Racing | Finished

(* a course built, its palette made and its meshes lit; its miniature
 * once the course select asks for it *)
type loaded = {
  course : Course.t;
  palette : Palette.t;
  mutable miniature : Mesh.t option;
}

type model = {
  (* the courses, each built the first time it is needed *)
  catalog : (unit -> Course.t) array;
  loaded : loaded option array;
  mutable current : int;
  render : Render.t;
  (* the player's car, and braking; the rivals', by the grid's order *)
  player_car : Mesh.t * Mesh.t;
  rival_cars : Mesh.t array;
  mutable race : Race.t;
  mutable braking : bool;
  mutable scenes : scene Scene2d.t;
  (* two pictures' bytes, one a frame in turn (mini-doom's screens: the
   * platform keeps a picture it has shown by the value) *)
  screens : Bytes.t array;
  mutable frames : int;
  mutable view : view;
  (* stats: each frame's faces and the race said there *)
  stats : (string -> unit) option;
}

let radians (d : float) : float = d *. Float.pi /. 180.

let lens (eye : Vec3.t) (target : Vec3.t) (fov : float) : Camera.t =
  { eye; target; up = Camera.up_hint; fov; ortho = 0.; near = 0.1; far = 2000. }

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
  lens
    (x -. (back *. fx), y +. height, z -. (back *. fz))
    (x +. (ahead *. fx), y +. look, z +. (ahead *. fz))
    (60. +. (10. *. speed))

(* Camera3d.orbit: [distance] from (x, y, z) at [angle] round it,
 * [height] above, looking at [look] above it *)
let orbit (distance : float) (height : float) (look : float) (angle : float)
    ((x, y, z) : Vec3.t) : Camera.t =
  let a = radians angle in
  lens
    (x +. (distance *. sin a), y +. height, z +. (distance *. cos a))
    (x, y +. look, z)
    60.

(* the course select's table, under the miniature *)
let table = Mesh.rgb 40 80 50

(* the course's palette: its faces, what moves, the sky (over the land
 * and over the course select's table), the miniature's road, the cars
 * at every brightness; its meshes lit *)
let build (course : Course.t) (cars : Mesh.t list) (sky : Camera.t) : loaded =
  let palette = Palette.create () in
  let statics = Course.meshes course in
  List.iter (Palette.add_mesh palette) statics;
  List.iter
    (fun (s : Mesh.shape) -> Palette.add_mesh palette (Mesh.make s))
    (course.animated 0.);
  Palette.add_mesh palette (Mesh.make (Course.sky course sky));
  Palette.add_mesh palette (Mesh.make (Course.sky_over sky (-40.) table));
  List.iter
    (fun (c : Mesh.color) -> Palette.add_all_levels palette c)
    [ Mesh.white; Mesh.rgb 90 90 95; table ];
  List.iter
    (fun (mesh : Mesh.t) ->
      Array.iter (Palette.add_all_levels palette) mesh.colors)
    cars;
  Palette.make palette;
  List.iter
    (fun (mesh : Mesh.t) -> Mesh.light mesh (Palette.index palette))
    (statics @ Course.far_meshes course);
  { course; palette; miniature = None }

let load (m : model) (i : int) : loaded =
  match m.loaded.(i) with
  | Some l -> l
  | None ->
      let course = m.catalog.(i) () in
      let race = Race.start course in
      let l =
        build course
          (fst m.player_car :: snd m.player_car :: Array.to_list m.rival_cars)
          (camera m.view 0. (Driving.world course race.drive))
      in
      m.loaded.(i) <- Some l;
      l

let lit (l : loaded) (shape : Mesh.shape) : Mesh.t =
  let mesh = Mesh.make shape in
  Mesh.light mesh (Palette.index l.palette);
  mesh

(* the course round the eye: its sky, land, road near [s], landmarks,
 * what moves; the cars of [race] (the player's but from its cockpit) *)
let draw_course (m : model) (l : loaded) (cam : Camera.t) (time : float)
    (race : Race.t) : unit =
  let c = l.course and r = m.render in
  let d = race.drive in
  let sky = lit l (Course.sky c cam) in
  Render.frame r cam (Char.code (Bytes.get sky.shades 1));
  Render.draw r sky;
  List.iter (Render.draw r) (Course.land_near c cam.eye);
  List.iter (Render.draw r) (Course.road_near c d.s cam.eye);
  List.iter (Render.draw r) c.landmarks;
  List.iter (fun (s : Mesh.shape) -> Render.draw r (lit l s)) (c.animated time);
  let index = Palette.index l.palette in
  let (x, y, z), heading = Driving.world c d in
  (* (the player's own car not drawn from its cockpit) *)
  if m.view <> Cockpit || m.scenes.scene = Title then
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

(* the race's camera: following the car's heading, not its spin; off
 * the road, and against the rail, shaking with the car *)
let race_camera (m : model) (c : Course.t) (race : Race.t) : Camera.t =
  let d = race.drive in
  let at, heading = Driving.world c d in
  let follow = if d.spin > 0 then 90. -. d.car.heading else heading in
  let cam =
    camera m.view (Float.abs d.car.speed /. Driving.top_speed) (at, follow)
  in
  let shake =
    (if Float.abs d.offset > 1.15 *. Course.road_width then
       0.12 *. Float.abs d.car.speed /. Driving.top_speed
     else 0.)
    +. if d.bump < 12 then 0.3 *. float_of_int (12 - d.bump) /. 12. else 0.
  in
  let ex, ey, ez = cam.eye in
  {
    cam with
    eye = (ex, ey +. (shake *. sin (float_of_int race.time *. 2.1)), ez);
  }

(* the scene's picture drawn, and what goes over it *)
let draw (computer : P.computer) (m : model) (time : float) :
    loaded * P.shape list =
  (* the playground's texts are placed for a screen 1000 high: drawn on
   * one (as wide as the window's proportions), then scaled to the
   * window ([view]) *)
  let s = m.scenes in
  let screen =
    P.to_screen (computer.screen.width *. 1000. /. computer.screen.height) 1000.
  in
  let blink (period : float) : P.shape list -> P.shape list =
    Scene2d.blink period s
  in
  match s.scene with
  | Title ->
      let l = load m 0 in
      let r = Race.start l.course in
      let at, _ = Driving.world l.course r.drive in
      draw_course m l (orbit 11. 3.5 0.8 (Course.spin 12. time) at) time r;
      (l, Screens.title (blink 1.))
  | Select i ->
      (* the course on a table, turning, seen from above and aside *)
      let l = load m i in
      let cam = orbit 110. 105. 0. (Course.spin 10. time) (0., 0., 0.) in
      let mini =
        match l.miniature with
        | Some mesh -> mesh
        | None ->
            let mesh = lit l (Course.miniature l.course) in
            l.miniature <- Some mesh;
            mesh
      in
      let r = m.render in
      let sky = lit l (Course.sky_over cam (-40.) table) in
      Render.frame r cam (Char.code (Bytes.get sky.shades 1));
      Render.draw r sky;
      Render.draw r mini;
      List.iter
        (fun (sh : Mesh.shape) ->
          Render.draw r (lit l (Course.shrink l.course sh)))
        (l.course.animated time);
      (l, Screens.select screen (blink 1.) l.course)
  | Racing ->
      let l = load m m.current in
      draw_course m l (race_camera m l.course m.race) time m.race;
      (l, Screens.race screen (blink 0.3) l.course m.race)
  | Finished ->
      let l = load m m.current in
      draw_course m l (race_camera m l.course m.race) time m.race;
      (l, Screens.finished (blink 1.) l.course m.race)

let view (computer : P.computer) (m : model) : P.shape list =
  let (P.Time now) = computer.time in
  let l, over = draw computer m now in
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
           (Race.lap l.course r.drive + 1)
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
          palette = Palette.colors l.palette;
        };
    ]
  @ [ P.group over |> P.scale (screen.height /. 1000.) ]

let start_race (m : model) (i : int) : unit =
  m.current <- i;
  m.race <- Race.start (load m i).course;
  m.braking <- false

let update (computer : P.computer) (m : model) : model =
  let s = Scene2d.update computer m.scenes in
  let k = computer.keyboard in
  let space = Scene2d.pressed (fun (k : P.keyboard) -> k.kspace) s in
  let keys : Race.keys =
    { up = k.kup; down = k.kdown; left = k.kleft; right = k.kright }
  in
  (* a frame of the race, and its sound in the playground's order: a
   * gear's change and a crash, the engine and the road, the countdown
   * and the checkpoints' (before the start, the engine revs with the
   * pedal, the car held) *)
  let drive () =
    if Scene2d.pressed (fun (k : P.keyboard) -> Set_.mem "v" k.keys) s then
      m.view <- next_view m.view;
    let c = (load m m.current).course and before = m.race in
    let race, events = Race.step c keys before in
    let first, rest =
      List.partition
        (fun (e : Race.event) ->
          match e with
          | Shift | Crash -> true
          | _ -> false)
        events
    in
    List.iter Sound.event first;
    let rpm =
      if before.time < 0 then
        if k.kup then 0.7 +. (0.2 *. P.wave 0. 1. 0.3 computer.time) else 0.2
      else Race.revs race.drive
    in
    Sound.engine rpm
      (k.kup && not before.finished)
      (Course.in_span c.spans [ Tunnel ] (Driving.wrap c race.drive.s) <> None);
    Sound.road race.drive;
    List.iter Sound.event rest;
    m.race <- race;
    m.braking <- k.kdown || race.finished
  in
  m.scenes <-
    (match s.scene with
    | Title -> if space then Scene2d.go (Select 0) s else s
    | Select i ->
        let n = Array.length m.catalog in
        let left = Scene2d.pressed (fun (k : P.keyboard) -> k.kleft) s
        and right = Scene2d.pressed (fun (k : P.keyboard) -> k.kright) s in
        if left || right then Sound.play Sound.pick;
        if space then (
          Sound.play Sound.go_beep;
          start_race m i;
          Scene2d.go Racing s)
        else if left then Scene2d.go (Select ((i + n - 1) mod n)) s
        else if right then Scene2d.go (Select ((i + 1) mod n)) s
        else s
    | Racing ->
        drive ();
        if m.race.finished then Scene2d.go Finished s else s
    | Finished ->
        drive ();
        if space then Scene2d.go (Select m.current) s else s);
  m

(* the cars' meshes; the first course built (the title's, or [course]'s:
 * a race on it at once, not the title, for the frames' sessions) *)
let start (view : view) (width : int) (height : int) (course : int option)
    (stats : (string -> unit) option) : model =
  let catalog = [| Course.big_forest; Course.bay_bridge; Course.acropolis |] in
  let red = Mesh.rgb 220 30 40 in
  let player_car =
    (Mesh.make (Cars.model red false), Mesh.make (Cars.model red true))
  and rival_cars =
    Array.init (Array.length Cars.liveries) (fun (k : int) ->
        Mesh.make (Cars.model Cars.liveries.(k) false))
  in
  let first =
    match course with
    | None -> 0
    | Some i when i >= 0 && i < Array.length catalog -> i
    | Some i -> failwith (Printf.sprintf "no course %d" i)
  in
  let c = catalog.(first) () in
  let race = Race.start c in
  let loaded = Array.make (Array.length catalog) None in
  loaded.(first) <-
    Some
      (build c
         (fst player_car :: snd player_car :: Array.to_list rival_cars)
         (camera view 0. (Driving.world c race.drive)));
  {
    catalog;
    loaded;
    current = first;
    render = Render.create width height;
    player_car;
    rival_cars;
    race;
    braking = false;
    scenes = Scene2d.start (if course = None then Title else Racing);
    screens = [| Bytes.create (width * height); Bytes.create (width * height) |];
    frames = 0;
    view;
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
         if flag "sound" = Some "off" then Sound.on := false;
         if flag "lod" = Some "off" then Course.lod := false;
         let course = Option.bind (flag "course") int_of_string_opt in
         let model = start first width height course stats in
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
