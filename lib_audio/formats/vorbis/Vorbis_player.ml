(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Vorbis_player.mli *)

type t = {
  packets : string array; (* the three headers first *)
  loop : bool;
  mutable decoder : Vorbis.t;
  mutable next : int; (* the next packet to decode *)
  mutable block : float array array; (* the last one decoded *)
  mutable at : int; (* the next sample of it *)
  (* the two samples of the file's the mixer's falls between, and how
   * far it is from the first (0 to 1) *)
  mutable prev_l : float;
  mutable prev_r : float;
  mutable cur_l : float;
  mutable cur_r : float;
  mutable frac : float;
  step : float; (* the file's samples a mixer's sample *)
  mutable finished : bool;
  (* the file's length, each channel (Ogg.length), and how many of its
   * samples were read this time round *)
  length : int option;
  mutable read : int;
}

let start (packets : string array) : Vorbis.t =
  Vorbis.create ~identification:packets.(0) ~setup:packets.(2)

let create ~(loop : bool) (bytes : string) : (t, string) result =
  match Array.of_list (Ogg.packets bytes) with
  | packets when Array.length packets > 3 -> (
      match start packets with
      | decoder ->
          let step =
            float_of_int (Vorbis.rate decoder) /. float_of_int Signal.rate in
          (* (frac at 2: the file's first two samples read by the first
           * fill, the first one played as it is) *)
          Ok
            { packets; loop; decoder; next = 3; block = [||]; at = 0;
              prev_l = 0.; prev_r = 0.; cur_l = 0.; cur_r = 0.; frac = 2.;
              step; finished = false; length = Ogg.length bytes; read = 0 }
      | exception Failure e -> Error e)
  | _ -> Error "not an Ogg file of sound"

let rate (p : t) : int = Vorbis.rate p.decoder
let channels (p : t) : int = Vorbis.channels p.decoder
let finished (p : t) : bool = p.finished

(* the file's next sample, both channels (a mono file's in both): the
 * next packet decoded when the block is used up; at the end (its last
 * packet, or the length its last page says: the encoder's padding of
 * the last block is not silence), the first again or silence *)
let rec next_sample (p : t) : float * float =
  let past = match p.length with Some n -> p.read >= n | None -> false in
  if p.finished then (0., 0.)
  else if past then begin
    p.next <- Array.length p.packets;
    p.block <- [||];
    p.read <- 0;
    next_sample p
  end
  else if Array.length p.block > 0 && p.at < Array.length p.block.(0) then begin
    let l = p.block.(0).(p.at) in
    let r = if Array.length p.block > 1 then p.block.(1).(p.at) else l in
    p.at <- p.at + 1;
    p.read <- p.read + 1;
    (l, r)
  end
  else if p.next < Array.length p.packets then begin
    (* (a packet that does not decode: skipped, as a player does) *)
    (match Vorbis.decode p.decoder p.packets.(p.next) with
    | block -> p.block <- block
    | exception Failure _ -> p.block <- [||]);
    p.next <- p.next + 1;
    p.at <- 0;
    next_sample p
  end
  else if p.loop then begin
    p.decoder <- start p.packets;
    p.next <- 3;
    p.block <- [||];
    next_sample p
  end
  else begin
    p.finished <- true;
    (0., 0.)
  end

let fill (p : t) (out : Signal.stereo) : unit =
  for i = 0 to Array.length out.left - 1 do
    while p.frac >= 1. do
      p.frac <- p.frac -. 1.;
      p.prev_l <- p.cur_l;
      p.prev_r <- p.cur_r;
      let l, r = next_sample p in
      p.cur_l <- l;
      p.cur_r <- r
    done;
    out.left.(i) <- p.prev_l +. (p.frac *. (p.cur_l -. p.prev_l));
    out.right.(i) <- p.prev_r +. (p.frac *. (p.cur_r -. p.prev_r));
    p.frac <- p.frac +. p.step
  done
