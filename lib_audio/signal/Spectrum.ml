(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Spectrum.mli *)

(* ix: the author's playground's libs/audio/signal/Spectrum.ml its optional arguments are said (docs/plans/plan_audio.md) *)

type complex = float * float

let dft (x : float array) : complex array =
  let n = Array.length x in
  Array.init n (fun k ->
      let re = ref 0. and im = ref 0. in
      Array.iteri
        (fun i xi ->
          let a = 2. *. Float.pi *. float_of_int (k * i mod n) /. float_of_int n in
          re := !re +. (xi *. cos a);
          im := !im -. (xi *. sin a))
        x;
      (!re, !im))

let fft (x : float array) : complex array =
  let n = Array.length x in
  if n land (n - 1) <> 0 then invalid_arg "Spectrum.fft: not a power of 2";
  (* recursive, the definition's shape: the even samples' transform
   * and the odd ones', combined: X[k] = E[k] + w^k O[k], X[k + n/2] =
   * E[k] - w^k O[k], w = e^(-2 pi i / n) (the butterfly) *)
  let rec go (x : complex array) : complex array =
    let n = Array.length x in
    if n = 1 then x
    else
      let even = go (Array.init (n / 2) (fun i -> x.(2 * i))) and odd = go (Array.init (n / 2) (fun i -> x.((2 * i) + 1))) in
      let out = Array.make n (0., 0.) in
      for k = 0 to (n / 2) - 1 do
        let a = -2. *. Float.pi *. float_of_int k /. float_of_int n in
        let (ore, oim) = odd.(k) and (ere, eim) = even.(k) in
        (* w^k O[k] *)
        let tre = (cos a *. ore) -. (sin a *. oim) and tim = (cos a *. oim) +. (sin a *. ore) in
        out.(k) <- (ere +. tre, eim +. tim);
        out.(k + (n / 2)) <- (ere -. tre, eim -. tim)
      done;
      out
  in
  go (Array.map (fun v -> (v, 0.)) x)

let magnitudes (spectrum : complex array) : float array =
  let n = Array.length spectrum in
  Array.init ((n / 2) + 1) (fun k ->
      let (re, im) = spectrum.(k) in
      let m = sqrt ((re *. re) +. (im *. im)) /. float_of_int n in
      if k = 0 || k = n / 2 then m else 2. *. m)

let bin_frequency ~(n : int) (k : int) : float = float_of_int k *. float_of_int Signal.rate /. float_of_int n

let hann (x : float array) : float array =
  let n = Array.length x in
  Array.mapi (fun i v -> v *. 0.5 *. (1. -. cos (2. *. Float.pi *. float_of_int i /. float_of_int (n - 1)))) x

(* ix: of_signal's transform in flat arrays (Float.Array), the real and
 * imaginary parts apart, each size's w^k and the window made once and
 * kept: the same arithmetic as fft's, magnitudes' and hann's, in the
 * same order. By mini-ml a complex was a pair of two new floats, and
 * each butterfly called cos and sin twice; mini-rebirth's spectrum,
 * 4,096 samples a frame, was a third of its time (old: magnitudes (fft
 * (if window then hann x else x))) *)
let twiddles : (int * (Float.Array.t * Float.Array.t)) list ref = ref []

(* w^k's cos and sin for k < n / 2, at n *)
let twiddle (n : int) : Float.Array.t * Float.Array.t =
  match List.assoc_opt n !twiddles with
  | Some w -> w
  | None ->
      let c = Float.Array.make (n / 2) 0. and s = Float.Array.make (n / 2) 0. in
      for k = 0 to (n / 2) - 1 do
        let a = -2. *. Float.pi *. float_of_int k /. float_of_int n in
        Float.Array.set c k (cos a);
        Float.Array.set s k (sin a)
      done;
      twiddles := (n, (c, s)) :: !twiddles;
      (c, s)

(* fft's recursion unrolled: the samples in bit-reversed order, then
 * each size's butterflies in place, a block of [len] holding the even
 * samples' transform in its first half and the odd ones' in its second,
 * as go's two calls returned them: the same products and sums *)
(* i's bits reversed, for each i < n, at n *)
let reversals : (int * int array) list ref = ref []

let reversal (n : int) : int array =
  match List.assoc_opt n !reversals with
  | Some r -> r
  | None ->
      let rec log i = if 1 lsl i >= n then i else log (i + 1) in
      let bits = log 0 in
      let r =
        Array.init n (fun i ->
            let r = ref 0 in
            for b = 0 to bits - 1 do
              if i land (1 lsl b) <> 0 then r := !r lor (1 lsl (bits - 1 - b))
            done;
            !r)
      in
      reversals := (n, r) :: !reversals;
      r

let fft_flat (x : Float.Array.t) : Float.Array.t * Float.Array.t =
  let n = Float.Array.length x in
  let reversed = reversal n in
  let re = Float.Array.make n 0. and im = Float.Array.make n 0. in
  for i = 0 to n - 1 do
    Float.Array.set re i (Float.Array.get x reversed.(i))
  done;
  let len = ref 2 in
  while !len <= n do
    let half = !len / 2 in
    let (c, s) = twiddle !len in
    let start = ref 0 in
    while !start < n do
      for k = 0 to half - 1 do
        let e = !start + k in
        let o = e + half in
        let c = Float.Array.get c k and s = Float.Array.get s k in
        let ore = Float.Array.get re o and oim = Float.Array.get im o in
        let ere = Float.Array.get re e and eim = Float.Array.get im e in
        (* w^k O[k] *)
        let tre = (c *. ore) -. (s *. oim) and tim = (c *. oim) +. (s *. ore) in
        Float.Array.set re e (ere +. tre);
        Float.Array.set im e (eim +. tim);
        Float.Array.set re o (ere -. tre);
        Float.Array.set im o (eim -. tim)
      done;
      start := !start + !len
    done;
    len := 2 * !len
  done;
  (re, im)

(* hann's 1 - cos, at n *)
let windows : (int * Float.Array.t) list ref = ref []

let window_of (n : int) : Float.Array.t =
  match List.assoc_opt n !windows with
  | Some w -> w
  | None ->
      let w = Float.Array.make n 0. in
      for i = 0 to n - 1 do
        Float.Array.set w i
          (1. -. cos (2. *. Float.pi *. float_of_int i /. float_of_int (n - 1)))
      done;
      windows := (n, w) :: !windows;
      w

(* ix: window was optional: true *)
let of_signal ~(window : bool) (s : Signal.t) : float array =
  let rec pow2 p = if p * 2 <= min 4096 (Array.length s) then pow2 (p * 2) else p in
  let n = pow2 1 in
  let re = Float.Array.make n 0. in
  let w = window_of n in
  for i = 0 to n - 1 do
    Float.Array.set re i
      (if window then s.(i) *. 0.5 *. Float.Array.get w i else s.(i))
  done;
  let (re, im) = fft_flat re in
  Array.init ((n / 2) + 1) (fun k ->
      let re = Float.Array.get re k and im = Float.Array.get im k in
      let m = sqrt ((re *. re) +. (im *. im)) /. float_of_int n in
      if k = 0 || k = n / 2 then m else 2. *. m)

let peak (mags : float array) : int =
  let best = ref 1 in
  Array.iteri (fun k m -> if k > 0 && m > mags.(!best) then best := k) mags;
  !best
