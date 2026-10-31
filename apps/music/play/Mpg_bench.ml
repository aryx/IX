(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What an .mpg costs, a part at a time, to be run under mini-5i -s (the
 * instructions counted) or by a clock on a board:
 *   mpg_bench open film.mpg      the file read and its streams apart
 *   mpg_bench sound film.mpg     and its sound decoded whole
 *   mpg_bench frames film.mpg n  and its first n pictures, not the sound
 * Each run's count less the run before it is the part's cost.
 * ix: the author's playground's libs/graphics/videos/tests/Mpg_bench.ml, by
 * parts and no clock of its own *)

let () =
  Cap.main (fun caps ->
      let argv = CapSys.argv caps in
      let bytes =
        match FS.read_opt caps (Fpath.v argv.(2)) with Some b -> b | None -> failwith "can't read the file"
      in
      let streams = Mpeg_system.of_string bytes in
      let video = Option.get (Mpeg_system.video streams) and audio = Option.get (Mpeg_system.audio streams) in
      match argv.(1) with
      | "open" -> ()
      | "sound" -> ignore (Mpeg_audio.decode audio.bytes)
      | "frames" ->
          let h, movie, _ = Mpeg1.of_string ~residual:false video.bytes in
          let n = min (int_of_string argv.(3)) (Movie.frame_count movie) in
          Console.print caps (Printf.sprintf "%dx%d, %d frames, %d asked\n" h.width h.height (Movie.frame_count movie) n);
          for i = 0 to n - 1 do
            ignore (movie.frame i)
          done
      | _ -> failwith "usage: mpg_bench open|sound|frames file [n]")
