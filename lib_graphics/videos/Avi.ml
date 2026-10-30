(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Avi.mli *)
(* ix: the author's playground's libs/graphics/videos/avi/Avi.ml; reading only, the sound as its file has it *)

type header = { width : int; height : int; rate : int * int; codec : string }

(*****************************************************************************)
(* RIFF *)
(*****************************************************************************)

let u16 (s : string) (i : int) : int = String.get_uint16_le s i
let u32 (s : string) (i : int) : int = Int32.to_int (String.get_int32_le s i) land 0xFFFFFFFF

(* the chunks between [from] and [upto]: (name, where its bytes start,
 * their size); a LIST's name is its type ("hdrl", "movi"), its bytes
 * after the type *)
let chunks (s : string) (from : int) (upto : int) : (string * int * int) list =
  let upto = min upto (String.length s) in
  let rec go i acc =
    if i + 8 > upto then List.rev acc
    else
      let id = String.sub s i 4 and size = u32 s (i + 4) in
      let size = min size (upto - i - 8) in
      let entry = if id = "LIST" && size >= 4 then (String.sub s (i + 8) 4, i + 12, size - 4) else (id, i + 8, size) in
      go (i + 8 + size + (size land 1)) (entry :: acc)
  in
  go from []

let find (name : string) (cs : (string * int * int) list) : (int * int) option =
  List.find_map (fun (n, at, size) -> if n = name then Some (at, size) else None) cs

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

type stream = { kind : string; handler : string; scale : int; rate : int; format : int * int (* strf *) }

let of_string (s : string) : header * Movie.t * (int * float array) option =
  if String.length s < 12 || String.sub s 0 4 <> "RIFF" || String.sub s 8 4 <> "AVI " then failwith "AVI: not an AVI file";
  let top = chunks s 12 (String.length s) in
  let hdrl = match find "hdrl" top with Some (at, size) -> chunks s at (at + size) | None -> failwith "AVI: no headers (hdrl)" in
  let movi = match find "movi" top with Some (at, size) -> (at, size) | None -> failwith "AVI: no data (movi)" in
  (* the streams, in order: stream n's chunks are named "0n.." *)
  let streams =
    List.filter_map
      (fun (n, at, size) ->
        if n <> "strl" then None
        else
          let cs = chunks s at (at + size) in
          match (find "strh" cs, find "strf" cs) with
          | Some (h, _), Some f -> Some { kind = String.sub s h 4; handler = String.sub s (h + 4) 4; scale = u32 s (h + 20); rate = u32 s (h + 24); format = f }
          | _ -> None)
      hdrl
  in
  let numbered = List.mapi (fun i st -> (i, st)) streams in
  let video = match List.find_opt (fun (_, st) -> st.kind = "vids") numbered with Some v -> v | None -> failwith "AVI: no video stream" in
  let vn, vs = video in
  let bitmap, _ = vs.format in
  let width = u32 s (bitmap + 4) and height = abs (Int32.to_int (String.get_int32_le s (bitmap + 8))) in
  let codec = String.sub s (bitmap + 16) 4 in
  if String.uppercase_ascii codec <> "MJPG" then failwith ("AVI: the codec " ^ String.escaped codec ^ ", not read here (only Motion JPEG)");
  (* the data: every chunk of "movi", "rec " lists opened *)
  let rec data at size = List.concat_map (fun (n, a, sz) -> if n = "rec " then data a sz else [ (n, a, sz) ]) (chunks s at (at + size)) in
  let data = data (fst movi) (snd movi) in
  let of_stream n = List.filter (fun (name, _, _) -> String.length name = 4 && int_of_string_opt (String.sub name 0 2) = Some n) data in
  let frames = Array.of_list (List.filter (fun (name, _, sz) -> (String.sub name 2 2 = "dc" || String.sub name 2 2 = "db") && sz > 0) (of_stream vn)) in
  if frames = [||] then failwith "AVI: no frames";
  let rate = if vs.rate > 0 && vs.scale > 0 then (vs.rate, vs.scale) else (1_000_000, max 1 (match find "avih" hdrl with Some (a, _) -> u32 s a | None -> 40_000)) in
  let period = float_of_int (snd rate) /. float_of_int (fst rate) in
  let count = Array.length frames in
  (* the last frame decoded, kept: a player shows each 2 or 3 times (60
   * screens a second for 25 frames) *)
  let last = ref (-1, Rgba_image.create ~width:0 ~height:0) in
  let decode i =
    if fst !last <> i then (let _, at, size = frames.(i) in last := (i, Jpeg.decode (String.sub s at size)));
    snd !last
  in
  let movie : Movie.t =
    {
      width;
      height;
      times = Array.init count (fun i -> float_of_int i *. period);
      duration = float_of_int count *. period;
      (* each frame a JPEG of its own: decoded alone *)
      frame = decode;
    }
  in
  (* the sound: the first audio stream's chunks, end to end *)
  let sound =
    match List.find_opt (fun (_, st) -> st.kind = "auds") numbered with
    | None -> None
    | Some (an, st) ->
        let fmt, _ = st.format in
        let tag = u16 s fmt and channels = u16 s (fmt + 2) and rate = u32 s (fmt + 4) and bits = u16 s (fmt + 14) in
        if tag <> 1 || (bits <> 8 && bits <> 16) || (channels <> 1 && channels <> 2) then failwith "AVI: sound not 8 or 16-bit PCM, mono or stereo";
        let bytes = String.concat "" (List.map (fun (_, at, size) -> String.sub s at size) (of_stream an)) in
        let width = bits / 8 * channels in
        let sample i c =
          let at = (i * width) + (c * bits / 8) in
          if bits = 16 then (let v = u16 bytes at in float_of_int (if v >= 32768 then v - 65536 else v)) /. 32767. else float_of_int (Char.code bytes.[at] - 128) /. 127.
        in
        let mono = Array.init (String.length bytes / width) (fun i -> if channels = 1 then sample i 0 else (sample i 0 +. sample i 1) /. 2.) in
        Some (rate, mono)
  in
  ({ width; height; rate; codec }, movie, sound)
