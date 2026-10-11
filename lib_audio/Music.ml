(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Music.mli *)

(* ix: the author's playground's libs/audio/Music.ml; a constructor of Synth's said with its module where mini-ml asks; a score played a block at a time (play_score, fill_score) is ix's (docs/plans/plan_audio.md) *)

let midi_frequency (n : int) : float = 440. *. (2. ** (float_of_int (n - 69) /. 12.))

let midi_number (name : string) : int option =
  let letter = function 'C' -> Some 0 | 'D' -> Some 2 | 'E' -> Some 4 | 'F' -> Some 5 | 'G' -> Some 7 | 'A' -> Some 9 | 'B' -> Some 11 | _ -> None in
  let n = String.length name in
  if n < 2 then None
  else
    match letter (Char.uppercase_ascii name.[0]) with
    | None -> None
    | Some semitone -> (
        let (accidental, rest) =
          match name.[1] with '#' -> (1, String.sub name 2 (n - 2)) | 'b' -> (-1, String.sub name 2 (n - 2)) | _ -> (0, String.sub name 1 (n - 1))
        in
        match int_of_string_opt rest with
        | Some octave when octave >= -1 && octave <= 9 -> Some (((octave + 1) * 12) + semitone + accidental)
        | _ -> None)

let frequency (name : string) : float = match midi_number name with Some n -> midi_frequency n | None -> 0.

let instrument ~(voice : int) ~(voices : int) : Oscillator.waveform * float =
  if voices > 1 && voice = voices - 1 then (Triangle, 0.5) else if voice = 0 then (Square, 0.3) else (Square, 0.18)

(* a drum, by its General MIDI key: short, whatever the note's length --
 * a bass drum a triangle falling from 150 to 50 Hz, a snare noise, a
 * hi-hat short bright noise. Shared by MIDI's channel 10 and a tune's
 * percussion voice (Abc.mli's clef=perc). *)
let drum ~(volume : float) (key : int) : Synth.t =
  let v source f = Synth.Voice { source; frequency = f; slide = None; seconds = 0.2; volume; fade = false; effects = []; envelope = None } in
  match key with
  | 35 | 36 -> v (Synth.Wave Oscillator.Triangle) 150. |> Synth.sliding 50. |> Synth.lasting 0.15 |> Synth.fading |> Synth.louder 2.
  | 38 | 40 -> v Synth.Noise 5000. |> Synth.lasting 0.15 |> Synth.fading
  | 42 | 44 | 46 -> v Synth.Noise 12000. |> Synth.lasting 0.05 |> Synth.fading |> Synth.louder 0.6
  | _ -> v Synth.Noise 3000. |> Synth.lasting 0.1 |> Synth.fading

let to_sound (tune : Abc.tune) : Synth.t =
  let voices = List.length tune.voices in
  let silence seconds = Synth.voice (Wave Sine) 0. |> Synth.louder 0. |> Synth.lasting seconds in
  Synth.Together
    (List.mapi
       (fun i events ->
         let (waveform, volume) = instrument ~voice:i ~voices in
         let is_drums = List.nth_opt tune.drums i = Some true in
         Synth.After
           (List.map
              (fun (e : Abc.event) ->
                match e.notes with
                | [] -> silence e.length
                | notes when is_drums ->
                    (* the drums of a clef=perc voice: each struck, and
                     * the rest of the note's time silent *)
                    Synth.Together (silence e.length :: List.map (drum ~volume:0.25) notes)
                | notes ->
                    let sounding = e.length *. 0.9 in
                    Synth.After
                      [ Synth.Together
                          (List.map
                             (fun n -> Synth.voice (Wave waveform) (midi_frequency n) |> Synth.lasting sounding |> Synth.louder (volume /. 0.5))
                             notes);
                        silence (e.length -. sounding) ])
              events))
       tune.voices)

(* a MIDI note's sound: its instrument, from its channel and program *)
let midi_voice (n : Midi.note) : Synth.t =
  let volume = 0.25 *. float_of_int n.velocity /. 127. in
  let v source f = Synth.Voice { source; frequency = f; slide = None; seconds = n.length; volume; fade = false; effects = []; envelope = None } in
  let f = midi_frequency n.key in
  if n.channel = 9 then drum ~volume n.key
  else
    match n.program / 8 with
    | 0 | 1 -> v (Synth.Wave Oscillator.Square) f |> Synth.fading |> Synth.louder 0.8
    | 3 -> v (Synth.Wave Oscillator.Sawtooth) f |> Synth.fading |> Synth.louder 0.7
    | 4 -> v (Synth.Wave Oscillator.Triangle) f |> Synth.louder 1.5
    | 5 | 6 -> v (Synth.Wave Oscillator.Sawtooth) f |> Synth.louder 0.5
    | 7 -> v (Synth.Wave Oscillator.Sawtooth) f |> Synth.louder 0.7
    | 11 -> v (Synth.Wave Oscillator.Triangle) f
    | _ -> v (Synth.Wave Oscillator.Square) f |> Synth.louder 0.7

let render_score (score : Midi.score) : Signal.t =
  (* a little after the last note, for the drums' tails *)
  let out = Array.make (Signal.samples (score.duration +. 0.2)) 0. in
  List.iter
    (fun (n : Midi.note) ->
      let at = Signal.samples n.start and s = Synth.render (midi_voice n) in
      Array.iteri (fun i x -> if at + i < Array.length out then out.(at + i) <- out.(at + i) +. x) s)
    score.notes;
  out

(* ix: a score a block at a time. A note is rendered when its time comes
 * (Synth.render: a second or two of samples), added to the blocks it
 * sounds in, and dropped; the sums are render_score's, in its order *)
type playing = {
  mutable coming : Midi.note list; (* by their starts *)
  mutable sounding : (int * Signal.t) list; (* where each starts, its samples *)
  mutable at : int;
  length : int;
}

let play_score (score : Midi.score) : playing =
  { coming = score.notes; sounding = []; at = 0; length = Signal.samples (score.duration +. 0.2) }

let score_finished (p : playing) : bool = p.at >= p.length

let fill_score (p : playing) (out : Signal.t) : unit =
  let n = Array.length out in
  Array.fill out 0 n 0.;
  let stop = min (p.at + n) p.length in
  let rec start (notes : Midi.note list) : Midi.note list =
    match notes with
    | note :: rest when Signal.samples note.start < stop ->
        p.sounding <- p.sounding @ [ (Signal.samples note.start, Synth.render (midi_voice note)) ];
        start rest
    | rest -> rest
  in
  p.coming <- start p.coming;
  p.sounding <-
    List.filter
      (fun ((from, s) : int * Signal.t) ->
        let last = min (from + Array.length s) stop in
        for i = max from p.at to last - 1 do
          out.(i - p.at) <- out.(i - p.at) +. s.(i - from)
        done;
        from + Array.length s > stop)
      p.sounding;
  p.at <- p.at + n
