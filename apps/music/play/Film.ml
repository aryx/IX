(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Film.mli *)

(* ix: what shows a film of the author's playground's
 * apps/media/TinyMediaPlayer.ml (its deck, movie_frame), alone: not its
 * playlist, its pictures, its scope *)

open Playground

(* an MPEG-1's decisions, for the analyzer; what was sent, made when asked *)
type analysis = { header : Mpeg1.header; info : int -> Mpeg1.info; sent : unit -> Movie.t }

type t = { movie : Movie.t; sound : Signal.stereo option; loops : bool; mpeg : analysis option }

(* the frames, and what the analyzer wants of them *)
let of_mpeg1 (bytes : string) (sound : Signal.stereo option) : t =
  let header, movie, info = Mpeg1.of_string ~residual:false bytes in
  let made = ref None in
  let sent () =
    match !made with
    | Some m -> m
    | None ->
        let _, m, _ = Mpeg1.of_string ~residual:true bytes in
        made := Some m;
        m
  in
  { movie; sound; loops = false; mpeg = Some { header; info; sent } }

let is_film (kind : string) : bool =
  List.mem kind [ "video/x-y4m"; "video/x-flic"; "video/x-msvideo"; "video/mpeg"; "image/gif" ]

(* an MP2's samples at our rate *)
let mpeg_sound (bytes : string) : Signal.stereo option =
  match Mpeg_audio.decode bytes with
  | Error _ -> None
  | Ok ((h : Mpeg_audio_header.t), (s : Signal.stereo)) ->
      let at_our_rate (x : Signal.t) = if h.sample_rate = Signal.rate then x else Resample.to_rate Cubic h.sample_rate x in
      Some { left = at_our_rate s.left; right = at_our_rate s.right }

(* [s] starting [seconds] later (earlier if negative): silence added
 * before it, or its start cut *)
let delayed (seconds : float) (s : Signal.t) : Signal.t =
  let n = int_of_float (Float.round (seconds *. float_of_int Signal.rate)) in
  if n >= 0 then Array.append (Array.make n 0.) s
  else Array.sub s (min (-n) (Array.length s)) (max 0 (Array.length s + n))

(* a system stream, its first video and audio: the sound moved so that its
 * time 0 is the first picture's (their first timestamps) *)
let of_system_stream (bytes : string) : (t, string) result =
  let streams = Mpeg_system.of_string bytes in
  match Mpeg_system.video streams with
  | None -> Error "no video stream"
  | Some video ->
      let sound =
        match Mpeg_system.audio streams with
        | None -> None
        | Some audio ->
            let offset = match (audio.first_pts, video.first_pts) with Some a, Some v -> a -. v | _ -> 0. in
            let moved (s : Signal.stereo) : Signal.stereo = { left = delayed offset s.left; right = delayed offset s.right } in
            Option.map moved (mpeg_sound audio.bytes)
      in
      Ok (of_mpeg1 video.bytes sound)

let read ~(kind : string) (bytes : string) : (t, string) result =
  match kind with
  | "video/x-y4m" -> Ok { movie = snd (Y4m.of_string bytes); sound = None; loops = false; mpeg = None }
  | "video/x-flic" -> Ok { movie = snd (Fli.of_string bytes); sound = None; loops = false; mpeg = None }
  | "image/gif" -> Ok { movie = Movie.of_frames (Gif.animation bytes); sound = None; loops = true; mpeg = None }
  | "video/x-msvideo" ->
      let _, movie, sound = Avi.of_string bytes in
      let at_rate ((rate, mono) : int * float array) : Signal.stereo =
        let s = Resample.to_rate Linear rate mono in
        { left = s; right = s }
      in
      Ok { movie; sound = Option.map at_rate sound; loops = false; mpeg = None }
  | "video/mpeg" when String.length bytes > 3 && bytes.[3] = '\xBA' -> of_system_stream bytes
  | "video/mpeg" -> Ok (of_mpeg1 bytes None)
  | _ -> Error ("not a film: " ^ kind)
  | exception Failure why -> Error why

(*****************************************************************************)
(* The sound's side: the mixer pulls its blocks between frames *)
(*****************************************************************************)

type deck = { mutable samples : Signal.stereo; mutable pos : int; mutable paused : bool }

let deck = { samples = { left = [||]; right = [||] }; pos = 0; paused = false }

let fill (out : Signal.stereo) : unit =
  let n = Array.length out.left in
  Array.fill out.left 0 n 0.;
  Array.fill out.right 0 n 0.;
  if not deck.paused then (
    let k = max 0 (min n (Array.length deck.samples.left - deck.pos)) in
    Array.blit deck.samples.left deck.pos out.left 0 k;
    Array.blit deck.samples.right deck.pos out.right 0 k;
    deck.pos <- deck.pos + k)

(*****************************************************************************)
(* The picture's side *)
(*****************************************************************************)

type model = {
  film : t;
  clock : float; (* seconds of the film shown, when the sound does not say *)
  last : float option; (* the time of the frame before *)
  paused : bool;
  changes : bool; (* d: what changed from the frame before, the rest dimmed *)
  blocks : bool; (* a: an MPEG-1's macroblocks and vectors drawn over it *)
  residual : bool; (* r: an MPEG-1 as what was sent, the prediction off *)
  held : string Set_.t;
}

(* where the film is: the sound's, once it has begun *)
let position (m : model) : float =
  if deck.pos > 0 then float_of_int deck.pos /. float_of_int Signal.rate
  else if m.film.loops then Float.rem m.clock m.film.movie.duration
  else m.clock

let status_bar = 26.

let update (caps : Cap.all_caps) (computer : computer) (m : model) : model =
  if m.film.sound <> None then
    ignore
      (Audio.instrument "film" (fun () ->
           { Instrument.note_on = (fun _ _ -> ()); note_off = ignore; set = (fun _ _ -> ()); fill }));
  let keys = computer.keyboard.keys in
  let pressed (name : string) = Set_.mem name keys && not (Set_.mem name m.held) in
  if computer.keyboard.typed = "q" then CapStdlib.exit caps 0;
  let paused = if pressed "space" then not m.paused else m.paused in
  deck.paused <- paused;
  let typed = computer.keyboard.typed in
  let m =
    { m with
      changes = (if typed = "d" then not m.changes else m.changes);
      blocks = (if typed = "a" then not m.blocks else m.blocks);
      residual = (if typed = "r" then not m.residual else m.residual) }
  in
  (* the arrows, five seconds: the sound's place, and the timer's *)
  let m =
    let step = if pressed "ArrowRight" then 5. else if pressed "ArrowLeft" then -5. else 0. in
    if step = 0. then m
    else
      let t = Float.max 0. (Float.min (m.film.movie.duration -. 0.001) (position m +. step)) in
      deck.pos <- int_of_float (t *. float_of_int Signal.rate);
      { m with clock = t }
  in
  let (Time now) = computer.time in
  (* (a step of more than a second is no film's: the platform's first time,
   * or a machine that stopped, which goes on from where it was) *)
  let passed = match m.last with Some t when now -. t <= 1. -> now -. t | _ -> 0. in
  { m with clock = (if paused then m.clock else m.clock +. passed); last = Some now; paused; held = keys }

(* a whole number of pixels a pixel when enlarged: at 8.75, the rows fall
 * between pixels; made smaller to fit, it can't be *)
let fit (m : Movie.t) (w : float) (h : float) : float =
  let f = Float.min (w /. float_of_int m.width) (h /. float_of_int m.height) in
  if f >= 1. then Float.of_int (int_of_float f) else f

(* what changed: the pixels the same as the frame before's at a quarter of
 * their brightness, the others as they are: what a delta frame stores
 * (Fli.mli), seen; the first frame all changed *)
let changed (movie : Movie.t) (i : int) : Rgba_image.t =
  let img = movie.frame i in
  if i = 0 then img
  else
    let before = movie.frame (i - 1) in
    let out = Rgba_image.create ~width:img.width ~height:img.height in
    let get (b : Bytes.t) (at : int) = Bytes.get_uint8 b at in
    for p = 0 to (img.width * img.height) - 1 do
      let o = 4 * p in
      let same =
        get img.rgba o = get before.rgba o
        && get img.rgba (o + 1) = get before.rgba (o + 1)
        && get img.rgba (o + 2) = get before.rgba (o + 2)
      in
      for c = 0 to 2 do
        let v = get img.rgba (o + c) in
        Bytes.set_uint8 out.rgba (o + c) (if same then v / 4 else v)
      done;
      Bytes.set_uint8 out.rgba (o + 3) 255
    done;
    out

let segment (color : color) ((x1, y1) : float * float) ((x2, y2) : float * float) : shape =
  let dx = x2 -. x1 and dy = y2 -. y1 in
  rectangle color (sqrt ((dx *. dx) +. (dy *. dy)) +. 1.) 2.
  |> rotate (atan2 (y2 -. y1) (x2 -. x1) *. 180. /. Float.pi)
  |> move ((x1 +. x2) /. 2.) ((y1 +. y2) /. 2.)

let kind_color (kind : Mpeg1.kind) : color =
  match kind with I -> rgb 230 60 50 | P -> rgb 60 200 80 | B -> rgb 60 130 240

(* the analyzer, over an MPEG-1: each macroblock tinted by how it was coded
 * (intra red, from the past green, from the future blue, from both purple, a
 * P's with no vector grey, skipped not at all), its vectors drawn from its
 * centre to where its pixels come from, white forward, cyan backward; under
 * the picture, the frames' kinds in the order shown, the one shown tall.
 * ix: the playground's TinyMediaPlayer, its analysis *)
let blocks_over (a : analysis) (movie : Movie.t) (f : float) (centre_y : float) (bottom_y : float) (w : float) (i : int) : shape list =
  let left = -.(float_of_int movie.width *. f /. 2.) in
  let top = centre_y +. (float_of_int movie.height *. f /. 2.) in
  let picture_bottom = top -. (float_of_int movie.height *. f) in
  let inf = a.info i in
  let cell = 16. *. f in
  let macroblock (at : int) ((how, fv, bv) : Mpeg1.how * (int * int) * (int * int)) : shape list =
    let cx = left +. ((float_of_int (at mod inf.mb_width) +. 0.5) *. cell) in
    let cy = top -. ((float_of_int (at / inf.mb_width) +. 0.5) *. cell) in
    (* the last row's can run past the picture: their tint cut at its edge *)
    let tint_h = Float.min (cell -. 2.) (cy +. (cell /. 2.) -. picture_bottom -. 1.) in
    let tint =
      match how with
      | Intra -> [ rgb 230 60 50 ]
      | Forward -> [ rgb 60 200 80 ]
      | Backward -> [ rgb 60 130 240 ]
      | Both -> [ rgb 180 80 220 ]
      | Zero -> [ rgb 150 150 150 ]
      | Skipped -> []
    in
    let arrow ((dx, dy) : int * int) (color : color) : shape list =
      if dx = 0 && dy = 0 then []
      else
        [ segment color (cx, cy) (cx +. (float_of_int dx /. 2. *. f), cy -. (float_of_int dy /. 2. *. f));
          move cx cy (circle color 3.) ]
    in
    List.map
      (fun (c : color) -> move cx (cy +. (cell /. 2.) -. 1. -. (tint_h /. 2.)) (fade 0.35 (rectangle c (cell -. 2.) tint_h)))
      tint
    @ arrow fv (rgb 250 250 250)
    @ arrow bv (rgb 90 230 230)
  in
  let n = Array.length a.header.kinds in
  let side = Float.min 14. ((w -. 40.) /. float_of_int n) in
  let strip =
    List.mapi
      (fun (k : int) (kind : Mpeg1.kind) ->
        move
          ((-.(float_of_int n *. side /. 2.)) +. ((float_of_int k +. 0.5) *. side))
          bottom_y
          (rectangle (kind_color kind) (side -. 2.) (if k = i then 22. else 10.)))
      (Array.to_list a.header.kinds)
  in
  List.concat (List.mapi macroblock (Array.to_list inf.macroblocks)) @ strip

let view (computer : computer) (m : model) : shape list =
  let movie = m.film.movie in
  let w = computer.screen.width and h = computer.screen.height in
  let i = Movie.index_at movie (position m) in
  let f = fit movie w (h -. status_bar) in
  let line =
    let mpeg =
      match m.film.mpeg with
      | Some a ->
          let kind = match a.header.kinds.(i) with I -> "I" | P -> "P" | B -> "B" in
          Printf.sprintf " (%s)   a r: blocks, what was sent" kind
      | None -> ""
    in
    Printf.sprintf "frame %d of %d%s   d: changes   arrows: 5 s   %s   q: the end" (i + 1) (Movie.frame_count movie) mpeg
      (if m.paused then "space: go on" else "space: pause")
  in
  let shown = match m.film.mpeg with Some a when m.residual -> a.sent () | _ -> movie in
  let picture = if m.changes then changed shown i else shown.frame i in
  let analysis =
    match m.film.mpeg with
    | Some a when m.blocks ->
        blocks_over a movie f (status_bar /. 2.) ((-.h /. 2.) +. status_bar +. 14.) w i
    | _ -> []
  in
  [ rectangle black w h;
    move 0. (status_bar /. 2.)
      (bitmap (f *. float_of_int movie.width) (f *. float_of_int movie.height) picture) ]
  @ analysis
  @ [
    move 0. ((-.h /. 2.) +. (status_bar /. 2.)) (scale 1.6 (words (rgb 200 200 200) line)) ]

let run (caps : Cap.all_caps) (film : t) : unit =
  (match film.sound with Some s -> deck.samples <- s | None -> ());
  Playground_platform.run_app caps
    (Playground_platform.flags caps @ [ ("window", "") ])
    (Playground.game view (update caps) { film; clock = 0.; last = None; paused = false; changes = false; blocks = false; residual = false; held = Set_.empty })
