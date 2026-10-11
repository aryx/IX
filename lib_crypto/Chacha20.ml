(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/crypto/Chacha20.ml; for _i (mini-ml has no for _) (docs/plans/plan_browser.md) *)

(* See Chacha20.mli *)

(* A word of 32 bits as two ints of 16, its low half first: x.(2 i) and
 * x.(2 i + 1). Right whatever an int's width, and nothing allocated: an
 * int has 31 bits where mini-ml compiles for arm (mini-9pi), and a word
 * in one gave other bytes there. block_wide below is the fast one, for
 * ints of 63 bits.
 * old: (between the two) words as int32, as the hashes': boxed by
 * mini-ml, 3,700 instructions a byte on arm *)
let h16 = 0xffff

(* a <- a + b *)
let add (x : int array) (a : int) (b : int) : unit =
  let lo = x.(2 * a) + x.(2 * b) in
  x.(2 * a) <- lo land h16;
  x.((2 * a) + 1) <- (x.((2 * a) + 1) + x.((2 * b) + 1) + (lo lsr 16)) land h16

(* d <- (d xor a) turned left by n bits: 16 (the halves change places) or less *)
let xor_rotl (x : int array) (d : int) (a : int) (n : int) : unit =
  let lo = x.(2 * d) lxor x.(2 * a) and hi = x.((2 * d) + 1) lxor x.((2 * a) + 1) in
  if n = 16 then (x.(2 * d) <- hi; x.((2 * d) + 1) <- lo)
  else begin
    x.(2 * d) <- ((lo lsl n) lor (hi lsr (16 - n))) land h16;
    x.((2 * d) + 1) <- ((hi lsl n) lor (lo lsr (16 - n))) land h16
  end

let quarter (x : int array) a b c d =
  add x a b; xor_rotl x d a 16;
  add x c d; xor_rotl x b c 12;
  add x a b; xor_rotl x d a 8;
  add x c d; xor_rotl x b c 7

let block_halves ~(key : string) ~(nonce : string) (counter : int) : string =
  let le16 (s : string) (i : int) : int = Char.code s.[i] lor (Char.code s.[i + 1] lsl 8) in
  let init =
    Array.concat
      [ [| 0x7865; 0x6170; 0x646e; 0x3320; 0x2d32; 0x7962; 0x6574; 0x6b20 |]; Array.init 16 (fun i -> le16 key (2 * i));
        [| counter land h16; (counter lsr 16) land h16 |]; Array.init 6 (fun i -> le16 nonce (2 * i)) ]
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
  (* the state at the start added back, a word at a time *)
  let out = Bytes.create 64 in
  for w = 0 to 15 do
    let lo = x.(2 * w) + init.(2 * w) in
    let hi = (x.((2 * w) + 1) + init.((2 * w) + 1) + (lo lsr 16)) land h16 in
    Bytes.set out (4 * w) (Char.chr (lo land 0xff));
    Bytes.set out ((4 * w) + 1) (Char.chr ((lo lsr 8) land 0xff));
    Bytes.set out ((4 * w) + 2) (Char.chr (hi land 0xff));
    Bytes.set out ((4 * w) + 3) (Char.chr (hi lsr 8))
  done;
  Bytes.to_string out

(*****************************************************************************)
(* opti: a word in an int of 63 bits (the playground's) *)
(*****************************************************************************)

let mask = 0xffffffff
let rotl (x : int) (n : int) : int = ((x lsl n) lor (x lsr (32 - n))) land mask
let le32 (s : string) (i : int) : int = Char.code s.[i] lor (Char.code s.[i + 1] lsl 8) lor (Char.code s.[i + 2] lsl 16) lor (Char.code s.[i + 3] lsl 24)

let quarter_wide (x : int array) a b c d =
  x.(a) <- (x.(a) + x.(b)) land mask;
  x.(d) <- rotl (x.(d) lxor x.(a)) 16;
  x.(c) <- (x.(c) + x.(d)) land mask;
  x.(b) <- rotl (x.(b) lxor x.(c)) 12;
  x.(a) <- (x.(a) + x.(b)) land mask;
  x.(d) <- rotl (x.(d) lxor x.(a)) 8;
  x.(c) <- (x.(c) + x.(d)) land mask;
  x.(b) <- rotl (x.(b) lxor x.(c)) 7

let block_wide ~(key : string) ~(nonce : string) (counter : int) : string =
  let init =
    Array.concat
      [ [| 0x61707865; 0x3320646e; 0x79622d32; 0x6b206574 |]; Array.init 8 (fun i -> le32 key (4 * i)); [| counter land mask |];
        Array.init 3 (fun i -> le32 nonce (4 * i)) ]
  in
  let x = Array.copy init in
  for _i = 1 to 10 do
    quarter_wide x 0 4 8 12;
    quarter_wide x 1 5 9 13;
    quarter_wide x 2 6 10 14;
    quarter_wide x 3 7 11 15;
    quarter_wide x 0 5 10 15;
    quarter_wide x 1 6 11 12;
    quarter_wide x 2 7 8 13;
    quarter_wide x 3 4 9 14
  done;
  String.init 64 (fun i -> Char.chr ((((x.(i / 4) + init.(i / 4)) land mask) lsr (8 * (i mod 4))) land 0xff))

(* opti: block_wide where an int holds a word and its carry *)
let block ~(key : string) ~(nonce : string) (counter : int) : string =
  if Sys.int_size >= 63 then block_wide ~key ~nonce counter else block_halves ~key ~nonce counter

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
