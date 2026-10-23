(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Player.mli *)

type t = { fill : Signal.stereo -> unit; finished : unit -> bool }

let of_samples (s : Signal.stereo) : t =
  let at = ref 0 and length = Array.length s.left in
  let fill (out : Signal.stereo) : unit =
    let n = Array.length out.left in
    let have = max 0 (min n (length - !at)) in
    Array.blit s.left !at out.left 0 have;
    Array.blit s.right !at out.right 0 have;
    Array.fill out.left have (n - have) 0.;
    Array.fill out.right have (n - have) 0.;
    at := !at + n
  in
  { fill; finished = (fun () -> !at >= length) }

let of_mod (song : Mod.song) : t =
  let p = Mod_player.create ~loop:false song in
  { fill = Mod_player.fill p; finished = (fun () -> Mod_player.finished p) }

let of_ogg (p : Vorbis_player.t) : t =
  { fill = Vorbis_player.fill p; finished = (fun () -> Vorbis_player.finished p) }

let of_score (score : Midi.score) : t =
  let p = Music.play_score score in
  let fill (out : Signal.stereo) : unit =
    Music.fill_score p out.left;
    Array.blit out.left 0 out.right 0 (Array.length out.left)
  in
  { fill; finished = (fun () -> Music.score_finished p) }

(* a file at Signal's rate: the frame being played and where in it *)
let of_mpeg_at_rate (d : Mpeg_audio.t) : t =
  let frame : Signal.stereo ref = ref { Signal.left = [||]; right = [||] } and at = ref 0 and ended = ref false in
  let fill (out : Signal.stereo) : unit =
    let n = Array.length out.left and done_ = ref 0 in
    while !done_ < n && not !ended do
      if !at >= Array.length !frame.left then (
        match Mpeg_audio.next d with
        | None -> ended := true
        | Some f ->
            frame := f;
            at := 0)
      else
        let have = min (n - !done_) (Array.length !frame.left - !at) in
        Array.blit !frame.left !at out.left !done_ have;
        Array.blit !frame.right !at out.right !done_ have;
        at := !at + have;
        done_ := !done_ + have
    done;
    Array.fill out.left !done_ (n - !done_) 0.;
    Array.fill out.right !done_ (n - !done_) 0.
  in
  { fill; finished = (fun () -> !ended) }

(* a file at another rate: each sample out is read between two of the
 * file's (Resample's Linear), the second maybe the next frame's first:
 * two frames are held, the one being read and the one after. The
 * samples are those of the whole file resampled. *)
let of_mpeg_resampled (d : Mpeg_audio.t) (rate : int) : t =
  let k = float_of_int rate /. float_of_int Signal.rate in
  let length = int_of_float (float_of_int (Mpeg_audio.samples d) /. k) in
  let silence : Signal.stereo = { left = [||]; right = [||] } in
  let frame = ref silence and after = ref silence in
  let base = ref 0 (* the file's sample that is [frame]'s first *) and at = ref 0 (* the samples given *) in
  let fetch () : Signal.stereo = match Mpeg_audio.next d with Some f -> f | None -> silence in
  after := fetch ();
  let fill (out : Signal.stereo) : unit =
    for j = 0 to Array.length out.left - 1 do
      if !at >= length then (
        out.left.(j) <- 0.;
        out.right.(j) <- 0.)
      else
        let position = float_of_int !at *. k in
        let i = int_of_float position in
        let t = position -. float_of_int i in
        while i - !base >= Array.length !frame.left && Array.length !after.left > 0 do
          base := !base + Array.length !frame.left;
          frame := !after;
          after := fetch ()
        done;
        let i = i - !base in
        let read (s : Signal.t) (next : Signal.t) : float =
          let n = Array.length s in
          let a = if i < n then s.(i) else 0. in
          let b = if i + 1 < n then s.(i + 1) else if i + 1 = n && Array.length next > 0 then next.(0) else 0. in
          a +. (t *. (b -. a))
        in
        out.left.(j) <- read !frame.left !after.left;
        out.right.(j) <- read !frame.right !after.right;
        incr at
    done
  in
  { fill; finished = (fun () -> !at >= length) }

let of_mpeg (d : Mpeg_audio.t) : t =
  let rate = (Mpeg_audio.header d).sample_rate in
  if rate = Signal.rate then of_mpeg_at_rate d else of_mpeg_resampled d rate

let of_file (name : string) (bytes : string) : (t, string) result =
  let ends = Filename.check_suffix (String.lowercase_ascii name) in
  if ends ".mod" then Result.map of_mod (Mod.of_string bytes)
  else if ends ".mid" || ends ".midi" then Result.map of_score (Midi.parse bytes)
  else if ends ".mp3" || ends ".mp2" then Result.map of_mpeg (Mpeg_audio.create bytes)
  else if ends ".wav" then Result.map of_samples (Wav.stereo_of_string bytes)
  else if ends ".ogg" then Result.map of_ogg (Vorbis_player.create ~loop:false bytes)
  else if ends ".abc" then Result.map (fun tune -> of_samples (Synth.render_stereo (Music.to_sound tune))) (Abc.parse bytes)
  else Error "not a .mod, .mid, .mp3, .mp2, .wav, .ogg or .abc"
