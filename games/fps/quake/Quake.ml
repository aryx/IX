(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-quake: Quake (id Software, 1996), its software renderer and
 * its lightmaps, as a program of ix's playground
 * (docs/plans/plan_quake.md). A walk through a level of a .bsp --
 * LibreQuake's lq_e0m1 by default, compiled by qbsp and vis, lit by
 * tools/Light.ml (data/README.md) -- textured and lit as Quake drew
 * it, its doors, buttons, lifts and triggers working, its monsters and
 * items standing.
 *
 *   the keys: the arrows (or w, s) walk and turn; a and d step aside;
 *   shift runs; space jumps (swims up); e uses (a secret door, a
 *   button: what Quake's shot did); page up and down look
 *
 *   usage: mini-quake [bsp=file.bsp] [scale=n]
 *            [x=X y=Y z=Z angle=A pitch=P] [lightmaps] [things=off] [entities]
 *     bsp=   the level (default: /lib/quake/e0m1.bsp, else
 *            games/fps/quake/data/e0m1.bsp); the palette and the
 *            colormap beside it
 *     scale= each pixel made n by n (1 to 4; 2 by default, 1 on Plan 9)
 *     x= y= z= angle= pitch=  the eye put there, looking that way
 *            (degrees): a test's camera
 *     lightmaps  the textures grey: the lightmaps alone
 *     things=off  no monster nor item drawn
 *     entities   the level's entities listed, and the end
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
  play : Play.t;
  (* the level's message: its name *)
  name : string;
  things : Things.thing list;
  images : Rgba_image.t array;
  mutable frames : int;
  scale : int;
  rgba : Bytes.t;
  mutable last : float;
}

(* the picture, the platform's pixels: each byte its colour, n by n *)
let to_rgba (m : model) : unit =
  let v = m.render.view in
  let src = v.screen and w = v.width and h = v.height in
  let k = m.scale and dst = m.images.(m.frames land 1).rgba and rgba = m.rgba in
  let row = 4 * w * k in
  for y = 0 to h - 1 do
    let o = ref (y * k * row) in
    for x = 0 to w - 1 do
      let c = 4 * Char.code (Bytes.unsafe_get src ((y * w) + x)) in
      let r = Bytes.unsafe_get rgba c
      and g = Bytes.unsafe_get rgba (c + 1)
      and b = Bytes.unsafe_get rgba (c + 2) in
      for _n = 1 to k do
        let i = !o in
        Bytes.unsafe_set dst i r;
        Bytes.unsafe_set dst (i + 1) g;
        Bytes.unsafe_set dst (i + 2) b;
        Bytes.unsafe_set dst (i + 3) '\255';
        o := i + 4
      done
    done;
    for j = 1 to k - 1 do
      Bytes.blit dst (y * k * row) dst (((y * k) + j) * row) row
    done
  done

let view (computer : P.computer) (m : model) : P.shape list =
  let p = m.play in
  List.iter
    (fun (t : Things.thing) ->
      if Brushes.taken p.brushes t.classname t.origin then t.alive <- false)
    m.things;
  Render.frame m.render m.level (Play.eye p) p.pitch (Play.yaw p) p.time
    p.styles (Play.bmodels p) m.things;
  m.frames <- m.frames + 1;
  to_rgba m;
  let screen = computer.screen in
  let v = m.render.view in
  let w = screen.width
  and h = screen.width *. float v.height /. float v.width in
  let text (s : string) (y : float) : P.shape =
    P.words P.white s |> P.scale 2. |> P.move 0. y
  in
  (if h < screen.height then
     [ P.rectangle (P.rgb 96 96 96) screen.width screen.height ]
   else [])
  @ [
      P.bitmap w h
        { (m.images.(m.frames land 1)) with width = v.width * m.scale };
    ]
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
  Play.frame m.play dt
    {
      forward = k.kup || k.kw;
      back = k.kdown || k.ks;
      left = k.kleft;
      right = k.kright;
      strafe_left = k.ka;
      strafe_right = k.kd;
      jump = k.kspace;
      run = k.kshift;
      look_up = held "pageup";
      look_down = held "pagedown";
      use_key = held "e";
    };
  m

let default_bsps = [ "/lib/quake/e0m1.bsp"; "games/fps/quake/data/e0m1.bsp" ]

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch
      @@ fun () ->
      (try
         let flags = Playground_platform.flags caps in
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
         if flag "entities" <> None then
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
             | Some n when n >= 1 && n <= 4 -> n
             | _ -> if Sys.os_type = "Plan9" then 1 else 2
           in
           let render = Render.create level colormap in
           let image () : Rgba_image.t =
             Rgba_image.create ~width:(320 * scale) ~height:(200 * scale)
           in
           let rgba = Bytes.create 1024 in
           for i = 0 to 255 do
             for c = 0 to 2 do
               Bytes.set rgba ((4 * i) + c) palette.[(3 * i) + c]
             done;
             Bytes.set rgba ((4 * i) + 3) '\255'
           done;
           if flag "lightmaps" <> None then Surfcache.grey := true;
           let play = Play.create level in
           (match
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
           | _ -> ());
           let things =
             if flag "things" = Some "off" then []
             else
               Things.load level (fun (f : string) ->
                   FS.read_opt caps
                     (Fpath.v (Filename.concat (Filename.dirname path) f)))
           in
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
               name;
               things;
               images = [| image (); image () |];
               frames = 0;
               scale;
               rgba;
               last = 0.;
             }
           in
           let flags =
             if flag "window" = None then
               ("window", Printf.sprintf "%dx%d" (320 * scale) (200 * scale))
               :: flags
             else flags
           in
           let flags =
             if flag "size" = None then
               ("size", string_of_int (320 * scale)) :: flags
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
