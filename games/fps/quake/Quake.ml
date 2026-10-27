(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-quake: Quake (id Software, 1996), its software renderer and
 * its lightmaps, as a program of ix's playground
 * (docs/plans/done/plan_quake.md). A game in a level of a .bsp --
 * LibreQuake's lq_e0m1 by default, compiled by qbsp and vis, lit by
 * tools/Light.ml (data/README.md) -- textured and lit as Quake drew
 * it, its doors, buttons, lifts and triggers working, its monsters
 * awake and fighting (Monsters, Ai), its weapons fired (Weapons), its
 * sounds heard and its music played (Sound).
 *
 *   the keys: the arrows (or w, s) walk and turn; a and d step aside;
 *   shift runs; space jumps (swims up); control (or f) fires; 1 to 7
 *   the weapons (1 the axe, 2 the shotgun, 3 the super shotgun, 4 the
 *   nailgun, 6 the grenade launcher, 7 the rocket launcher); e uses (a
 *   secret door, a button: what Quake's shot did too); page up and
 *   down look
 *
 *   usage: mini-quake [bsp=file.bsp] [scale=n]
 *            [x=X y=Y z=Z angle=A pitch=P] [lightmaps] [things=off]
 *            [gamma=g] [nomonsters] [ai=ways] [weapons=all] [sound=off|3d]
 *            [music=off|on] [graphics=only] [entities] [models=simple]
 *     bsp=   the level (default: /lib/quake/e0m1.bsp, else
 *            games/fps/quake/data/e0m1.bsp); the palette and the
 *            colormap beside it
 *     scale= each pixel made n by n (1 to 4; 2 by default; on Plan 9
 *            the window or screen, the largest whole n that fits)
 *     x= y= z= angle= pitch=  the eye put there, looking that way
 *            (degrees): a test's camera
 *     lightmaps  the textures grey: the lightmaps alone
 *     things=off  no monster nor item drawn
 *     gamma= the brightness: 1 the palette as it is (id's default) to
 *            0.3; 0.7 by default
 *     nomonsters  the level without its monsters (Quake's -nomonsters)
 *     ai=ways  the monsters find their way by the playground's AI
 *            (Ways), not QuakeC's alone (Monster_ai)
 *     weapons=all  every weapon and ammunition (Quake's impulse 9):
 *            the grenade launcher, which lq_e0m1 does not have
 *     sound= off: none; 3d: the playground's Audio3d, not Quake's
 *     music= the level's CD track, music/trackNN.ogg (worldspawn's
 *            "sounds"); off by default on Plan 9 (Vorbis's decoding by
 *            mini-ml's code)
 *     graphics=only  nomonsters things=off sound=off music=off: the
 *            renderer alone (its frames a second, the monsters' cost
 *            and the sound's apart)
 *     entities   the level's entities listed, and the end
 *     models=simple  the models' triangles by the first way, not by
 *            their gradients (Alias.gradients)
 *     precache   the models, sounds and music the game reads, listed
 *
 * A frame (the playground's view): Play's move for the time since the
 * last frame, then Render's picture of the eye, 320 by 200 bytes of
 * the palette, made the platform's pixels (each index its colour, n by
 * n), one Bitmap shape:
 *
 *          the keys                           the picture
 *   computer.keyboard --> Play.frame dt --> the eye, the doors' places
 *                                                  |
 *   Bitmap <-- the palette, n by n <-- Render.frame: 320 x 200 bytes
 *
 * history:
 * id's game ran on DOS (its renderer in C and Pentium assembly, by John
 * Carmack and Michael Abrash), then WinQuake, GLQuake (1997, OpenGL),
 * QuakeWorld; id gave the source in 1999 (GPL), and every port since
 * comes from it. chocolate-quake keeps its C paths: what these modules
 * were read beside. *)

module P = Playground
open Model

type model = {
  level : Model.t;
  render : Render.t;
  mutable play : Play.t;
  mutable game : Game.t;
  (* the level again from its start: the player dead, a key pressed *)
  restart : unit -> Play.t * Game.t;
  sound : Sound.t option;
  (* the palette reddened by a hit, 1 to 8, gilded by an item, 9 to 12
   * (Quake's color shifts, V_UpdatePalette: made once each) *)
  palettes : string array;
  (* the level's message: its name *)
  name : string;
  (* two pictures' bytes, one a frame in turn: the platform compares a
   * frame's shapes with the last's, so each frame's picture is a new
   * value, not the same bytes changed *)
  screens : Bytes.t array;
  mutable frames : int;
  status : bool; (* the status line shown *)
  mutable last : float;
}

(* the picture as it is, 320 by 200 bytes of the palette, given to the
 * platform (a Pixels shape), which makes of it what its device wants,
 * each pixel n by n (docs/plans/done/plan_playground_framebuffer.md, F2).
 * old: made RGBA here (to_rgba), then again by the draw platform *)
let snapshot (m : model) : unit =
  let src = m.render.view.screen in
  Bytes.blit src 0 m.screens.(m.frames land 1) 0 (Bytes.length src)

(* the palettes of [palette]: towards red by a twelfth a step, towards
 * gold by a tenth *)
let palettes (base : string) : string array =
  let tint ((r, g, b) : int * int * int) (k : float) : string =
    String.init 768 (fun (i : int) ->
        let c = Char.code base.[i] in
        let to_ = match i mod 3 with 0 -> r | 1 -> g | _ -> b in
        Char.chr (c + int_of_float (k *. float (to_ - c))))
  in
  Array.init 13 (fun (i : int) ->
      if i = 0 then base
      else if i <= 8 then tint (255, 0, 0) (float i /. 12.)
      else tint (215, 186, 69) (float (i - 8) /. 10.))

let palette (m : model) : string =
  let c = m.game.world.client in
  if c.damage_count > 0. then
    m.palettes.(1 + min 7 (int_of_float (c.damage_count *. 8.)))
  else if c.bonus_count > 0. then
    m.palettes.(9 + min 3 (int_of_float (c.bonus_count *. 4.)))
  else m.palettes.(0)

(* the eye: Play's, or the floor's when dead (view_ofs '0 0 -8') *)
let eye (m : model) : vec =
  match Game.dead_for m.game with
  | Some _ -> { m.play.body.origin with z = m.play.body.origin.z -. 8. }
  | None -> Play.eye m.play

let view (computer : P.computer) (m : model) : P.shape list =
  let p = m.play in
  List.iter
    (fun (t : Things.thing) ->
      if Brushes.taken p.brushes t.classname t.origin then t.alive <- false)
    m.game.things;
  Render.frame m.render m.level (eye m) p.pitch (Play.yaw p) p.time p.styles
    (Play.bmodels p) m.game.things;
  (* the game's entities, its particles, the weapon in hand *)
  Game.draw m.game m.render.view;
  m.frames <- m.frames + 1;
  snapshot m;
  let screen = computer.screen in
  let v = m.render.view in
  let w =
    Float.min screen.width (screen.height *. float v.width /. float v.height)
  in
  let h = w *. float v.height /. float v.width in
  let text (s : string) (y : float) : P.shape =
    P.words P.white s |> P.scale 2. |> P.move 0. y
  in
  (if h < screen.height || w < screen.width then
     [ P.rectangle (P.rgb 96 96 96) screen.width screen.height ]
   else [])
  @ [
      P.pixels w h
        {
          pwidth = v.width;
          pheight = v.height;
          indices = m.screens.(m.frames land 1);
          palette = palette m;
        };
    ]
  @ (if m.status then [ text (Game.status m.game) (20. -. (h /. 2.)) ] else [])
  @ (match m.game.world.message with
    | Some (s, at) when p.time -. at < 2. -> [ text s ((h /. 4.) -. 20.) ]
    | _ -> [])
  @ (match Game.dead_for m.game with
    | Some _ -> [ text "Press jump to play again" 0. ]
    | None -> [])
  (* (a door's, a trigger's message, for 2 seconds: Quake's centerprint) *)
  @ (match Brushes.message p.brushes with
    | Some (s, at) when p.time -. at < 2. -> [ text s (h /. 4.) ]
    | _ -> [])
  @
  if Brushes.exited p.brushes then
    let found, total = Brushes.secrets p.brushes in
    [
      text
        (Printf.sprintf "%s finished: %d of %d secrets" m.name found total)
        0.;
    ]
  else []

let update (computer : P.computer) (m : model) : model =
  let (P.Time now) = computer.time in
  if m.last = 0. || now -. m.last > 0.5 then m.last <- now;
  let dt = Float.min 0.1 (now -. m.last) in
  m.last <- now;
  let k = computer.keyboard in
  let held (name : string) : bool = Set_.mem name k.keys in
  let alive = Game.dead_for m.game = None in
  Play.frame m.play dt
    {
      forward = alive && (k.kup || k.kw);
      back = alive && (k.kdown || k.ks);
      left = alive && k.kleft;
      right = alive && k.kright;
      strafe_left = alive && k.ka;
      strafe_right = alive && k.kd;
      jump = alive && k.kspace;
      run = k.kshift;
      look_up = held "pageup";
      look_down = held "pagedown";
      use_key = alive && held "e";
    };
  let impulse =
    match List.find_opt held [ "1"; "2"; "3"; "4"; "6"; "7" ] with
    | Some n -> int_of_string n
    | None -> 0
  in
  Game.frame m.game dt (held "Control" || held "f") impulse;
  (match m.sound with
  | Some s -> Sound.play s (Game.sounds m.game) (eye m) (Play.yaw m.play)
  | None -> ignore (Game.sounds m.game));
  (* dead a second, then jump: the level again (single player's
   * respawn: the map reloaded) *)
  (match Game.dead_for m.game with
  | Some t when t > 1. && k.kspace ->
      let play, game = m.restart () in
      m.play <- play;
      m.game <- game
  | _ -> ());
  m

(* The palette made brighter (id's BuildGammaTable, vid.c): each
 * component c becomes 255 ((c + 0.5) / 255.5)^gamma. Quake's Options
 * menu's Brightness was this, from 1 (the palette as it is, id's
 * default) to 0.5; it changes no pixel's index, only the colours shown,
 * so it costs nothing a frame. 0.7 by default here: LibreQuake's map
 * was lit by ericw-tools for brighter rooms than tools/Light.ml's (the
 * author, 2026-10-22: "many zones seems still very dark (it's actually
 * hard to see some dogs in the shadow)"). *)
let default_gamma = 0.7

let with_gamma (g : float) (c : int) : int =
  if g = 1. then c
  else
    max 0
      (min 255
         (int_of_float ((255. *. (((float c +. 0.5) /. 255.5) ** g)) +. 0.5)))

let default_bsps = [ "/lib/quake/e0m1.bsp"; "games/fps/quake/data/e0m1.bsp" ]

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch
      @@ fun () ->
      (try
         let flags = Playground_platform.flags caps in
         (* graphics=only: the renderer alone, as the game was before its
          * things, monsters and sound: a frame rate of the drawing only *)
         let flags =
           if List.assoc_opt "graphics" flags = Some "only" then
             [ ("nomonsters", ""); ("things", "off"); ("sound", "off");
               ("music", "off") ]
             @ flags
           else flags
         in
         let flag (name : string) : string option = List.assoc_opt name flags in
         let path =
           match flag "bsp" with
           | Some f -> f
           | None -> (
               match
                 List.find_opt
                   (fun (f : string) -> Sys.file_exists f)
                   default_bsps
               with
               | Some f -> f
               | None -> failwith "no level: bsp=file.bsp")
         in
         let level = Model.load (Bspfile.parse (FS.read caps (Fpath.v path))) in
         if flag "precache" <> None then
           (* what the game reads beside the level: its models, its
            * sounds, its music (tools/mkdata.sh copies them) *)
           List.iter
             (fun (f : string) -> Console.print caps (f ^ "\n"))
             (Monsters.models @ Weapons.models
             @ List.map
                 (fun (s : string) -> "sound/" ^ s ^ ".wav")
                 (Monsters.sounds @ Weapons.sounds @ Brushes.sound_names)
             @ [ Cdaudio.track level ])
         else if flag "entities" <> None then
           List.iter
             (fun (e : (string * string) list) ->
               Console.print caps
                 (String.concat " "
                    (List.map
                       (fun ((k, v) : string * string) ->
                         Printf.sprintf "%s=%S" k v)
                       e)
                 ^ "\n"))
             level.entities
         else begin
           let beside (f : string) : string =
             FS.read caps (Fpath.v (Filename.concat (Filename.dirname path) f))
           in
           let palette = beside "palette.lmp"
           and colormap = beside "colormap.lmp" in
           let scale =
             match Option.bind (flag "scale") int_of_string_opt with
             | Some n when n >= 1 && n <= 4 -> Some n
             (* (None: the window's size, the platform's whole multiple) *)
             | _ -> if Sys.os_type = "Plan9" then None else Some 2
           in
           let render = Render.create level colormap in
           let gamma =
             match Option.bind (flag "gamma") float_of_string_opt with
             | Some g when g >= 0.3 && g <= 1. -> g
             | _ -> default_gamma
           in
           let palette =
             String.map
               (fun (c : char) -> Char.chr (with_gamma gamma (Char.code c)))
               palette
           in
           if flag "lightmaps" <> None then Surfcache.grey := true;
           if flag "models" = Some "simple" then Alias.gradients := false;
           let place (play : Play.t) : unit =
             match
               ( Option.bind (flag "x") float_of_string_opt,
                 Option.bind (flag "y") float_of_string_opt,
                 Option.bind (flag "z") float_of_string_opt )
             with
             | Some x, Some y, Some z ->
                 let a =
                   match Option.bind (flag "angle") float_of_string_opt with
                   | Some a -> a
                   | None -> 0.
                 in
                 let pitch =
                   match Option.bind (flag "pitch") float_of_string_opt with
                   | Some a -> a
                   | None -> 0.
                 in
                 Play.place play { x; y; z } a pitch
             | _ -> ()
           in
           let read (f : string) : string option =
             FS.read_opt caps
               (Fpath.v (Filename.concat (Filename.dirname path) f))
           in
           (* (the models, read once for all the restarts) *)
           let cache = Hashtbl.create 32 in
           let models (f : string) : Alias.t option =
             match Hashtbl.find_opt cache f with
             | Some x -> x
             | None ->
                 let x = Option.map Alias.load (read f) in
                 Hashtbl.replace cache f x;
                 x
           in
           let start () : Play.t * Game.t =
             (* (the same level: Play makes its doors and lifts again,
              * and the renderer has marked its leaves) *)
             let play = Play.create level in
             place play;
             (* (the items standing; the monsters are Game's) *)
             let things =
               if flag "things" = Some "off" then []
               else
                 List.filter
                   (fun (t : Things.thing) ->
                     not
                       (String.length t.classname > 8
                       && String.sub t.classname 0 8 = "monster_"))
                   (Things.load level read)
             in
             let game =
               Game.create level play models things
                 (flag "nomonsters" = None && flag "things" <> Some "off")
                 (flag "ai" = Some "ways")
             in
             if flag "weapons" = Some "all" then Game.give_all game;
             (play, game)
           in
           let play, game = start () in
           let sound =
             if flag "sound" = Some "off" then None
             else Some (Sound.create read (flag "sound" = Some "3d"))
           in
           (* the level's CD track, looping (off by default on Plan 9:
            * mini-ml's decoding is most of a Pi's core) *)
           let music =
             match flag "music" with
             | Some m -> m = "on"
             | None -> Sys.os_type <> "Plan9"
           in
           (if music && sound <> None then
              match read (Cdaudio.track level) with
              | Some ogg -> Cdaudio.play ogg
              | None -> ());
           let name =
             match level.entities with
             | w :: _ -> (
                 match Model.value w "message" with Some s -> s | None -> path)
             | [] -> path
           in
           let model =
             {
               level;
               render;
               play;
               game;
               restart = start;
               sound;
               palettes = palettes palette;
               status = flag "status" <> Some "off";
               name;
               screens =
                 [| Bytes.create (320 * 200); Bytes.create (320 * 200) |];
               frames = 0;
               last = 0.;
             }
           in
           let flags =
             match (flag "window", scale) with
             | Some _, _ -> flags
             | None, Some n ->
                 ("window", Printf.sprintf "%dx%d" (320 * n) (200 * n)) :: flags
             | None, None -> ("window", "") :: flags
           in
           (* (no scale: the software platform's square of 320) *)
           let side = match scale with Some n -> 320 * n | None -> 320 in
           let flags =
             if flag "size" = None then ("size", string_of_int side) :: flags
             else flags
           in
           Playground_platform.run_app caps
             (("heap", "modest") :: flags)
             (P.game view update model)
         end
       with Failure msg ->
         Console.eprint caps ("mini-quake: " ^ msg ^ "\n");
         CapStdlib.exit caps 1);
      Exit.OK)
