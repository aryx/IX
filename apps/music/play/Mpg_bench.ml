(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What an .mpg costs, a part at a time, to be run under mini-5i -s (the
 * instructions counted) or by a clock on a board:
 *   mpg_bench open film.mpg      the file read and its streams apart
 *   mpg_bench sound film.mpg     and its sound decoded whole
 *   mpg_bench frames film.mpg n  and its first n pictures, not the sound
 *   mpg_bench draw film.mpg n w h f [floats]  and each drawn in a w by h
 *     window, f times its size, on black, by Blit.resized or as draw_fast
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
      | "draw" ->
          let h, movie, _ = Mpeg1.of_string ~residual:false video.bytes in
          let n = min (int_of_string argv.(3)) (Movie.frame_count movie) in
          let w = int_of_string argv.(4) and wh = int_of_string argv.(5) and f = float_of_string argv.(6) in
          let options = { Shape_render_software.default_options with antialiasing = true } in
          for i = 0 to n - 1 do
            let picture = movie.frame i in
            let fb = Framebuffer.create ~width:w ~height:wh in
            let tw = int_of_float (f *. float_of_int h.width) and th = int_of_float (f *. float_of_int h.height) in
            let bitmap =
              if Array.length argv > 7 && argv.(7) = "floats" then Playground.bitmap (float_of_int tw) (float_of_int th) picture
              else
                Playground.bitmap (float_of_int tw) (float_of_int th) (Blit.resized picture ~width:tw ~height:th)
                |> Playground.move (if (w - tw) land 1 = 1 then 0.5 else 0.) (if (wh - th) land 1 = 1 then 0.5 else 0.)
            in
            let shapes =
              [ Playground.rectangle Playground.black (float_of_int w) (float_of_int wh); bitmap ]
            in
            Shape_render_software.render ~options ~scale:1. fb shapes
          done
      | _ -> failwith "usage: mpg_bench open|sound|frames|draw file [n [w h f [floats]]]")
