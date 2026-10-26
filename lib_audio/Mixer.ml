(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mixer.mli *)

(* ix: the author's playground's libs/audio/Mixer.ml; its optional arguments are said (docs/plans/plan_audio.md) *)

(* a one-shot: its samples, and how far it's been read.
 * ix: or a recording kept as it is, its volume, pan and far ear's delay
 * applied as it is mixed (play_at): mini-doom's and mini-quake's sounds
 * of the monsters, each made louder and panned at each play, were the
 * whole sound rendered again into new arrays (plan_virtuaracing.md,
 * stage 5). [len]: its length, its delay in; [scaled] = None, [samples]
 * as they are.
 * old: type shot = { samples : Signal.stereo; mutable at : int } *)
type scaled = {
  volume : float;
  gain_left : float;
  gain_right : float;
  late_left : int;
  late_right : int;
}
type shot = {
  samples : Signal.stereo;
  mutable at : int;
  len : int;
  scaled : scaled option;
}

(* a continuous voice: what it should play, its state, whether it was
 * kept since the last pull, its filter, and its pan (and the last
 * pull's, to glide from) *)
type continuous = {
  mutable voice : Synth.voice;
  mutable running : Synth.running;
  mutable kept : bool;
  mutable filter : Synth.filter option;
  memory : Filter.memory;
  mutable pan : float;
  mutable last_pan : float;
}

(* a loop: its samples, how far read (wrapping at the end), how many
 * samples of it have gone out in all (not wrapping: the loop's clock),
 * and whether it's being stopped *)
type looped = { sound : Signal.stereo; mutable pos : int; mutable played : int; mutable stopping : bool; prepare : int -> int -> unit }

(* an instrument: what it is, and whether it's being stopped *)
type played_live = { live : Instrument.t; mutable ending : bool }

type t = {
  mutable shots : shot list;
  continuous : (string, continuous) Hashtbl.t;
  loops : (string, looped) Hashtbl.t;
  instruments : (string, played_live) Hashtbl.t;
}

let max_playing = 32
let stereo = ref true
let length (s : Signal.stereo) : int = Array.length s.left
let create () : t = { shots = []; continuous = Hashtbl.create 8; loops = Hashtbl.create 2; instruments = Hashtbl.create 2 }

(* ix: loop_prepared and change_prepared, and loop and change over them *)
let loop_prepared (m : t) (name : string) (sound : Signal.stereo) (prepare : int -> int -> unit) : unit =
  match Hashtbl.find_opt m.loops name with
  | Some l when not l.stopping -> ()
  | _ -> if length sound > 0 then Hashtbl.replace m.loops name { sound; pos = 0; played = 0; stopping = false; prepare }

let change_prepared (m : t) (name : string) (sound : Signal.stereo) (prepare : int -> int -> unit) : unit =
  match Hashtbl.find_opt m.loops name with
  | Some l when (not l.stopping) && length sound > 0 ->
      (* (in floats: a tune's place times a tune's length is past an
       * int of 31 bits)
       * old: let pos = l.pos * length sound / length l.sound in *)
      let pos = int_of_float (float_of_int l.pos *. float_of_int (length sound) /. float_of_int (length l.sound)) in
      Hashtbl.replace m.loops name { l with sound; pos = min pos (length sound - 1); prepare }
  | _ -> loop_prepared m name sound prepare

let nothing (_ : int) (_ : int) : unit = ()
let loop (m : t) (name : string) (sound : Signal.stereo) : unit = loop_prepared m name sound nothing
let change (m : t) (name : string) (sound : Signal.stereo) : unit = change_prepared m name sound nothing

let stop (m : t) (name : string) : unit =
  Option.iter (fun l -> l.stopping <- true) (Hashtbl.find_opt m.loops name);
  Option.iter (fun i -> i.ending <- true) (Hashtbl.find_opt m.instruments name)

let looping (m : t) : string list = Hashtbl.fold (fun name _ acc -> name :: acc) m.loops [] |> List.sort compare

let instrument (m : t) (name : string) (live : Instrument.t) : unit =
  match Hashtbl.find_opt m.instruments name with
  | Some i when not i.ending -> ()
  | _ -> Hashtbl.replace m.instruments name { live; ending = false }

let instruments (m : t) : string list =
  Hashtbl.fold (fun name i acc -> if i.ending then acc else name :: acc) m.instruments [] |> List.sort compare

let add_shot (m : t) (shot : shot) : unit =
  (* the newest first; past max_playing, the oldest dropped *)
  m.shots <- List.filteri (fun i _ -> i < max_playing) (shot :: m.shots)

let play (m : t) (samples : Signal.stereo) : unit =
  add_shot m { samples; at = 0; len = length samples; scaled = None }

(* ix: Synth.render_stereo's of Panned (pan, louder volume (Samples x)),
 * without its arrays: each sample gain *. (x *. volume), the far ear's
 * zeros before it, the near one's after it *)
let play_at (m : t) (x : Signal.t) ~(volume : float) ~(pan : float) : unit =
  let (gain_left, gain_right) = Space.pan pan in
  let d = if !Space.ears_apart then Space.interaural_delay pan else 0 in
  let (late_left, late_right) = if pan > 0. then (d, 0) else (0, d) in
  add_shot m
    { samples = Signal.both x; at = 0; len = Array.length x + d;
      scaled = Some { volume; gain_left; gain_right; late_left; late_right } }

(* a shot's j-th sample, in each ear *)
let shot_left (s : shot) (j : int) : float =
  match s.scaled with
  | None -> s.samples.left.(j)
  | Some c ->
      let j = j - c.late_left in
      if j < 0 || j >= Array.length s.samples.left then 0.
      else c.gain_left *. (s.samples.left.(j) *. c.volume)

let shot_right (s : shot) (j : int) : float =
  match s.scaled with
  | None -> s.samples.right.(j)
  | Some c ->
      let j = j - c.late_right in
      if j < 0 || j >= Array.length s.samples.right then 0.
      else c.gain_right *. (s.samples.right.(j) *. c.volume)

(* ix: filter and pan were optional: none, 0 *)
let keep ~(filter : Synth.filter option) ~(pan : float) (m : t) (name : string) (voice : Synth.voice) : unit =
  match Hashtbl.find_opt m.continuous name with
  | Some c ->
      c.voice <- voice;
      c.filter <- filter;
      c.pan <- pan;
      c.kept <- true
  | None ->
      Hashtbl.replace m.continuous name
        { voice; running = Synth.start (); kept = true; filter; memory = Filter.silence (); pan; last_pan = pan }

(* old: pull, the mixing in float arrays (pull below, flat := false) *)
let pull_boxed (m : t) (n : int) : Signal.stereo =
  let left = Array.make n 0. and right = Array.make n 0. in
  (* the one-shots' next samples *)
  m.shots
  |> List.iter (fun s ->
         let k = min n (s.len - s.at) in
         for i = 0 to k - 1 do
           left.(i) <- left.(i) +. shot_left s (s.at + i);
           right.(i) <- right.(i) +. shot_right s (s.at + i)
         done;
         s.at <- s.at + k);
  m.shots <- List.filter (fun s -> s.at < s.len) m.shots;
  (* the continuous ones: going on, or fading out if not kept *)
  let gone = ref [] in
  m.continuous
  |> Hashtbl.iter (fun name c ->
         let samples =
           if c.kept then (
             let (samples, running) = Synth.continue c.running c.voice n in
             c.running <- running;
             samples)
           else (
             gone := name :: !gone;
             Synth.release c.running c.voice n)
         in
         let samples =
           match c.filter with
           | None -> samples
           | Some f ->
               let q = Filter.biquad f.kind ~cutoff:f.cutoff ~q:f.q in
               Array.map (Filter.step q c.memory) samples
         in
         (* the pan gliding from the last pull's to this one's, like the
          * volume (Synth.continue): no click when a source moves *)
         let (l0, r0) = Space.pan c.last_pan and (l1, r1) = Space.pan c.pan in
         Array.iteri
           (fun i x ->
             let a = float_of_int (i + 1) /. float_of_int n in
             left.(i) <- left.(i) +. (x *. (l0 +. ((l1 -. l0) *. a)));
             right.(i) <- right.(i) +. (x *. (r0 +. ((r1 -. r0) *. a))))
           samples;
         c.last_pan <- c.pan;
         c.kept <- false);
  List.iter (Hashtbl.remove m.continuous) !gone;
  (* the loops: read around and around; a stopped one fades out over
   * this pull, then is gone *)
  let stopped = ref [] in
  m.loops
  |> Hashtbl.iter (fun name l ->
         let len = length l.sound in
         l.prepare l.pos n;
         for i = 0 to n - 1 do
           let fade = if l.stopping then 1. -. (float_of_int i /. float_of_int n) else 1. in
           left.(i) <- left.(i) +. (fade *. l.sound.left.(l.pos));
           right.(i) <- right.(i) +. (fade *. l.sound.right.(l.pos));
           l.pos <- (l.pos + 1) mod len
         done;
         l.played <- l.played + n;
         if l.stopping then stopped := name :: !stopped);
  List.iter (Hashtbl.remove m.loops) !stopped;
  (* the instruments: a block each; a stopped one fades out over this
   * pull, like a loop, then is gone *)
  let ended = ref [] in
  m.instruments
  |> Hashtbl.iter (fun name i ->
         let block : Signal.stereo = { left = Array.make n 0.; right = Array.make n 0. } in
         i.live.fill block;
         for k = 0 to n - 1 do
           let fade = if i.ending then 1. -. (float_of_int k /. float_of_int n) else 1. in
           left.(k) <- left.(k) +. (fade *. block.left.(k));
           right.(k) <- right.(k) +. (fade *. block.right.(k))
         done;
         if i.ending then ended := name :: !ended);
  List.iter (Hashtbl.remove m.instruments) !ended;
  let out : Signal.stereo = { left = Mix.limit ~soft:true left; right = Mix.limit ~soft:true right } in
  if !stereo then out else Signal.both (Signal.mono out)

(* ix: the same mixing, in the same order, in flat arrays (Float.Array):
 * by mini-ml, each sample stored in a float array was a new block and
 * the write barrier, and each continuous voice's a pair and a running
 * (Synth.continue_into); the samples the same, made float arrays at
 * the end only. mini-virtuaracing's engine, road and wind, 3.2M
 * instructions a sixtieth of a second on arm (plan_virtuaracing.md,
 * stage 5) *)
let flat = ref true

let pull (m : t) (n : int) : Signal.stereo =
  if not !flat then pull_boxed m n else begin
  let left = Float.Array.make n 0. and right = Float.Array.make n 0. in
  let add (a : Float.Array.t) (i : int) (x : float) : unit =
    Float.Array.set a i (Float.Array.get a i +. x)
  in
  m.shots
  |> List.iter (fun s ->
         let k = min n (s.len - s.at) in
         (match s.scaled with
          | None ->
              for i = 0 to k - 1 do
                add left i s.samples.left.(s.at + i);
                add right i s.samples.right.(s.at + i)
              done
          | Some c ->
              (* (shot_left's and shot_right's, the shot's kind looked at
               * once: a sample out of the recording, a delay's, adds
               * nothing) *)
              let x = s.samples.left and nx = Array.length s.samples.left in
              for i = 0 to k - 1 do
                let jl = s.at + i - c.late_left and jr = s.at + i - c.late_right in
                if jl >= 0 && jl < nx then add left i (c.gain_left *. (x.(jl) *. c.volume));
                if jr >= 0 && jr < nx then add right i (c.gain_right *. (x.(jr) *. c.volume))
              done);
         s.at <- s.at + k);
  m.shots <- List.filter (fun s -> s.at < s.len) m.shots;
  let samples = Float.Array.make n 0. and gone = ref [] in
  m.continuous
  |> Hashtbl.iter (fun name c ->
         if c.kept then c.running <- Synth.continue_into c.running c.voice samples n
         else (
           gone := name :: !gone;
           let silent = { c.voice with volume = 0. } in
           ignore (Synth.continue_into c.running silent samples n));
         (match c.filter with
          | None -> ()
          | Some f ->
              let q = Filter.biquad f.kind ~cutoff:f.cutoff ~q:f.q in
              for i = 0 to n - 1 do
                let x = Float.Array.get samples i in
                Float.Array.set samples i (Filter.step q c.memory x)
              done);
         let (l0, r0) = Space.pan c.last_pan and (l1, r1) = Space.pan c.pan in
         for i = 0 to n - 1 do
           let x = Float.Array.get samples i in
           let a = float_of_int (i + 1) /. float_of_int n in
           add left i (x *. (l0 +. ((l1 -. l0) *. a)));
           add right i (x *. (r0 +. ((r1 -. r0) *. a)))
         done;
         c.last_pan <- c.pan;
         c.kept <- false);
  List.iter (Hashtbl.remove m.continuous) !gone;
  let stopped = ref [] in
  m.loops
  |> Hashtbl.iter (fun name l ->
         let len = length l.sound in
         l.prepare l.pos n;
         for i = 0 to n - 1 do
           let fade = if l.stopping then 1. -. (float_of_int i /. float_of_int n) else 1. in
           add left i (fade *. l.sound.left.(l.pos));
           add right i (fade *. l.sound.right.(l.pos));
           l.pos <- (l.pos + 1) mod len
         done;
         l.played <- l.played + n;
         if l.stopping then stopped := name :: !stopped);
  List.iter (Hashtbl.remove m.loops) !stopped;
  let ended = ref [] in
  m.instruments
  |> Hashtbl.iter (fun name i ->
         let block : Signal.stereo = { left = Array.make n 0.; right = Array.make n 0. } in
         i.live.fill block;
         for k = 0 to n - 1 do
           let fade = if i.ending then 1. -. (float_of_int k /. float_of_int n) else 1. in
           add left k (fade *. block.left.(k));
           add right k (fade *. block.right.(k))
         done;
         if i.ending then ended := name :: !ended);
  List.iter (Hashtbl.remove m.instruments) !ended;
  let limit (a : Float.Array.t) : Signal.t =
    Array.init n (fun i -> Mix.soft_clip (Float.Array.get a i))
  in
  let out : Signal.stereo = { left = limit left; right = limit right } in
  if !stereo then out else Signal.both (Signal.mono out)
  end

let playing (m : t) : int * int = (List.length m.shots, Hashtbl.length m.continuous)
let played (m : t) (name : string) : int option = Option.map (fun l -> l.played) (Hashtbl.find_opt m.loops name)
