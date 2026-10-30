(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Film.mli *)

(* ix: what shows a film of the author's playground's
 * apps/media/TinyMediaPlayer.ml (its deck, movie_frame), alone: not its
 * playlist, its pictures, its scope *)

open Playground

type t = { movie : Movie.t; sound : Signal.t option; loops : bool }

let is_film (kind : string) : bool =
  List.mem kind [ "video/x-y4m"; "video/x-flic"; "video/x-msvideo"; "image/gif" ]

let read ~(kind : string) (bytes : string) : (t, string) result =
  match kind with
  | "video/x-y4m" -> Ok { movie = snd (Y4m.of_string bytes); sound = None; loops = false }
  | "video/x-flic" -> Ok { movie = snd (Fli.of_string bytes); sound = None; loops = false }
  | "image/gif" -> Ok { movie = Movie.of_frames (Gif.animation bytes); sound = None; loops = true }
  | "video/x-msvideo" ->
      let _, movie, sound = Avi.of_string bytes in
      let at_rate ((rate, mono) : int * float array) : Signal.t = Resample.to_rate Linear rate mono in
      Ok { movie; sound = Option.map at_rate sound; loops = false }
  | _ -> Error ("not a film: " ^ kind)
  | exception Failure why -> Error why

(*****************************************************************************)
(* The sound's side: the mixer pulls its blocks between frames *)
(*****************************************************************************)

type deck = { mutable samples : Signal.t; mutable pos : int; mutable paused : bool }

let deck = { samples = [||]; pos = 0; paused = false }

let fill (out : Signal.stereo) : unit =
  let n = Array.length out.left in
  Array.fill out.left 0 n 0.;
  Array.fill out.right 0 n 0.;
  if not deck.paused then (
    let k = max 0 (min n (Array.length deck.samples - deck.pos)) in
    Array.blit deck.samples deck.pos out.left 0 k;
    Array.blit deck.samples deck.pos out.right 0 k;
    deck.pos <- deck.pos + k)

(*****************************************************************************)
(* The picture's side *)
(*****************************************************************************)

type model = {
  film : t;
  clock : float; (* seconds of the film shown, when the sound does not say *)
  last : float option; (* the time of the frame before *)
  paused : bool;
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

let view (computer : computer) (m : model) : shape list =
  let movie = m.film.movie in
  let w = computer.screen.width and h = computer.screen.height in
  let i = Movie.index_at movie (position m) in
  let f = fit movie w (h -. status_bar) in
  let line =
    Printf.sprintf "frame %d of %d   %s   q: the end" (i + 1) (Movie.frame_count movie)
      (if m.paused then "space: go on" else "space: pause")
  in
  [ rectangle black w h;
    move 0. (status_bar /. 2.)
      (bitmap (f *. float_of_int movie.width) (f *. float_of_int movie.height) (movie.frame i));
    move 0. ((-.h /. 2.) +. (status_bar /. 2.)) (scale 1.6 (words (rgb 200 200 200) line)) ]

let run (caps : Cap.all_caps) (film : t) : unit =
  (match film.sound with Some s -> deck.samples <- s | None -> ());
  Playground_platform.run_app caps
    (Playground_platform.flags caps @ [ ("window", "") ])
    (Playground.game view (update caps) { film; clock = 0.; last = None; paused = false; held = Set_.empty })
