(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sound.mli *)

type t = {
  wad : Wad.t;
  three_d : bool;
  (* the sounds made, by name; None: not in the WAD *)
  cache : (string, Audio.sound option) Hashtbl.t;
}

let create (wad : Wad.t) (three_d : bool) : t =
  { wad; three_d; cache = Hashtbl.create 64 }

let dmx_to_wav (lump : string) : string option =
  if String.length lump < 8 + 32 || Wad.short lump 0 <> 3 then None
  else begin
    (* (the rate unsigned: 44,100 is past a short) *)
    let rate = Wad.u8 lump 2 lor (Wad.u8 lump 3 lsl 8)
    and count = Wad.int32 lump 4 in
    let count = min count (String.length lump - 8) in
    (* (the pads: 16 bytes at each end) *)
    let first = 8 + 16 and n = max 0 (count - 32) in
    let b = Buffer.create (44 + (2 * n)) in
    let add32 (v : int) : unit =
      List.iter
        (fun (s : int) -> Buffer.add_char b (Char.chr ((v lsr s) land 255)))
        [ 0; 8; 16; 24 ]
    in
    let add16 (v : int) : unit =
      Buffer.add_char b (Char.chr (v land 255));
      Buffer.add_char b (Char.chr ((v lsr 8) land 255))
    in
    Buffer.add_string b "RIFF";
    add32 (36 + (2 * n));
    Buffer.add_string b "WAVEfmt ";
    add32 16;
    add16 1;
    add16 1;
    add32 rate;
    add32 (rate * 2);
    add16 2;
    add16 16;
    Buffer.add_string b "data";
    add32 (2 * n);
    for i = first to first + n - 1 do
      add16 ((Char.code lump.[i] - 128) * 256)
    done;
    Some (Buffer.contents b)
  end

let sound (s : t) (name : string) : Audio.sound option =
  match Hashtbl.find_opt s.cache name with
  | Some v -> v
  | None ->
      let v =
        Option.bind
          (Wad.find s.wad ("DS" ^ String.uppercase_ascii name))
          (fun (l : Wad.lump) -> Option.map Audio.wav (dmx_to_wav l.data))
      in
      Hashtbl.replace s.cache name v;
      v

(* s_sound.c's numbers *)
let clipping_dist = 1200.
let close_dist = 160.
let stereo_swing = 96. /. 128.

(* S_AdjustSoundParams: the loudness and the pan, None too far *)
let adjust (p : World.player) (x : float) (y : float) : (float * float) option =
  let d = World.approx_distance (x -. p.x) (y -. p.y) in
  if d > clipping_dist then None
  else begin
    let a = Float.atan2 (y -. p.y) (x -. p.x) -. p.angle in
    let pan = -.stereo_swing *. Float.sin a in
    let vol =
      if d < close_dist then 1.
      else (clipping_dist -. d) /. (clipping_dist -. close_dist)
    in
    if vol <= 0. then None else Some (vol, pan)
  end

let play (s : t) (w : World.t) : unit =
  let p = w.player in
  (* (one of a name a tic: a shotgun's seven pellets, one bang) *)
  let seen = Hashtbl.create 8 in
  List.iter
    (fun (e : World.sound) ->
      if not (Hashtbl.mem seen (e.sfx, e.origin)) then begin
        Hashtbl.replace seen (e.sfx, e.origin) ();
        match (sound s e.sfx, e.origin) with
        | None, _ -> ()
        | Some snd, None -> Audio.play snd
        | Some snd, Some (x, y) -> (
            if s.three_d then begin
              let m (v : float) : float = v /. 32. in
              let ears =
                Audio3d.facing ~velocity:(0., 0., 0.)
                  (m p.x, m p.y, m p.viewz)
                  p.angle
              in
              Audio.play
                (Audio3d.heard ears ~velocity:(0., 0., 0.)
                   ~reference:(close_dist /. 32.) ~speed_of_sound:343.
                   (m x, m y, m p.viewz)
                   snd)
            end
            else
              match adjust p x y with
              | Some (vol, pan) ->
                  (* old: Audio.play (snd |> Audio.louder vol |> Audio.pan pan) *)
                  Audio.play_at ~volume:vol ~pan snd
              | None -> ())
      end)
    (List.rev w.sounds);
  w.sounds <- []

let music (wad : Wad.t) (map : string) : unit =
  match Wad.find wad ("D_" ^ map) with
  | Some l -> Audio.play_midi "music" (Mus.to_midi l.data)
  | None -> ()
