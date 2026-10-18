(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* play, a program of TinyKernel.ml's: ../../TinyPlay.ml, a WAV file's
 * sound written to /audio a block at a time (given to tiny-ml with what
 * it is on, as one program: the Makefile).
 *
 *     play /examples/korobeiniki.wav
 *
 * What is here: the file read (TinyLibGUI's read_file), the speaker
 * opened, why not said. OCaml compiles it too, for the host (tiny-play,
 * ../../sdl/): its calls TinyCalls's, the speaker SDL's. *)
open TinyCalls
open TinyLibGUI
open TinyPlay

let () =
  if u_argc () <> 2 then (ignore (u_write 2 "usage: play file.wav\n"); exit 1);
  let out = u_open "/audio" 1 in
  if out < 0 then (ignore (u_write 2 "play: no /audio\n"); exit 1);
  let data = read_file (u_arg 1) in
  (try play out (if data = "" then failwith "no such file, or empty" else data)
   with Failure why -> ignore (u_write 2 ("play: " ^ u_arg 1 ^ ": " ^ why ^ "\n")); exit 1);
  exit 0
