(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's playground/apis/Audio.ml; less the live effects not copied (drive, chorus, flanger, phaser, rotary, compressed), a loop rendered as it is played, the platform's samples asked through Audio_source (docs/plans/plan_audio.md) *)

(* See Audio.mli *)

type sound = Synth.t

let tone f = Synth.voice (Synth.Wave Oscillator.Sine) f
let square f = Synth.voice (Synth.Wave Oscillator.Square) f
let triangle f = Synth.voice (Synth.Wave Oscillator.Triangle) f
let sawtooth f = Synth.voice (Synth.Wave Oscillator.Sawtooth) f
let noise roughness = Synth.voice Synth.Noise roughness
let pluck f = Synth.voice Synth.Pluck f
let fm f ratio index = Synth.voice (Synth.Fm { ratio; index }) f
let note name = tone (Music.frequency name)
let lasting = Synth.lasting
let fading = Synth.fading
let louder = Synth.louder
let sliding = Synth.sliding
let together sounds = Synth.Together sounds
let after sounds = Synth.After sounds
let filtered (kind : Filter.kind) ~(q : float) (cutoff : float) (cutoff_to : float) (s : sound) : sound = Synth.Filtered ({ Synth.kind; cutoff; cutoff_to; q }, s)

(* Butterworth's Q, the flattest; the wah's 5, a +14 dB ring *)
let low_pass cutoff = filtered Filter.Low_pass ~q:0.707 cutoff cutoff
let high_pass cutoff = filtered Filter.High_pass ~q:0.707 cutoff cutoff
(* the resonance rings up to 5 times as loud: the sound turned down
 * first, not to be cut by the mixer *)
let wah from to_ s = filtered Filter.Low_pass ~q:5. from to_ (Synth.louder 0.4 s)
let naive = Synth.naive

let tune (who : string) (parse : string -> (Abc.tune, string) result) (text : string) : sound =
  match parse text with
  | Ok tune -> Music.to_sound tune
  | Error e ->
      prerr_endline (who ^ ": not a tune: " ^ e);
      Synth.After []

let abc = tune "Audio.abc" Abc.parse
let doremi = tune "Audio.doremi" Doremi.parse
let of_tune = Music.to_sound

let wav (bytes : string) : sound =
  match Wav.of_string bytes with
  | Ok samples -> Synth.Samples samples
  | Error e ->
      prerr_endline ("Audio.wav: " ^ e);
      Synth.After []

let recorded (s : sound) : sound = Synth.Samples (Synth.render s)

let midi (bytes : string) : sound =
  match Midi.parse bytes with
  | Ok score -> Synth.Samples (Music.render_score score)
  | Error e ->
      prerr_endline ("Audio.midi: " ^ e);
      Synth.After []

let vibrato rate depth = Synth.with_effect (Pitch_effect.Vibrato { rate; depth })
let arpeggio semitones step = Synth.with_effect (Pitch_effect.Arpeggio { semitones; step })
let echo delay feedback s = Synth.Echo ({ Synth.delay; feedback = (if feedback > 0.95 then 0.95 else if feedback < 0. then 0. else feedback) }, s)
let reverb seconds s = Synth.Reverb ((if seconds < 0.01 then 0.01 else seconds), s)

(* the ready-made sounds: audio/Sfx's presets, after sfxr's categories *)
let sfx = Sfx.to_sound
let random_sound (category : string) (seed : int) : sound = sfx (Sfx.random category ~seed)
let blip = sfx Sfx.blip
let coin = sfx Sfx.coin
let jump = sfx Sfx.jump
let laser = sfx Sfx.laser
let hit = sfx Sfx.hit
let explosion = sfx Sfx.explosion
let step = sfx Sfx.step
let powerup = sfx Sfx.powerup

let varied (name : string) (seed : int) : sound =
  match List.assoc_opt name Sfx.presets with
  | Some s -> sfx (Sfx.vary ~seed s)
  | None ->
      prerr_endline ("Audio.varied: no such sound " ^ name);
      Synth.After []

(* the mixer every sound goes to; the platform pulls its samples *)
let mixer = Mixer.create ()

