(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's playground/apis/Audio.ml; less the live effects not copied (chorus, flanger, phaser, rotary), a loop rendered as it is played, the platform's samples asked through Audio_source; play_ogg (docs/plans/plan_audio.md) *)

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

(* the live effects (effects/), run over the sound rendered: a fresh
 * effect for each rendering (ix: tail was optional, 0) *)
let processed (tail : float) (make : unit -> Signal.stereo -> unit) (s : sound) : sound =
  Synth.Processed ({ Synth.make; tail }, s)

(* [gain] dB in, [gain] dB back out: a pedal's drive knob with its level
 * knob turned to match. Oversampled x2, not x4: a whole sound is
 * rendered at once, and a 20 s loop took 1.2 s natively at x4 (2.1 s in
 * a browser), a game frozen that long; x2 halves it, its aliases at -58.6
 * dB still (Drive.mli). A sound in the middle (both sides the same, the
 * common case) is driven once and copied, halving it again. *)
let drive (gain : float) : sound -> sound =
  processed 0. (fun () ->
      let left = Drive.create ~oversampling:2 () and right = Drive.create ~oversampling:2 () in
      let back = 1. /. Mix.of_decibels gain in
      fun (st : Signal.stereo) ->
        let mono = st.left = st.right in
        Drive.process left Drive.Tanh ~drive:gain ~mix:1. st.left;
        Array.iteri (fun (i : int) (x : float) -> st.left.(i) <- back *. x) st.left;
        if mono then Array.blit st.left 0 st.right 0 (Array.length st.left)
        else begin
          Drive.process right Drive.Tanh ~drive:gain ~mix:1. st.right;
          Array.iteri (fun (i : int) (x : float) -> st.right.(i) <- back *. x) st.right
        end)

let compressed (threshold : float) (ratio : float) : sound -> sound =
  processed 0. (fun () ->
      Dynamics.process ~key:None (Dynamics.create ())
        { Dynamics.compressor with threshold; ratio = (if ratio < 1. then 1. else ratio) })

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
 * voices that sound in it are rendered as far as the stretch goes, and
 * added where they go (Synth.pieces). Once around, all of it is there.
 * A sound whose pieces are not known (an echo over all of it, a pan)
 * is rendered whole, as before.
 *
 * Two things more, for the board (the author, of Tetris on the Pi 2,
 * 2026-10-12: "tetris now seems really slow, it was at 4fps, even
 * alone"; counted on arm, mini-5i: a frame was 7 million instructions
 * of mini-ml's while the theme was first played, and 1.9 once it had
 * gone round):
 * - a voice is rendered up to the stretch read and no further
 *   (Synth.voice_steps), where it was rendered whole when its first
 *   sample was asked: a long note was tens of millions of
 *   instructions in one tick, a quarter of a second, and the frames
 *   came in bursts;
 * - a tune says the same voice many times (the theme's bass is eight
 *   notes, each said eight times): its samples are rendered once
 *   (notes), and kept until the tune is whole.
 * The samples are the same ones, in the same order of additions.
 * old:
 *   let waiting = ref (Synth.pieces s) in
 *   let prepare (pos : int) (n : int) : unit =
 *     let sounds_in ((at, len, _) : int * int * Synth.t) : bool = ... in
 *     if !waiting <> [] then begin
 *       let (now, later) = List.partition sounds_in !waiting in
 *       waiting := later;
 *       List.iter (fun ((at, _, piece) : int * int * Synth.t) ->
 *           let x = Synth.render piece in
 *           for i = 0 to min (Array.length x) (total - at) - 1 do
 *             samples.(at + i) <- samples.(at + i) +. x.(i)
 *           done) now
 *     end in *)
