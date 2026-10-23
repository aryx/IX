(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sound.mli *)

open Model

type t = {
  read : string -> string option;
  three_d : bool;
  cache : (string, Audio.sound option) Hashtbl.t;
}

let create (read : string -> string option) (three_d : bool) : t =
  { read; three_d; cache = Hashtbl.create 64 }

let sound (s : t) (name : string) : Audio.sound option =
  match Hashtbl.find_opt s.cache name with
  | Some v -> v
  | None ->
      let v = Option.map Audio.wav (s.read ("sound/" ^ name ^ ".wav")) in
      Hashtbl.replace s.cache name v;
      v

(* snd_dma.c's sound_nominal_clip_dist *)
let clip_dist = 1000.

(* the effects' master volume (Quake's "volume", 0.7 by default): a
 * fight's sounds at once stay under the music's top *)
let volume = 0.5

let play (s : t) (sounds : Edict.sound list) (eye : vec) (yaw : float) : unit =
  let a = yaw *. Float.pi /. 180. in
  (* (the listener's right: the yaw less a quarter turn) *)
  let right = { x = Float.sin a; y = -.Float.cos a; z = 0. } in
  (* (one of a name a frame: a shotgun's pellets' ricochets, one) *)
  let heard = Hashtbl.create 8 in
  List.iter
    (fun (e : Edict.sound) ->
      if not (Hashtbl.mem heard e.sfx) then begin
        Hashtbl.replace heard e.sfx ();
        match (sound s e.sfx, e.at) with
        | None, _ -> ()
        | Some snd, None -> Audio.play (Audio.louder volume snd)
        | Some snd, Some o ->
            if s.three_d then begin
              let m (v : vec) : float * float * float =
                (v.x /. 32., v.y /. 32., v.z /. 32.)
              in
              let ears = Audio3d.facing ~velocity:(0., 0., 0.) (m eye) a in
              Audio.play
                (Audio3d.heard ears ~velocity:(0., 0., 0.)
                   ~reference:(clip_dist /. 32. /. 8.)
                   ~speed_of_sound:343. (m o) (Audio.louder volume snd))
            end
            else begin
              let d = sub o eye in
              let dist = length d *. e.attenuation /. clip_dist in
              let vol = if e.attenuation = 0. then 1. else 1. -. dist in
              if vol > 0. then begin
                let pan =
                  if length d < 1. then 0. else dot right (normalize d)
                in
                Audio.play (snd |> Audio.louder (volume *. vol) |> Audio.pan pan)
              end
            end
      end)
    sounds
