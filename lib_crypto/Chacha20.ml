(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/crypto/Chacha20.ml; for _i (mini-ml has no for _) (docs/plans/plan_browser.md) *)

(* See Chacha20.mli *)

(* A word is an int32, as the hashes': an int has 31 bits where mini-ml
 * compiles for arm (mini-9pi), and a word in one gave other bytes there.
 * old: let mask = 0xffffffff, and (x.(a) + x.(b)) land mask on ints *)
let ( +: ) = Int32.add
let ( ^: ) = Int32.logxor
let rotl (x : int32) (n : int) : int32 = Int32.logor (Int32.shift_left x n) (Int32.shift_right_logical x (32 - n))
let le32 (s : string) (i : int) : int32 =
  let byte k = Int32.of_int (Char.code s.[i + k]) in
  Int32.logor (Int32.logor (byte 0) (Int32.shift_left (byte 1) 8)) (Int32.logor (Int32.shift_left (byte 2) 16) (Int32.shift_left (byte 3) 24))

let quarter (x : int32 array) a b c d =
  x.(a) <- x.(a) +: x.(b);
  x.(d) <- rotl (x.(d) ^: x.(a)) 16;
  x.(c) <- x.(c) +: x.(d);
  x.(b) <- rotl (x.(b) ^: x.(c)) 12;
  x.(a) <- x.(a) +: x.(b);
  x.(d) <- rotl (x.(d) ^: x.(a)) 8;
  x.(c) <- x.(c) +: x.(d);
  x.(b) <- rotl (x.(b) ^: x.(c)) 7

let block ~(key : string) ~(nonce : string) (counter : int) : string =
  let init =
    Array.concat
      [ [| 0x61707865l; 0x3320646el; 0x79622d32l; 0x6b206574l |]; Array.init 8 (fun i -> le32 key (4 * i)); [| Int32.of_int counter |];
        Array.init 3 (fun i -> le32 nonce (4 * i)) ]
  in
  let x = Array.copy init in
  for _i = 1 to 10 do
    quarter x 0 4 8 12;
    quarter x 1 5 9 13;
    quarter x 2 6 10 14;
    quarter x 3 7 11 15;
    quarter x 0 5 10 15;
    quarter x 1 6 11 12;
    quarter x 2 7 8 13;
    quarter x 3 4 9 14
  done;
  String.init 64 (fun i -> Char.chr (Int32.to_int (Int32.shift_right_logical (x.(i / 4) +: init.(i / 4)) (8 * (i mod 4))) land 0xff))

let encrypt ~(key : string) ~(nonce : string) ~(counter : int) (data : string) : string =
  let n = String.length data in
  let out = Bytes.create n in
  let rec go i c =
    if i < n then (
      let ks = block ~key ~nonce c in
      for j = 0 to min 64 (n - i) - 1 do
        Bytes.set out (i + j) (Char.chr (Char.code data.[i + j] lxor Char.code ks.[j]))
      done;
      go (i + 64) (c + 1))
  in
  go 0 counter;
  Bytes.to_string out