(* a voice's samples, as far as they were asked *)
type note = { step : int -> float; buf : Signal.t; mutable upto : int }
(* a piece of the tune: where it goes, and how much of it is there *)
type piece = { at : int; len : int; sound : Synth.t; mutable added : int }

let prepared (s : sound) : Signal.stereo * (int -> int -> unit) =
  match Synth.length s with
  | Some total when total > 0 ->
      let samples = Array.make total 0. in
      let waiting = ref (List.map (fun ((at, len, sound) : int * int * Synth.t) -> { at; len; sound; added = 0 }) (Synth.pieces s)) in
      let notes : (Synth.voice * note) list ref = ref [] in
      let note_of (v : Synth.voice) : note =
        match List.find_opt (fun ((v', _) : Synth.voice * note) -> v' = v) !notes with
        | Some (_, n) -> n
        | None ->
            let (n, step) = Synth.voice_steps v in
            let note = { step; buf = Array.make n 0.; upto = 0 } in
            notes := (v, note) :: !notes;
            note in
      (* the piece's samples up to its [want]-th, in the tune *)
      let feed (p : piece) (want : int) : unit =
        let all = min p.len (total - p.at) in
        let x, want =
          match p.sound with
          | Synth.Voice v ->
              let note = note_of v in
              let want = min want (min all (Array.length note.buf)) in
              for i = note.upto to want - 1 do note.buf.(i) <- note.step i done;
              if want > note.upto then note.upto <- want;
              (note.buf, want)
          (* (what is not a voice: all of it at once) *)
          | sound -> let x = Synth.render sound in (x, min all (Array.length x)) in
        for i = p.added to want - 1 do
          samples.(p.at + i) <- samples.(p.at + i) +. x.(i)
        done;
        if want > p.added then p.added <- want;
        (match p.sound with Synth.Voice _ -> () | _ -> p.added <- all) in
      let prepare (pos : int) (n : int) : unit =
        if !waiting <> [] then begin
          (* the stretch read: [pos, pos + n), and around the end *)
          List.iter (fun (p : piece) ->
              if p.at < pos + n && p.at + p.len > pos then feed p (pos + n - p.at);
              if pos + n > total && p.at < pos + n - total then feed p (pos + n - total - p.at)) !waiting;
          waiting := List.filter (fun (p : piece) ->
              p.added < min p.len (total - p.at) && (match p.sound with Synth.Voice v -> p.added < Signal.samples v.seconds | _ -> true)) !waiting;
          if !waiting = [] then notes := []
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

(* an .ogg's sound, decoded as the mixer pulls it, the same way *)
let play_ogg (name : string) (bytes : string) : unit =
  match Vorbis_player.create ~loop:true bytes with
  | Error e -> prerr_endline ("Audio.play_ogg: " ^ e)
  | Ok p ->
      Mixer.instrument mixer name
        { Instrument.note_on = (fun _ _ -> ()); note_off = (fun _ -> ());
          set = (fun _ _ -> ()); fill = Vorbis_player.fill p }

(* ix: a MIDI song the same way, a block at a time (Music.play_score),
 * again from its start when it ends. midi renders it whole: mini-doom's
 * first song, 186 seconds, is 8 million floats, past the largest block
 * on a 32-bit machine (and a hundred megabytes of heap) *)
let play_midi (name : string) (bytes : string) : unit =
  match Midi.parse bytes with
  | Error e -> prerr_endline ("Audio.play_midi: " ^ e)
  | Ok score ->
      if not !muted then begin
        let p = ref (Music.play_score score) in
        let fill (out : Signal.stereo) : unit =
          if Music.score_finished !p then p := Music.play_score score;
          Music.fill_score !p out.left;
          Array.blit out.left 0 out.right 0 (Array.length out.left)
        in
        Mixer.instrument mixer name
          { Instrument.note_on = (fun _ _ -> ()); note_off = (fun _ -> ()); set = (fun _ _ -> ()); fill }
      end

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
          else if ends_with ".ogg" then play_ogg name bytes
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

(* ix: a recording mixed from its own samples, its volume and pan
 * applied as the mixer pulls it (Mixer.play_at): a sound made louder
 * and panned at each play was rendered whole, new arrays each time
 * (mini-doom's and mini-quake's monsters, plan_virtuaracing.md,
 * stage 5); any other sound the old way *)
let play_at ~(volume : float) ~(pan : float) (s : sound) : unit =
  if not !muted then
    match s with
    | Synth.Samples x -> Mixer.play_at mixer x ~volume ~pan
    | _ -> play (Synth.Panned (pan, louder volume s))

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
