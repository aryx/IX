(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* KAudio.ml on the host, by OCaml: sounds made into a ring of
 * KRaw's, and what can be counted of them printed (their
 * samples' crossings of zero, their largest, their last, what is left
 * past them); messages read, and bad ones.
 * usage: Host.exe *)

let ring = 0xc00000 and size = 8192

let sample i =
  let b = KRaw.peekb (ring + (i land (size - 1))) in
  if b > 127 then b - 256 else b
let clear () = Bytes.fill KRaw.mem ring size '\000'

(* the samples from at, n of them: how many times the sign changes,
 * the largest, the last; and whether the one after is still 0 *)
let say name at n =
  let crossings = ref 0 and largest = ref 0 in
  for i = at + 1 to at + n - 1 do
    if (sample i >= 0) <> (sample (i - 1) >= 0) then incr crossings;
    largest := max !largest (abs (sample i))
  done;
  Printf.printf
    "%s: %d samples, %d crossings, largest %d, last %d, after %d\n"
    name n !crossings !largest (sample (at + n - 1)) (sample (at + n))

(* a tone, its wave by its number in a message (0 a square, 1 a
 * triangle, 2 a sawtooth, 3 noise), and back *)
let tone w hz to_hz n volume : KAudio.tone =
  { t_wave = (match w with 0 -> Square | 1 -> Triangle | 2 -> Sawtooth
                           | _ -> Noise);
    t_hz = hz; t_to_hz = to_hz; t_samples = n; t_volume = volume }
let wave_number (w : KAudio.wave) =
  match w with Square -> 0 | Triangle -> 1 | Sawtooth -> 2 | Noise -> 3

let () =
  (* a square of 1,000 Hz for 10 ms: 80 samples, two crossings a period *)
  clear ();
  KAudio.mix ring size 0 (tone 0 1000 1000 80 100);
  say "square 1000 Hz" 0 80;
  (* sliding from 500 to 1,500 Hz: more crossings in its second half *)
  clear ();
  KAudio.mix ring size 0 (tone 0 500 1500 800 100);
  say "slide, first half" 0 400;
  say "slide, second half" 400 400;
  (* the other waves *)
  clear ();
  KAudio.mix ring size 0 (tone 1 440 440 800 100);
  say "triangle 440 Hz" 0 800;
  clear ();
  KAudio.mix ring size 0 (tone 2 440 440 800 100);
  say "sawtooth 440 Hz" 0 800;
  clear ();
  KAudio.mix ring size 0 (tone 3 2000 2000 800 100);
  say "noise" 0 800;
  (* two sounds at the same place add up, and stop at 127 *)
  clear ();
  KAudio.mix ring size 0 (tone 0 1000 1000 80 100);
  KAudio.mix ring size 0 (tone 0 1000 1000 80 100);
  say "twice the square" 0 80;
  (* the ring goes round: from its last two samples to its first six *)
  clear (); KAudio.mix ring size (size - 2) (tone 0 1000 1000 8 100);
  Printf.printf "round the ring: %s\n"
    (String.concat " "
       (List.map (fun i -> string_of_int (sample i))
          [ size - 3; size - 2; size - 1; 0; 1; 5; 6 ]));
  (* messages: two sounds, then bad ones *)
  let two =
    TinyLibDraw.msg 's' [ 0; 784; 784; 60; 40 ]
    ^ TinyLibDraw.msg 's' [ 1; 440; 80; 700; 90 ] in
  List.iter (function
    | KAudio.Tone t ->
        Printf.printf
          "message: wave %d, %d to %d Hz, %d samples, volume %d\n"
          (wave_number t.t_wave) t.t_hz t.t_to_hz t.t_samples t.t_volume
    | KAudio.Samples s ->
        Printf.printf "message: %d samples, %s\n" (String.length s)
          (String.concat " "
             (List.map (fun c -> string_of_int (Char.code c))
                (List.of_seq (String.to_seq s)))))
    (KAudio.sounds (two ^ TinyLibDraw.msg 'p' [ 3 ] ^ "\001\127\255"));
  (* samples added to what is there: 100 + 100 kept at 127, -1 + 1 *)
  clear ();
  KRaw.pokeb ring 100;
  KRaw.pokeb (ring + 1) 255;
  KAudio.mix_sound ring size 0 (KAudio.Samples "\100\001");
  Printf.printf "samples added: %d %d\n" (sample 0) (sample 1);
  List.iter (fun (name, m) ->
    Printf.printf "%s: %s\n" name
      (match KAudio.sounds m with
       | _ -> "read"
       | exception KAudio.Bad_sound -> "bad"))
    [ "cut short", String.sub two 0 15;
      "samples cut short", TinyLibDraw.msg 'p' [ 3 ] ^ "\001\002";
      "another letter", "x" ^ String.sub two 1 10;
      "5,000 Hz", TinyLibDraw.msg 's' [ 0; 5000; 440; 10; 40 ];
      "two seconds", TinyLibDraw.msg 's' [ 0; 440; 440; 2000; 40 ];
      "nothing", "" ]

