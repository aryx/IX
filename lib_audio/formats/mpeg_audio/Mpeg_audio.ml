(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mpeg_audio.mli *)

(* ix: the author's playground's libs/audio/formats/mpeg_audio/Mpeg_audio.ml; a decoder with a state (create, next: a frame when asked) is ix's, decode over it (docs/plans/plan_audio.md) *)

(* ix: the decoder a frame at a time (create, next), where the whole
 * file at once; decode is over it, its samples the same *)
type t = {
  bytes : string;
  first : Mpeg_audio_header.t;
  mutable frames : (int * Mpeg_audio_header.t) list; (* those not decoded yet *)
  total : int; (* all the frames' samples *)
  filters : Polyphase.t array; (* a channel each *)
  bits : Bitstream.t;
  layer3 : Layer3.state;
}

let create (s : string) : (t, string) result =
  match Mpeg_audio_header.frames s with
  | [] -> Error "no MPEG audio frame"
  | (_, first) :: _ when first.layer = 1 -> Error "MPEG audio Layer I: not read"
  | (_, first) :: _ as frames ->
      let total = List.fold_left (fun n ((_, h) : int * Mpeg_audio_header.t) -> n + h.samples) 0 frames in
      Ok { bytes = s; first; frames; total; filters = [| Polyphase.create (); Polyphase.create () |]; bits = Bitstream.of_string s; layer3 = Layer3.create () }

let header (d : t) : Mpeg_audio_header.t = d.first
let samples (d : t) : int = d.total

(* a frame's samples into [left] and [right] from [at] *)
let frame (d : t) (pos : int) (h : Mpeg_audio_header.t) (left : Signal.t) (right : Signal.t) (at : int) : unit =
  Bitstream.seek d.bits (8 * (pos + 4 + if h.crc then 2 else 0));
  (* the subband samples, per channel, time slot after time slot *)
  let subbands = if h.layer = 2 then Layer2.decode h d.bits else Layer3.decode d.layer3 h d.bytes pos in
  let slots = h.samples / 32 in
  Array.iteri
    (fun ch samples ->
      let out = if ch = 0 then left else right in
      for t = 0 to slots - 1 do
        Polyphase.synthesize d.filters.(ch) (Array.sub samples (t * 32) 32) out (at + (t * 32))
      done)
    subbands;
  if h.channels = 1 then Array.blit left at right at h.samples

let next (d : t) : Signal.stereo option =
  match d.frames with
  | [] -> None
  | (pos, h) :: rest ->
      d.frames <- rest;
      let left = Array.make h.samples 0. and right = Array.make h.samples 0. in
      frame d pos h left right 0;
      Some { Signal.left; right }

let decode (s : string) : (Mpeg_audio_header.t * Signal.stereo, string) result =
  match create s with
  | Error e -> Error e
  | Ok d ->
      let left = Array.make d.total 0. and right = Array.make d.total 0. in
      let at = ref 0 in
      List.iter
        (fun ((pos, h) : int * Mpeg_audio_header.t) ->
          frame d pos h left right !at;
          at := !at + h.samples)
        d.frames;
      Ok (d.first, { Signal.left; right })
