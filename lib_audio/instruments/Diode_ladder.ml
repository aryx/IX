(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Diode_ladder.mli *)

(* ix: the author's playground's libs/audio/instruments/Diode_ladder.ml (docs/plans/plan_audio.md) *)

(* ix: v1..v4 then the input before (the trapezoid's), in a flat array,
 * and the system's matrix, its right side and its answer made once: by
 * mini-ml, a float stored in a float array or a mutable float field is
 * a new block and the write barrier, and process made 25 arrays a
 * sample (old: { v : float array; mutable last_x : float }, solve on a
 * float array array, a new m, y and x each sample) *)
type t = {
  v : Float.Array.t;
  m : Float.Array.t;
  y : Float.Array.t;
  x : Float.Array.t;
}

let create () : t =
  { v = Float.Array.make 5 0.; m = Float.Array.make 16 0.;
    y = Float.Array.make 4 0.; x = Float.Array.make 4 0. }

let reset (t : t) : unit = Float.Array.fill t.v 0 5 0.
let rate = float_of_int Signal.rate

(* the equations as v' = w (A v + b u): A's rows, b = (2, 0, 0, 0) *)
let a = [| [| -4.; 2.; 0.; 0. |]; [| 1.; -2.; 1.; 0. |]; [| 0.; 1.; -2.; 1. |]; [| 0.; 0.; 1.; -1. |] |]

(* the feedback enters through u = x - k v4: A's first row gains
 * -2 k in its last column; row r's column c at 4 r + c *)
let with_feedback (k : float) : Float.Array.t =
  Float.Array.init 16 (fun rc ->
      let i = rc / 4 and j = rc mod 4 in
      if i = 0 && j = 3 then a.(i).(j) -. (2. *. k) else a.(i).(j))

(* (inlined: mini-ml's, a small function of the unit) *)
let get (a : Float.Array.t) (i : int) : float = Float.Array.unsafe_get a i
let set (a : Float.Array.t) (i : int) (x : float) : unit =
  Float.Array.unsafe_set a i x

(* [solve t]: m x = y, 4 x 4 (row r's column c at 4 r + c, unchecked:
 * the loops' bounds keep it within 16), Gaussian
 * elimination with partial pivoting, the rows swapped where the
 * playground swaps their arrays; m and y are overwritten *)
let solve (t : t) : unit =
  let n = 4 and m = t.m and y = t.y and x = t.x in
  for c = 0 to n - 1 do
    let p = ref c in
    for r = c + 1 to n - 1 do
      if Float.abs (get m ((4 * r) + c))
         > Float.abs (get m ((4 * !p) + c))
      then p := r
    done;
    let p = !p in
    if p <> c then
      for j = 0 to n - 1 do
        let tmp = get m ((4 * c) + j) in
        set m ((4 * c) + j) (get m ((4 * p) + j));
        set m ((4 * p) + j) tmp
      done;
    let ty = get y c in
    set y c (get y p);
    set y p ty;
    for r = c + 1 to n - 1 do
      let f = get m ((4 * r) + c) /. get m ((4 * c) + c) in
      for j = c to n - 1 do
        set m ((4 * r) + j) (get m ((4 * r) + j) -. (f *. get m ((4 * c) + j)))
      done;
      set y r (get y r -. (f *. get y c))
    done
  done;
  for r = n - 1 downto 0 do
    let s = ref (get y r) in
    for j = r + 1 to n - 1 do
      s := !s -. (get m ((4 * r) + j) *. get x j)
    done;
    set x r (!s /. get m ((4 * r) + r))
  done

let process (t : t) ~(cutoff : Float.Array.t) ~(resonance : float)
    (s : Float.Array.t) : unit =
  let ak = with_feedback resonance and v = t.v and m = t.m and y = t.y in
  let highest = 0.45 *. rate in
  for i = 0 to Float.Array.length s - 1 do
    let x = tanh (Float.Array.get s i) in
    let fc = Signal.at_least 10. (Signal.at_most 20000. (Float.Array.get cutoff i)) in
    (* prewarped: the trapezoid's h w / 2 = tan (pi fc / rate) *)
    let g = tan (Float.pi *. Signal.at_most highest fc /. rate) in
    (* (I - g A) v' = (I + g A) v + g b (x + x_last) *)
    for r = 0 to 3 do
      for c = 0 to 3 do
        set m ((4 * r) + c)
          ((if r = c then 1. else 0.) -. (g *. get ak ((4 * r) + c)))
      done
    done;
    for r = 0 to 3 do
      let sum = ref (get v r) in
      for c = 0 to 3 do
        sum := !sum +. (g *. get ak ((4 * r) + c) *. get v c)
      done;
      set y r
        (if r = 0 then !sum +. (g *. 2. *. (x +. get v 4)) else !sum)
    done;
    solve t;
    for k = 0 to 3 do
      set v k (get t.x k)
    done;
    set v 4 x;
    Float.Array.set s i (get t.x 3)
  done
