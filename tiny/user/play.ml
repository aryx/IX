(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* play, a program of TinyKernel.ml's: ../TinyPlay.ml, a WAV file's
 * sound written to /dev/audio a block at a time.
 *
 *     play /examples/korobeiniki.wav
 *
 * What is here: the file read, the speaker
 * opened, why not said. OCaml compiles it too, for the host (tiny-play,
 * sdl/): its system TinyLibSystem's, the speaker SDL's. *)
module TSys = TinyLibSystem

(* (the messages as before: the usage on its own, a file's trouble after
 * its name, which main says after play's) *)
let () =
  TSys.main "play" (fun caps argv ->
    if Array.length argv <> 2 then begin
      TSys.eprint caps "usage: play file.wav\n";
      Exit.Code 1
    end
    else
      let file = argv.(1) in
        let out = TSys.open_out caps (Fpath.v "/dev/audio") in
        let data = try TSys.read_file caps (Fpath.v file) with Failure _ -> "" in
        (try
           TinyPlay.play out
             (if data = "" then failwith "no such file, or empty" else data)
         with Failure why -> failwith (file ^ ": " ^ why));
        Exit.OK)
