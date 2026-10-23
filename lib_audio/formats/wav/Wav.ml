(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wav.mli *)

(* ix: the author's playground's libs/audio/formats/wav/Wav.ml; no file read or written here (write, read, write_stereo: the caller's, through its capabilities), stereo_to_string in their place, and stereo_of_string, a file's two channels kept; a sample of 16 bits read and written through the unsigned ones; a WAV of 8 bits read too (mini-quake's sounds) (docs/plans/plan_audio.md) *)

(* [channels] interleaved: the frames, each a sample per channel *)
let to_string_channels (channels : Signal.t list) : string =
  let c = List.length channels in
  let n = match channels with [] -> 0 | s :: _ -> Array.length s in
  let b = Buffer.create (44 + (2 * c * n)) in
  let u32 v = Buffer.add_int32_le b (Int32.of_int v) and u16 v = Buffer.add_uint16_le b v in
  Buffer.add_string b "RIFF";
  u32 (36 + (2 * c * n));
  Buffer.add_string b "WAVEfmt ";
  u32 16;
  u16 1;
  u16 c;
  u32 Signal.rate;
  u32 (2 * c * Signal.rate);
  u16 (2 * c);
  u16 16;
  Buffer.add_string b "data";
  u32 (2 * c * n);
  for i = 0 to n - 1 do
    List.iter (fun s -> Buffer.add_uint16_le b (Signal.to_int16 s.(i) land 0xFFFF)) channels
  done;
  Buffer.contents b

let to_string (samples : Signal.t) : string = to_string_channels [ samples ]

(* the chunks after "RIFF" size "WAVE": each a 4-letter name, a size,
 * its bytes (padded to an even size); "fmt " and "data" are the two we
 * need, and a file may have others (LIST, fact, ...) before, between,
 * after *)
let chunks (s : string) : (string * int * int) list =
  let rec go i acc =
    if i + 8 > String.length s then List.rev acc
    else
      let size = Int32.to_int (String.get_int32_le s (i + 4)) in
      go (i + 8 + size + (size land 1)) ((String.sub s i 4, i + 8, size) :: acc)
  in
  go 12 []

(* ix: both channels kept (stereo_of_string), of_string over it *)
let stereo_of_string (s : string) : (Signal.stereo, string) result =
  if String.length s < 12 || String.sub s 0 4 <> "RIFF" || String.sub s 8 4 <> "WAVE" then Error "not a WAV file"
  else
    let cs = chunks s in
    match (List.find_opt (fun (n, _, _) -> n = "fmt ") cs, List.find_opt (fun (n, _, _) -> n = "data") cs) with
    | Some (_, fmt, _), Some (_, data, size) ->
        let u16 i = String.get_uint16_le s (fmt + i) in
        let channels = u16 2 and rate = Int32.to_int (String.get_int32_le s (fmt + 4)) in
        let bits = u16 14 in
        if u16 0 <> 1 || (bits <> 16 && bits <> 8) || (channels <> 1 && channels <> 2) then Error "not 8- or 16-bit PCM, mono or stereo"
        else
          let size = min size (String.length s - data) in
          let bytes = bits / 8 in
          let frames = size / (bytes * channels) in
          let s16 j = let v = String.get_uint16_le s j in if v >= 0x8000 then v - 0x10000 else v in
          (* ix: 8 bits too, unsigned, 128 the silence (Quake's sounds) *)
          let sample j = if bytes = 1 then float_of_int (Char.code s.[j] - 128) /. 127. else float_of_int (s16 j) /. 32767. in
          let channel c = Resample.to_rate Linear rate (Array.init frames (fun i -> sample (data + (bytes * ((i * channels) + c))))) in
          let left = channel 0 in
          Ok { Signal.left; right = (if channels = 1 then left else channel 1) }
    | _ -> Error "no fmt or no data chunk"

(* stereo mixed down: a sound here is mono until panned *)
let of_string (s : string) : (Signal.t, string) result =
  match stereo_of_string s with Error e -> Error e | Ok st -> Ok (if st.left == st.right then st.left else Signal.mono st)

let stereo_to_string (s : Signal.stereo) : string = to_string_channels [ s.left; s.right ]
