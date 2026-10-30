(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Avi: a clip of ffmpeg's (clips/make_clips.sh, which needs it; the clip is
 * checked in): its header, its frames against each other, its sound; what
 * is refused. The playground's test wrote its own, by the writer left there. *)

let t = Testo.create

let read_file (path : string) : string =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> really_input_string ic (in_channel_length ic))

(* the repository's top, whichever directory Testo runs from *)
let rec top (dir : string) : string =
  if Sys.file_exists (Filename.concat dir "license.txt") then dir
  else if Filename.dirname dir = dir then failwith "the repository's top not found"
  else top (Filename.dirname dir)

let file () = read_file (Filename.concat (top (Sys.getcwd ())) "lib_graphics/videos/tests/clips/testsrc_mjpeg.avi")

let read () =
  let h, movie, sound = Avi.of_string (file ()) in
  Alcotest.(check int) "width" 64 h.width;
  Alcotest.(check int) "height" 48 h.height;
  Alcotest.(check string) "codec" "MJPG" (String.uppercase_ascii h.codec);
  Alcotest.(check int) "10 frames" 10 (Movie.frame_count movie);
  Alcotest.(check (float 0.0001)) "a second" 1. movie.duration;
  (* every frame a JPEG alone: any frame at once, and the same asked again *)
  let last = movie.frame 9 in
  let first = movie.frame 0 in
  Alcotest.(check int) "its pixels' size" (64 * 48 * 4) (Bytes.length first.rgba);
  Alcotest.(check bool) "frames differ" true (not (Bytes.equal first.rgba last.rgba));
  Alcotest.(check bool) "frame 9 again, after frame 0" true (Bytes.equal last.rgba (movie.frame 9).rgba);
  match sound with
  | None -> Alcotest.fail "no sound"
  | Some (rate, samples) ->
      Alcotest.(check int) "its rate" 8000 rate;
      Alcotest.(check bool) "about a second of it" true (abs (Array.length samples - 8000) < 800);
      let loudest = Array.fold_left (fun m x -> Float.max m (Float.abs x)) 0. samples in
      Alcotest.(check bool) "it is a sound, within -1 to 1" true (loudest > 0.01 && loudest <= 1.)

let refused () =
  let other = Bytes.of_string (file ()) in
  let s = Bytes.to_string other in
  (* the codec's four letters, in strf, changed: not read *)
  let at = (let rec find i = if String.sub s i 4 = "strf" then i else find (i + 1) in find 0) + 8 + 16 in
  Bytes.blit_string "XVID" 0 other at 4;
  (match Avi.of_string (Bytes.to_string other) with
  | _ -> Alcotest.fail "another codec read"
  | exception Failure _ -> ());
  match Avi.of_string "RIFF\000\000\000\000WAVE" with
  | _ -> Alcotest.fail "a WAV read"
  | exception Failure _ -> ()

let tests = [ t "Avi: a clip of ffmpeg's, Motion JPEG and PCM" read; t "Avi: what is refused" refused ]
