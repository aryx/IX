(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wide.mli. OCaml's (dune): the product's halves, none of which
 * overflows an int; lib_crypto/Wide.ml, mini-ml's, is the processor's.
 * The same as the runtime's ml_mul_high, in C *)

let mul_high (a : int) (b : int) : int =
  let n = Sys.int_size in
  let h = n / 2 in
  let m = (1 lsl h) - 1 in
  let a0 = a land m and a1 = a lsr h and b0 = b land m and b1 = b lsr h in
  let mid = (a1 * b0) + ((a0 * b0) lsr h) in
  let mid2 = (a0 * b1) + (mid land m) in
  (* a * b over 2^2h *)
  let hi = (a1 * b1) + (mid lsr h) + (mid2 lsr h) in
  hi lsr (n - (2 * h))
