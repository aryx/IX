(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sha1.mli *)

type t = string

(* A word of 32 bits as its two halves of 16, (high, low): an integer
 * has 31. A shift may lose its top bits, never its low ones, which
 * land 0xffff keeps. *)
let add (ah, al) (bh, bl) = let l = al + bl in (ah + bh + (l lsr 16)) land 0xffff, l land 0xffff
let logand (ah, al) (bh, bl) = ah land bh, al land bl
let logor (ah, al) (bh, bl) = ah lor bh, al lor bl
let logxor (ah, al) (bh, bl) = ah lxor bh, al lxor bl
let lognot (h, l) = h lxor 0xffff, l lxor 0xffff
let rotl (h, l) n =
  let h, l, n = if n >= 16 then l, h, n - 16 else h, l, n in
  if n = 0 then h, l
  else ((h lsl n) lor (l lsr (16 - n))) land 0xffff, ((l lsl n) lor (h lsr (16 - n))) land 0xffff

let string s =
  let n = String.length s in
  (* the message, a 1 bit, zeros, its length in bits: 64-byte blocks *)
  let total = (((n + 8) / 64) + 1) * 64 in
  let m = Bytes.make total '\000' in
  Bytes.blit_string s 0 m 0 n;
  Bytes.set m n (Char.chr 128);
  let bits = n * 8 in
  for i = 0 to 3 do Bytes.set m (total - 1 - i) (Char.chr ((bits lsr (8 * i)) land 255)) done;
  let byte i = Char.code (Bytes.get m i) in
  let h = Array.make 5 (0, 0) in
  h.(0) <- 0x6745, 0x2301; h.(1) <- 0xefcd, 0xab89; h.(2) <- 0x98ba, 0xdcfe; h.(3) <- 0x1032, 0x5476; h.(4) <- 0xc3d2, 0xe1f0;
  let w = Array.make 80 (0, 0) in
  for block = 0 to (total / 64) - 1 do
    let base = 64 * block in
    for t = 0 to 15 do
      let i = base + (4 * t) in
      w.(t) <- (byte i lsl 8) lor byte (i + 1), (byte (i + 2) lsl 8) lor byte (i + 3)
    done;
    for t = 16 to 79 do w.(t) <- rotl (logxor (logxor w.(t - 3) w.(t - 8)) (logxor w.(t - 14) w.(t - 16))) 1 done;
    let a = ref h.(0) and b = ref h.(1) and c = ref h.(2) and d = ref h.(3) and e = ref h.(4) in
    for t = 0 to 79 do
      let f, k =
        if t < 20 then logor (logand !b !c) (logand (lognot !b) !d), (0x5a82, 0x7999)
        else if t < 40 then logxor (logxor !b !c) !d, (0x6ed9, 0xeba1)
        else if t < 60 then logor (logor (logand !b !c) (logand !b !d)) (logand !c !d), (0x8f1b, 0xbcdc)
        else logxor (logxor !b !c) !d, (0xca62, 0xc1d6) in
      let temp = add (add (add (rotl !a 5) f) (add !e k)) w.(t) in
      e := !d; d := !c; c := rotl !b 30; b := !a; a := temp
    done;
    h.(0) <- add h.(0) !a; h.(1) <- add h.(1) !b; h.(2) <- add h.(2) !c; h.(3) <- add h.(3) !d; h.(4) <- add h.(4) !e
  done;
  let r = Bytes.make 20 '\000' in
  for i = 0 to 4 do
    let hi, lo = h.(i) in
    Bytes.set r (4 * i) (Char.chr (hi lsr 8)); Bytes.set r ((4 * i) + 1) (Char.chr (hi land 255));
    Bytes.set r ((4 * i) + 2) (Char.chr (lo lsr 8)); Bytes.set r ((4 * i) + 3) (Char.chr (lo land 255))
  done;
  Bytes.to_string r

let to_hex t =
  let digit n = String.get "0123456789abcdef" n in
  String.init (2 * String.length t) (fun i -> let c = Char.code (String.get t (i / 2)) in digit (if i mod 2 = 0 then c lsr 4 else c land 15))
