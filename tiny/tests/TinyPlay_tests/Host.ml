(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyPlay.ml on the host, by OCaml: WAV files read and made into the
 * speaker's samples, and what can be said of them printed (the
 * format, how many samples, their sum, the first ones); a file in
 * blocks against the same file at once; files that are no WAV it plays.
 * usage: Host.exe korobeiniki.wav *)
open TinyPlay

let le n k = String.init k (fun i -> Char.chr ((n lsr (8 * i)) land 255))

(* a WAV of these frames' bytes, with a chunk before "fmt " (an odd
 * one, padded) when [extra] *)
let make ?(format = 1) ?(extra = false) rate channels bits data =
  let chunk id body = id ^ le (String.length body) 4 ^ body ^ (if String.length body land 1 = 1 then "\000" else "") in
  let fmt = chunk "fmt " (le format 2 ^ le channels 2 ^ le rate 4 ^ le (rate * channels * bits / 8) 4 ^ le (channels * bits / 8) 2 ^ le bits 2) in
  let body = "WAVE" ^ (if extra then chunk "LIST" "odd" else "") ^ fmt ^ chunk "data" data in
  "RIFF" ^ le (String.length body) 4 ^ body

let signed s = List.init (String.length s) (fun i -> let c = Char.code s.[i] in if c > 127 then c - 256 else c)
let sum s = List.fold_left ( + ) 0 (signed s)

let say name data =
  match wav data with
  | w ->
      let n = samples w in
      let all = piece w data 0 n in
      Printf.printf "%s: %d Hz, %d channel(s), %d bits, %d bytes; %d samples, sum %d, first %s\n" name w.rate w.channels w.bits w.bytes n (sum all)
        (String.concat " " (List.map string_of_int (List.filteri (fun i _ -> i < 8) (signed all))))
  | exception Failure why -> Printf.printf "%s: %s\n" name why

let () =
  let file = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  say "korobeiniki.wav" file;
  (* in blocks, as play writes it: the same samples as at once *)
  let w = wav file in
  let n = samples w in
  let rec blocks k = if k >= n then [] else piece w file k block :: blocks (k + block) in
  Printf.printf "in blocks of %d: %s\n" block (if String.concat "" (blocks 0) = piece w file 0 n then "the same" else "OTHER");
  (* 8 bits, unsigned, two channels: the mean, 128 the silence; 16,000 a second: every other frame *)
  say "8 bits, stereo, 16,000 Hz" (make 16000 2 8 (String.concat "" (List.init 16 (fun i -> String.make 1 (Char.chr (128 + (8 * i))) ^ String.make 1 (Char.chr (128 - (4 * i)))))));
  (* 16 bits at 8,000: the top bytes as they are; a chunk to skip first *)
  say "16 bits, 8,000 Hz, a chunk before" (make ~extra:true 8000 1 16 (String.concat "" (List.map (fun v -> le (v land 0xffff) 2) [ 0; 256; -256; 32767; -32768; 1000 ])));
  (* 4,000 a second: each frame twice *)
  say "8 bits, 4,000 Hz" (make 4000 1 8 "\128\138\148\118");
  List.iter (fun (name, data) -> say name data)
    [ "not RIFF", "hello, world";
      "floats", make ~format:3 8000 1 32 "abcd";
      "24 bits", make 8000 1 24 "abc";
      "no format", "RIFF" ^ le 12 4 ^ "WAVEdata" ^ le 0 4;
      "nothing", "" ]
