(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Resample.mli *)

(* ix: the author's playground's libs/audio/signal/Resample.ml (docs/plans/plan_audio.md) *)

type kind = Nearest | Linear | Cubic

let kinds = [ Nearest; Linear; Cubic ]
let name = function Nearest -> "nearest" | Linear -> "linear" | Cubic -> "cubic"
let kind = ref Linear

let read (kind : kind) (s : Signal.t) (position : float) : float =
  let n = Array.length s in
  let at i = if i < 0 || i >= n then 0. else s.(i) in
  let i = int_of_float (Float.floor position) in
  let t = position -. float_of_int i in
  match kind with
  | Nearest -> at (int_of_float (Float.round position))
  | Linear -> at i +. (t *. (at (i + 1) -. at i))
  | Cubic ->
      (* Catmull-Rom through p0 p1 p2 p3, between p1 and p2 *)
      let p0 = at (i - 1) and p1 = at i and p2 = at (i + 1) and p3 = at (i + 2) in
      p1
      +. (0.5 *. t
         *. (p2 -. p0
            +. (t *. ((2. *. p0) -. (5. *. p1) +. (4. *. p2) -. p3 +. (t *. ((3. *. (p1 -. p2)) +. p3 -. p0))))))

let faster (kind : kind) (k : float) (s : Signal.t) : Signal.t =
  let n = int_of_float (float_of_int (Array.length s) /. k) in
  Array.init (max 0 n) (fun i -> read kind s (float_of_int i *. k))

let to_rate (kind : kind) (rate : int) (s : Signal.t) : Signal.t =
  if rate = Signal.rate then s else faster kind (float_of_int rate /. float_of_int Signal.rate) s
