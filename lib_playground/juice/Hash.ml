(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/juice/Hash.ml; on floats and Int32, for a machine whose ints have 31 bits *)

(* See Hash.mli *)

(* ix: on floats, where the playground's is on ints: a state goes up
 * to 2^31 - 2, and an int of a 32-bit machine (the Pi 1's, under
 * mini-ml) has 31 bits, its sign among them; a float holds an integer
 * exactly up to 2^53, and the largest product here, 16807 * (2^31 -
 * 2), is under 2^45 (as lib_playground's Lehmer). The bits folded
 * (mix) are an Int32's. The same numbers come out, on every machine:
 * Hash.mli's worked example.
 * old:
 *   let m = 2147483647
 *   (* by Schrage's method, every product below 2^31 (127773 = m / 16807, 2836 = m mod 16807) *)
 *   let park_miller (x : int) : int =
 *     let hi = x / 127773 and lo = x mod 127773 in
 *     let t = (16807 * lo) - (2836 * hi) in
 *     if t > 0 then t else t + m
 *   let mix (x : int) : int = let x = x lxor (x lsr 13) in if x = 0 then 1 else x
 *   let hash ~(seed : int) (i : int) : float =
 *     let x = ((i land 0xfffff) * 1024) + (seed land 0x3ff) + 1 in
 *     let x = park_miller (mix (park_miller (mix (park_miller x)))) in
 *     (2. *. float_of_int x /. float_of_int m) -. 1.
 *)

(* Park and Miller's minimal standard, one step: 16807 x mod (2^31 - 1)
 * (a multiple of m gives m, as Schrage's method did) *)
let m = 2147483647.

let park_miller (x : float) : float =
  let t = Float.rem (16807. *. x) m in
  if t > 0. then t else t +. m

(* the high bits folded into the low ones: breaks the linearity that
 * leaves neighbouring points correlated (see Hash.mli) *)
let mix (x : float) : float =
  let v = Int32.of_float x in
  let v = Int32.logxor v (Int32.shift_right_logical v 13) in
  if v = 0l then 1. else Int32.to_float v

let hash ~(seed : int) (i : int) : float =
  (* 20 bits of point, 10 of seed: below 2^30, positive *)
  let x = (float_of_int (i land 0xfffff) *. 1024.) +. float_of_int (seed land 0x3ff) +. 1. in
  let x = park_miller (mix (park_miller (mix (park_miller x)))) in
  (2. *. x /. m) -. 1.

let unit ~(seed : int) (i : int) : float = (hash ~seed i +. 1.) /. 2.
