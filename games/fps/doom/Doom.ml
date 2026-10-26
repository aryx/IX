(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-doom: Doom (id Software, 1993), its renderer and its data, as a
 * program of ix's playground (docs/plans/done/plan_doom.md). A walk through
 * a level of a WAD -- Freedoom's E1M1 by default, made from Freedoom's
 * source by tools/Mkwad.ml (data/README.md) -- its walls, floors,
 * ceilings and sky textured and lit as Doom drew them, its doors and
 * lifts working, to its exit.
 *
 *   the keys: the arrows (or w, s) walk and turn; a and d step aside
 *   (Doom's , and .); shift runs; space (or e) uses (a door, a
 *   switch, a lift); control (or f) fires; 1 to 3 the weapons (1 the
 *   fist, or the chainsaw; 2 the pistol; 3 the shotgun)
 *
 *   usage: mini-doom [wad=file.wad] [map=E1M1] [scale=n] [x=X y=Y angle=A]
 *                    [nomonsters] [things=off] [ai=ways] [sound=off|3d]
 *                    [music=off] [graphics=only] [lumps]
 *     wad=   the WAD (default: /lib/doom/freedoom.wad, else
 *            games/fps/doom/data/freedoom.wad: the card's, the
 *            repository's); an IWAD of id's works the same
 *            (doom1.wad), the levels its own
 *     map=   which level (the WAD's first by default)
 *     scale= each of Doom's 320 by 200 pixels made n by n (1 to 4;
 *            2 by default); the platform's size= is then 320 n, so
 *            that it shows the picture as it is (unless size= is
 *            said). On Plan 9 by default, the picture is all of the
 *            window or screen, the largest whole n that fits (the
 *            device makes it n times larger: mini-9pi's 'z')
 *     x= y= angle=  the player put there, looking that way (degrees):
 *            a test's camera (tests/compare.sh)
 *     nomonsters  the level without its monsters (Doom's -nomonsters)
 *     things=off  the level without its things: no item, decoration
 *            nor monster drawn or moved
 *     ai=ways  the monsters find their way by the playground's AI
 *            (Ways), not id's (Enemy)
 *     sound=  off: none; 3d: the playground's Audio3d, not id's
 *            (Sound)
 *     music=  off, or on: the level's music (Audio's MIDI player); off
 *            by default on Plan 9: mini-ml's code makes a second of it
 *            in 7 (OCaml's in 0.3), the game's frames stopped meanwhile
 *     graphics=only  nomonsters things=off sound=off music=off: the
 *            renderer alone, the walls, floors and ceilings (its frames
 *            a second, the monsters' cost and the sound's apart)
 *     status=off  no status line (a test's picture: tests/compare.sh)
 *     lumps  the WAD's lumps listed, and the end
 *
 * A frame (the playground's view): Play's tics since the last frame
 * (35 a second, at most 4 a frame), then Render's picture of the
 * player's eye (between its last two tics: [eye]), 320 by 200 bytes
 * of the palette, made the platform's
 * pixels (each index its colour, n by n), one Bitmap shape; the
 * messages are the playground's words over it.
 *
 *          the keys                         the picture
 *   computer.keyboard --> Play.command --> Play.tic (x 35 a second)
 *                                              |
 *                                      the player's eye
 *                                              v
 *   Bitmap <-- the palette, n by n <-- Render.frame: 320 x 200 bytes
 *
 * This is the slow way on mini-9pi: the draw platform is given a new
 * picture at every frame (plan_doom.md, stage 6: a framebuffer).
 *
 * history:
 * id's game ran on DOS, then on NeXTSTEP (where it was written), Linux
 * (linuxdoom, whose source id gave in 1997), and everywhere since;
 * 9front's doom9 is linuxdoom with a draw device for its window: what
 * this does on mini-9pi. *)

module P = Playground

type model = {
  mutable play : World.t;
  (* the level again, from its start (the player dead, use pressed) *)
  restart : unit -> World.t;
  sound : Sound.t option;
  status : bool; (* the status line shown *)
  (* the palette reddened by the pain, 1 to 8 (id's PLAYPAL's 1 to 8),
   * or gilded by an item, 9 to 12: each made once, the same value
   * then *)
  palettes : string array;
  sprites : Things.sprites;
  render : Render.t;
  (* two pictures' bytes, one a frame in turn: the platform compares a
   * frame's shapes with the last's (Redraw), which must not be the same
   * bytes changed; and each frame's picture a new value over them
   * ([view]) *)
  screens : Bytes.t array;
  mutable frames : int;
  mutable last : float; (* the time of the last frame *)
  mutable pending : float; (* the time not yet made tics *)
  (* use pressed since the last tic: a frame's press between two tics
   * (60 frames a second, 35 tics) is not lost *)
  mutable use_pressed : bool;
  (* the eye at the tic before the last (x, y, z, angle): a frame shows
   * it between that tic and the last *)
  mutable before : float * float * float * float;
}

(* Doom's picture as it is, 320 by 200 bytes of the palette, given to
 * the platform (a Pixels shape), which makes of it what its device
 * wants: the screen's format on Plan 9, RGBA elsewhere, each pixel n by
 * n (docs/plans/done/plan_playground_framebuffer.md, F2).
 * old: made RGBA here, each pixel n by n (to_rgba), 30% of a frame on
 * the Pi 2 by mini-ml's code; the draw platform then made it again in
 * the screen's format *)
let snapshot (m : model) : unit =
  let src = Render.screen m.render in
  Bytes.blit src 0 m.screens.(m.frames land 1) 0 (Bytes.length src)

let tics_a_second = 35.

(* The eye drawn between its last two tics, as far as the time since
 * the last says: 35 tics at 60 frames a second, a frame that showed
 * the last tic's eye showed it again or moved by one, and the walk
 * went by jerks (the author, 2026-10-22: "this machine is 100x faster
 * than a 486Dx66 from 1995 where doom was running smoothly"; id's
 * game drew at most a frame a tic, and the ports since draw this way,
 * the picture a tic late). A move longer than a tic's run (a
 * teleporter) is not drawn on its way. *)
let eye (m : model) : float * float * float * float =
  let p = m.play.player and x, y, z, angle = m.before in
  let f = Float.min 1. (m.pending *. tics_a_second) in
  let between (a : float) (b : float) : float = a +. (f *. (b -. a)) in
  if Float.abs (p.x -. x) +. Float.abs (p.y -. y) > 64. then (p.x, p.y, p.viewz, p.angle)
  else (between x p.x, between y p.y, between z p.viewz, between angle p.angle)

(* ST_doPaletteStuff: red the more it hurt, gold a moment for an item *)
let palette (m : model) : string =
  let p = m.play.player in
  let red = (p.damagecount + 7) lsr 3 and gold = (p.bonuscount + 7) lsr 3 in
  if red > 0 then m.palettes.(min 8 red)
  else if gold > 0 then m.palettes.(8 + min 4 gold)
  else m.palettes.(0)

(* the palettes of [palette]: towards red by an ninth a step, towards
 * gold by an eighth (as Freedoom's playpal script makes PLAYPAL's) *)
let palettes (base : string) : string array =
  let tint ((r, g, b) : int * int * int) (k : float) : string =
    String.init 768 (fun (i : int) ->
        let c = Char.code base.[i] in
        let to_ = match i mod 3 with 0 -> r | 1 -> g | _ -> b in
        Char.chr (c + int_of_float (k *. float (to_ - c)))) in
  Array.init 13 (fun (i : int) ->
      if i = 0 then base
      else if i <= 8 then tint (255, 0, 0) (float i /. 9.)
      else tint (215, 186, 69) (float (i - 8) /. 8.))

(* the status bar's numbers, as words (no STBAR here) *)
let status (m : model) : string =
  let p = m.play.player in
  let ammo =
    match (Info.weaponinfo p.readyweapon).ammo with
    | Some Info.Clip -> string_of_int p.clips
    | Some Info.Shell -> string_of_int p.shells
    | None -> "-" in
  Printf.sprintf "HEALTH %d%%  ARMOR %d%%  AMMO %s  KILLS %d" p.health p.armor
    ammo m.play.kills

let view (computer : P.computer) (m : model) : P.shape list =
  let x, y, z, angle = eye m in
  let p = m.play.player in
  Render.set_extralight m.render p.extralight;
  Render.frame m.render m.play.level m.play.textures m.sprites m.play.by_sector m.play.tic x y z angle;
  (* R_DrawPlayerSprites: the weapon, then its flash *)
  let hand =
    List.filter_map
      (fun (sp : World.psprite) ->
        Option.map (fun (st : Info.state) -> (st, sp.sx, sp.sy)) sp.pstate)
      [ p.weapon_sp; p.flash_sp ] in
  let light = (Level.sector_at m.play.level p.x p.y).light in
  Render.hand m.render m.play.textures m.sprites light hand;
  m.frames <- m.frames + 1;
  snapshot m;
  let screen = computer.screen in
  (* (as many units as the platform has pixels: the window's, or the
   * square's at size=320n) *)
  let w = Float.min screen.width (screen.height *. float (Render.width m.render) /. float (Render.height m.render)) in
  let h = w *. float (Render.height m.render) /. float (Render.width m.render) in
  let text (s : string) (y : float) : P.shape = P.words P.white s |> P.scale 2. |> P.move 0. y in
  (* (a grey around the picture, where the screen is a square: the
   * Plan 9 platforms'; not black, where the platform's counter of
   * frames, in black, would not be seen. A window of the picture's
   * size has none, its pixels then the picture's only) *)
  (if h < screen.height || w < screen.width then [ P.rectangle (P.rgb 96 96 96) screen.width screen.height ] else [])
  (* (a new picture each frame, though its bytes are one of two: the
   * draw platform keeps the device's image of a picture it has shown,
   * found by the value itself (==), and a picture changed in place was
   * shown as it was the first time: on mini-9pi the eye never moved,
   * the author: "I see 15fps but I can't do anything") *)
  @ [ P.pixels w h
        { pwidth = Render.width m.render; pheight = Render.height m.render; indices = m.screens.(m.frames land 1);
          palette = palette m } ]
  @ (if m.status then [ text (status m) (20. -. (h /. 2.)) ] else [])
  @ (if m.play.message_tics > 0 then [ text m.play.message (h /. 2. -. 20.) ] else [])
  @ (if p.health <= 0 then [ text "Press use to play again." 0. ] else [])
  @
  if m.play.exited then
    [ text (Printf.sprintf "%s finished: %d of %d secrets" m.play.level.name m.play.secrets (Play.secrets_total m.play)) 0. ]
  else []

let update (computer : P.computer) (m : model) : model =
  let (P.Time now) = computer.time in
  (* (the first frame, or a clock that jumped: no time to catch up) *)
  if m.last = 0. || now -. m.last > 0.5 then m.last <- now;
  m.pending <- Float.min (4. /. tics_a_second) (m.pending +. (now -. m.last));
  m.last <- now;
  let k = computer.keyboard in
  let held (name : string) : bool = Set_.mem name k.keys in
  if k.kspace || held "e" then m.use_pressed <- true;
  let number =
    match List.find_opt held [ "1"; "2"; "3" ] with
    | Some n -> int_of_string n
    | None -> 0 in
  while m.pending >= 1. /. tics_a_second do
    m.pending <- m.pending -. (1. /. tics_a_second);
    let p = m.play.player in
    m.before <- (p.x, p.y, p.viewz, p.angle);
    if not m.play.exited then
      Play.tic m.play
        (Play.command m.play.player
           { up = k.kup || k.kw; down = k.kdown || k.ks; left = k.kleft; right = k.kright; run = k.kshift;
             strafe_left = k.ka || held ","; strafe_right = k.kd || held ".";
             use_key = m.use_pressed;
             fire = held "Control" || held "f"; number });
    m.use_pressed <- k.kspace || held "e";
    if m.play.reborn then begin
      m.play <- m.restart ();
      let p = m.play.player in
      m.before <- (p.x, p.y, p.viewz, p.angle)
    end
  done;
  (* the tics' sounds, from where they were made *)
  (match m.sound with Some s -> Sound.play s m.play | None -> m.play.sounds <- []);
  m

let default_wads = [ "/lib/doom/freedoom.wad"; "games/fps/doom/data/freedoom.wad" ]

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch @@ fun () ->
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
           match flag "wad" with
           | Some f -> f
           | None -> (
               match List.find_opt (fun (f : string) -> Sys.file_exists f) default_wads with
               | Some f -> f
               | None -> failwith "no WAD: wad=file.wad")
         in
         let wad = Wad.parse (FS.read caps (Fpath.v path)) in
         if flag "lumps" <> None then
           Array.iter
             (fun (l : Wad.lump) -> Console.print caps (Printf.sprintf "%-8s %d\n" l.name (String.length l.data)))
             wad.lumps
         else begin
           let textures = Textures.load wad in
           (* (texture 0 is no texture, as in Doom: R_TextureNumForName's
            * "-" and the first of TEXTURE1 the same) *)
           let texture (name : string) : int = let k = Textures.texture textures name in if k = 0 then -1 else k in
           let map = match flag "map" with Some m -> String.uppercase_ascii m | None -> (match Level.maps wad with m :: _ -> m | [] -> failwith "no level in the WAD") in
           let level () : Level.t =
             Level.load wad map texture (Textures.flat textures) in
           (* (None: the window's size, the platform's whole multiple) *)
           let scale = match Option.bind (flag "scale") int_of_string_opt with Some n when n >= 1 && n <= 4 -> Some n | _ -> if Sys.os_type = "Plan9" then None else Some 2 in
           let render = Render.create 320 200 in
           let palette =
             String.init 768 (fun (k : int) -> Char.chr ((textures.palette.(k / 3) lsr (8 * (2 - (k mod 3)))) land 255))
           in
           let ai = if flag "ai" = Some "ways" then World.Ways else World.Id in
           let start () : World.t =
             Play.create (level ()) textures (flag "nomonsters" = None) ai in
           let play = start () in
           (* (things=off: none drawn, a test's: tests/compare.sh) *)
           if flag "things" = Some "off" then List.iter (fun (m : Things.mobj) -> m.alive <- false) play.things;
           (* (x=, y=, angle=: the player put there, a test's camera) *)
           (match (Option.bind (flag "x") float_of_string_opt, Option.bind (flag "y") float_of_string_opt) with
           | Some x, Some y ->
               let a = match Option.bind (flag "angle") float_of_string_opt with Some a -> a | None -> 0. in
               Play.place play x y (a *. 4. *. atan 1. /. 180.)
           | _ -> ());
           let sound =
             if flag "sound" = Some "off" then None
             else Some (Sound.create wad (flag "sound" = Some "3d")) in
           let music =
             match flag "music" with
             | Some m -> m = "on"
             | None -> Sys.os_type <> "Plan9" in
           if music && sound <> None then Sound.music wad map;
           let model = {
               play; restart = start; sound; status = flag "status" <> Some "off";
               palettes = palettes palette; sprites = Things.load wad; render; screens = [| Bytes.create (320 * 200); Bytes.create (320 * 200) |]; frames = 0; last = 0.; pending = 0.; use_pressed = false;
               before = (play.player.x, play.player.y, play.player.viewz, play.player.angle) } in
           (* the window the picture's size, a unit a pixel
            * (Session.window); the software platform's square of 320 n
            * (it has no window=). No scale: the window, whatever its
            * size, and the software platform's square of 320 *)
           let flags =
             match (flag "window", scale) with
             | Some _, _ -> flags
             | None, Some n -> ("window", Printf.sprintf "%dx%d" (320 * n) (200 * n)) :: flags
             | None, None -> ("window", "") :: flags in
           let side = match scale with Some n -> 320 * n | None -> 320 in
           let flags = if flag "size" = None then ("size", string_of_int side) :: flags else flags in
           (* heap=modest: a WAD's megabytes are alive the whole game, and a
            * game's heap of eight times what is alive (Plan9_loop) does
            * not fit in mini-9pi's memory *)
           Playground_platform.run_app caps (("heap", "modest") :: flags) (P.game view update model)
         end
       with Failure msg ->
         Console.eprint caps ("mini-doom: " ^ msg ^ "\n");
         CapStdlib.exit caps 1);
      Exit.OK)
