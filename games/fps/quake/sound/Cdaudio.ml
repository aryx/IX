(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cdaudio.mli *)

let track (level : Model.t) : string =
  let n =
    match level.entities with
    | w :: _ -> (
        match Option.bind (Model.value w "sounds") int_of_string_opt with
        | Some n when n >= 2 -> n
        | _ -> 2)
    | [] -> 2
  in
  Printf.sprintf "music/track%02d.ogg" n

let play (ogg : string) : unit = Audio.play_ogg "music" ogg
