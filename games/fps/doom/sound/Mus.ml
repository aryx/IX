(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mus.mli *)

(* a MIDI number of variable length: 7 bits a byte, the first ones
 * with their high bit *)
let add_vlq (b : Buffer.t) (n : int) : unit =
  let rec bytes (n : int) (acc : int list) : int list =
    if n < 128 then n :: acc else bytes (n lsr 7) ((n land 127) :: acc)
  in
  match bytes n [] with
  | [] -> ()
  | l ->
      let k = List.length l in
      List.iteri
        (fun (i : int) (v : int) ->
          Buffer.add_char b (Char.chr (if i < k - 1 then v lor 128 else v)))
        l

(* MUS's controllers 1 to 9, MIDI's: the bank, the modulation, the
 * volume, the pan, the expression, the reverb, the chorus, the sustain
 * pedal, the soft pedal *)
let controllers = [| 0; 0; 1; 7; 10; 11; 91; 93; 64; 67 |]

(* its system events 10 to 14, MIDI's controllers: all sounds off, all
 * notes off, mono, poly, reset *)
let system = [| 120; 123; 126; 127; 121 |]

let convert (mus : string) : string =
  let u8 (i : int) : int =
    if i < String.length mus then Char.code mus.[i] else 0
  in
  let u16 (i : int) : int = u8 i lor (u8 (i + 1) lsl 8) in
  let start = u16 6 in
  let track = Buffer.create (String.length mus * 2) in
  let channels = Array.make 16 (-1) and volumes = Array.make 16 127 in
  let next_channel = ref 0 and delay = ref 0 in
  (* (MUS's 15 the drums, MIDI's 9; the others in turn, 9 skipped) *)
  let midi_channel (c : int) : int =
    if c = 15 then 9
    else begin
      if channels.(c) < 0 then begin
        channels.(c) <- !next_channel;
        next_channel := !next_channel + if !next_channel = 8 then 2 else 1
      end;
      channels.(c)
    end
  in
  let event (bytes : int list) : unit =
    add_vlq track !delay;
    delay := 0;
    List.iter
      (fun (v : int) -> Buffer.add_char track (Char.chr (v land 255)))
      bytes
  in
  let i = ref start and ended = ref false in
  while (not !ended) && !i < String.length mus do
    let desc = u8 !i in
    incr i;
    let c = midi_channel (desc land 15) in
    (match (desc lsr 4) land 7 with
    | 0 ->
        event [ 0x80 lor c; u8 !i land 127; 64 ];
        incr i
    | 1 ->
        let note = u8 !i in
        incr i;
        if note land 128 <> 0 then begin
          volumes.(desc land 15) <- u8 !i land 127;
          incr i
        end;
        event [ 0x90 lor c; note land 127; volumes.(desc land 15) ]
    | 2 ->
        (* (8 bits of the wheel to MIDI's 14) *)
        let v = u8 !i * 64 in
        incr i;
        event [ 0xe0 lor c; v land 127; (v lsr 7) land 127 ]
    | 3 ->
        let k = u8 !i in
        incr i;
        if k >= 10 && k <= 14 then event [ 0xb0 lor c; system.(k - 10); 0 ]
    | 4 ->
        let k = u8 !i and v = u8 (!i + 1) land 127 in
        i := !i + 2;
        if k = 0 then event [ 0xc0 lor c; v ]
        else if k < 10 then event [ 0xb0 lor c; controllers.(k); v ]
    | 6 -> ended := true
    | _ -> ());
    if desc land 128 <> 0 then begin
      let d = ref 0 and more = ref true in
      while !more && !i < String.length mus do
        let v = u8 !i in
        incr i;
        d := (!d lsl 7) lor (v land 127);
        more := v land 128 <> 0
      done;
      delay := !delay + !d
    end
  done;
  event [ 0xff; 0x2f; 0 ];
  let b = Buffer.create (Buffer.length track + 22) in
  let add32 (n : int) : unit =
    List.iter
      (fun (s : int) -> Buffer.add_char b (Char.chr ((n lsr s) land 255)))
      [ 24; 16; 8; 0 ]
  in
  let add16 (n : int) : unit =
    Buffer.add_char b (Char.chr ((n lsr 8) land 255));
    Buffer.add_char b (Char.chr (n land 255))
  in
  (* (format 0, one track, 70 tics a beat; the tempo MIDI's 120 by
   * default: 140 tics a second) *)
  Buffer.add_string b "MThd";
  add32 6;
  add16 0;
  add16 1;
  add16 70;
  Buffer.add_string b "MTrk";
  add32 (Buffer.length track);
  Buffer.add_buffer b track;
  Buffer.contents b

let to_midi (lump : string) : string =
  if String.length lump >= 4 && String.sub lump 0 4 = "MUS\026" then
    convert lump
  else lump
