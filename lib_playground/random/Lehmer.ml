(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/random/Lehmer.ml (docs/plans/plan_playground.md) *)

(* See Lehmer.mli *)

(* ix: a state is kept in a float, where the playground's is an int: it
 * goes up to 2^31 - 2, and an int of a 32-bit machine (the Pi1's) has
 * 31 bits, its sign among them. A float holds an integer exactly up to
 * 2^53, and the largest product below, 16807 * (2^31 - 2), is under
 * 2^45: the same numbers come out, on every machine.
 * old:
 *   type t = int
 *   let m = 2147483647 (* 2^31 - 1, a prime *)
 *   let a = 16807 (* 7^5 *)
 *   let q = m / a (* 127773 *)
 *   let r = m mod a (* 2836 *)
 *   let of_int (n : int) : t = let s = abs (n mod m) in if s = 0 then 1 else s
 *   let scramble (n : int) : t = of_int (Int32.to_int (Int32.logand (fmix32 (Int32.of_int n)) 0x7fffffffl))
 *   (* Schrage's way of a * s mod m without the product, which 32 bits do not hold *)
 *   let next (s : t) : t = let t = (a * (s mod q)) - (r * (s / q)) in if t > 0 then t else t + m
 *   let to_unit (s : t) : float = float_of_int (s - 1) /. float_of_int (m - 1)
 *)
type t = float

let m = 2147483647. (* 2^31 - 1, a prime *)
let a = 16807. (* 7^5 *)

let of_float (n : float) : t =
  let s = Float.rem (Float.abs n) m in
  if s = 0. then 1. else s

let of_int (n : int) : t = of_float (float_of_int n)

(* MurmurHash3's fmix32, on Int32 (wrapping at 2^32 natively and in a
 * browser alike) *)
let fmix32 (h : int32) : int32 =
  let xorshift k h = Int32.logxor h (Int32.shift_right_logical h k) in
  h |> xorshift 16 |> Int32.mul 0x85ebca6bl |> xorshift 13 |> Int32.mul 0xc2b2ae35l |> xorshift 16

let scramble (n : int) : t =
  (* the low 31 bits of the hash *)
  of_float (Int32.to_float (Int32.logand (fmix32 (Int32.of_int n)) 0x7fffffffl))

let next (s : t) : t = Float.rem (a *. s) m

let to_unit (s : t) : float = (s -. 1.) /. (m -. 1.)

type state = t ref

let make (seed : int) : state = ref (scramble seed)

let draw (st : state) : float =
  st := next !st;
  to_unit !st

let int (st : state) (n : int) : int = min (n - 1) (int_of_float (draw st *. float_of_int n))
let float (st : state) (x : float) : float = draw st *. x