(* claude: while true, nothing starts playing (silently, for tinybox's
 * previews: a program run in the menu's process, heard by no one) *)
let muted = ref false

let silently (f : unit -> 'a) : 'a =
  let before = !muted in
  muted := true;
  match f () with
  | x -> muted := before; x
  | exception e -> muted := before; raise e

(* ix: a sound's samples kept from one play to the next, where the
 * playground renders them at each: a game plays the same few sounds
 * (Audio.laser, Audio.explosion: one value each), and a render is all
 * of the sound at once, in the tick that asks. An explosion is some
 * 100 million instructions of mini-ml's on arm, a fifth of a second
 * of a Pi 1 at best, at every burst (the author, of TinyMissileCommand
 * there, 2026-10-13: "the framerate is extremely slow"). The same
 * value (==) is the same samples, which the mixer reads and does not
 * change; a sound made anew each time (Audio.varied) is rendered each
 * time, as before. The last eight: a game's few sounds, and not a
 * second of floats for each sound there ever was. *)
let rendered : (sound * Signal.stereo) list ref = ref []

let render_once (s : sound) : Signal.stereo =
  match List.find_opt (fun ((s', _) : sound * Signal.stereo) -> s' == s) !rendered with
  | Some (_, samples) -> samples
  | None ->
      let samples = Synth.render_stereo s in
      rendered := (s, samples) :: List.filteri (fun (i : int) (_ : sound * Signal.stereo) -> i < 7) !rendered;
      samples

(* old: Mixer.play mixer (Synth.render_stereo s) *)
let play (s : sound) : unit = if not !muted then Mixer.play mixer (render_once s)

(* a continuous sound's voices, each kept under its own name, with the
   filter it's under and its pan (after: only the first sound goes on;
   filters nested: the outermost; pans nested: the innermost) *)
(* ix: filter and pan were optional *)
let rec voices (filter : Synth.filter option) (pan : float option) (s : sound) : (Synth.voice * Synth.filter option * float option) list =
  match s with
  | Synth.Voice v -> [ (v, filter, pan) ]
  | Synth.Together l -> List.concat (List.map (voices filter pan) l)
  | Synth.After (s :: _) -> voices filter pan s
  | Synth.Echo (_, s) -> voices filter pan s
  | Synth.Reverb (_, s) -> voices filter pan s
  | Synth.Processed (_, s) -> voices filter pan s
  | Synth.Filtered (f, s) -> voices (match filter with Some _ -> filter | None -> Some f) pan s
  | Synth.Panned (p, s) -> voices filter (Some p) s
  | Synth.After [] | Synth.Samples _ -> []

let keep_playing (name : string) (s : sound) : unit =
  if not !muted then
    List.iteri (fun i ((v, filter, pan) : Synth.voice * Synth.filter option * float option) ->
        Mixer.keep ~filter ~pan:(match pan with Some p -> p | None -> 0.) mixer (Printf.sprintf "%s#%d" name i) v) (voices None None s)

(* ix: a loop is rendered as it is played, where the playground renders
 * it whole before its first sample (a tune of a minute: 2.6 million
 * samples; Tetris's theme, 13 seconds, is 7 seconds of a Pi 1). Its
 * samples are zeros at first; before the mixer reads a stretch, the
 * voices that sound in it and are not yet rendered are, and added
 * where they go (Synth.pieces). Once around, all of it is there. A
 * sound whose pieces are not known (an echo over all of it, a pan) is
 * rendered whole, as before. *)
let prepared (s : sound) : Signal.stereo * (int -> int -> unit) =
  match Synth.length s with
  | Some total when total > 0 ->
      let samples = Array.make total 0. in
      let waiting = ref (Synth.pieces s) in
      let prepare (pos : int) (n : int) : unit =
        (* the stretch read: [pos, pos + n), and around the end *)
        let sounds_in ((at, len, _) : int * int * Synth.t) : bool =
          let overlaps (from : int) (upto : int) : bool = at < upto && at + len > from in
          overlaps pos (pos + n) || (pos + n > total && overlaps 0 (pos + n - total)) in
        if !waiting <> [] then begin
          let (now, later) = List.partition sounds_in !waiting in
          waiting := later;
          List.iter (fun ((at, _, piece) : int * int * Synth.t) ->
              let x = Synth.render piece in
              for i = 0 to min (Array.length x) (total - at) - 1 do
                samples.(at + i) <- samples.(at + i) +. x.(i)
              done) now
        end in
      (Signal.both samples, prepare)
  | _ -> (Synth.render_stereo s, fun _ _ -> ())

let loop (name : string) (s : sound) : unit =
  if not !muted && not (List.mem name (Mixer.looping mixer)) then begin
    let (samples, prepare) = prepared s in
    Mixer.loop_prepared mixer name samples prepare
  end

(* the platform's way to get a file's bytes; none until run_app *)
let fetcher : (string -> (string option -> unit) -> unit) ref = ref (fun _ k -> k None)
let set_fetcher f = fetcher := f
let fetch (source : string) (k : string option -> unit) : unit = !fetcher source k

(* the loops asked for with loop_from, playing or still downloading:
 * asked once *)
let requested : (string, unit) Hashtbl.t = Hashtbl.create 2

(* a module's song, played by its own player (not rendered ahead: a
 * song of minutes would be hundreds of megabytes of samples), pulled by
 * the mixer as an instrument *)
let play_module (name : string) (bytes : string) : unit =
  match Mod.of_string bytes with
  | Error e -> prerr_endline ("Audio.play_module: " ^ e)
  | Ok song ->
      let p = Mod_player.create ~loop:true song in
      Mixer.instrument mixer name
        { Instrument.note_on = (fun _ _ -> ()); note_off = (fun _ -> ()); set = (fun _ _ -> ()); fill = Mod_player.fill p }

let loop_from (name : string) (source : string) : unit =
  if not !muted && not (Hashtbl.mem requested name) then (
    Hashtbl.replace requested name ();
    !fetcher source (fun (got : string option) ->
      match got with
      | None ->
          prerr_endline ("Audio.loop_from: can't get " ^ source);
          Hashtbl.remove requested name
      | Some bytes ->
          let ends_with = Filename.check_suffix (String.lowercase_ascii source) in
          if ends_with ".mod" then play_module name bytes
          else
            let read =
              if ends_with ".mid" || ends_with ".midi" then midi
              else if ends_with ".abc" then abc
              else if ends_with ".wav" then wav
              else doremi
            in
            Mixer.loop mixer name (Synth.render_stereo (read bytes))))

let faster = Synth.faster
let change_loop (name : string) (s : sound) : unit =
  if not !muted then begin
    let (samples, prepare) = prepared s in
    Mixer.change_prepared mixer name samples prepare
  end

let pan (p : float) (s : sound) : sound = Synth.Panned (p, s)
let pitched = Synth.pitched

(* the screen's centre the listener; half the width (500) the side *)
let from (x : float) (y : float) (s : sound) : sound =
  let d = Float.hypot x y in
  Synth.Panned (x /. 500., s) |> Synth.louder (Space.attenuation ~reference:700. d)

type instrument = Instrument.t

(* the instruments asked for, by name; the mixer's list says which still
 * play (a stopped one is made afresh when asked for again) *)
let instruments : (string, Instrument.t) Hashtbl.t = Hashtbl.create 2

let instrument (name : string) (make : unit -> Instrument.t) : instrument =
  (* claude: muted, an instrument of its own, which the mixer never pulls *)
  if !muted then make () else
  match Hashtbl.find_opt instruments name with
  | Some i when List.mem name (Mixer.instruments mixer) -> i
  | _ ->
      let i = make () in
      Hashtbl.replace instruments name i;
      Mixer.instrument mixer name i;
      i

let note_on (i : instrument) (name : string) : unit = match Music.midi_number name with Some key -> i.note_on key 1. | None -> ()
let note_off (i : instrument) (name : string) : unit = match Music.midi_number name with Some key -> i.note_off key | None -> ()
let set (i : instrument) (knob : string) (value : float) : unit = i.set knob value

let stop (name : string) : unit =
  Hashtbl.remove requested name;
  Mixer.stop mixer name
let pull (n : int) : Signal.stereo = Mixer.pull mixer n

let position (name : string) : float option =
  Option.map (fun n -> float_of_int n /. float_of_int Signal.rate) (Mixer.played mixer name)

(* the platforms' reports, averaged over about a second (a one-pole, a
 * 60th of the way each frame): the queue swings by a frame from one
 * frame to the next, the average is what a player feels *)
let latest = ref None

let set_latency (seconds : float) : unit =
  latest := Some (match !latest with None -> seconds | Some l -> l +. ((seconds -. l) /. 60.))

let latency () : float = match !latest with Some l -> l | None -> 0.

(* ix: a platform finds the samples here (Audio_source.mli) *)
let () =
  Audio_source.source := Some { Audio_source.pull = (fun (n : int) -> let s = pull n in (s.left, s.right)); latency = set_latency }
