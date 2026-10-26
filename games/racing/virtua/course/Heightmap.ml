(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's gamekits/heightmap/Heightmap.ml
 * (docs/plans/plan_virtuaracing.md) *)

(* See Heightmap.mli *)

type t = { size : int; cells : float array; top : float; sea : float }

(*****************************************************************************)
(* Making it up *)
(*****************************************************************************)

(* every step keeps the low 30 bits: those of a product are the same
 * whether it was computed on 32 bits (the web) or 63 (native) *)
let random (seed : int) (i : int) (j : int) : float =
  let mask = 0x3FFFFFFF in
  let h = ((seed * 0x27d4eb2d) + (i * 0x165667b1) + (j * 0x1b873593)) land mask in
  let h = h lxor (h lsr 15) in
  let h = (h * 0x2c1b3c6d) land mask in
  let h = h lxor (h lsr 12) in
  let h = (h * 0x297a2d39) land mask in
  let h = h lxor (h lsr 15) in
  (float_of_int h /. float_of_int mask *. 2.) -. 1.

(* Diamond-square, on a grid that wraps around (the cell after the last
 * is the first: no edges to special-case), [step] halved each time:
 *
 *    a . . . b       a . . . b        a . e . b
 *    . . . . .       . . . . .        . . . . .
 *    . . . . .  ->   . . m . .   ->   h . m . f
 *    . . . . .       . . . . .        . . . . .
 *    d . . . c       d . . . c        d . g . c
 *                   the diamond:     the square: e, f, g, h, the
 *                   m, a b c d's     average of the 4 points around
 *                   average + bump   (the next squares' m's too) + bump
 *)
let diamond_square (seed : int) (size : int) (roughness : float) : float array =
  let a = Array.make (size * size) 0. in
  let index i j = ((j land (size - 1)) * size) + (i land (size - 1)) in
  let get i j = a.(index i j) in
  let set i j v = a.(index i j) <- v in
  let rec go step bump =
    if step > 1 then begin
      let h = step / 2 in
      for y = 0 to (size / step) - 1 do
        for x = 0 to (size / step) - 1 do
          let i = x * step and j = y * step in
          let corners = get i j +. get (i + step) j +. get i (j + step) +. get (i + step) (j + step) in
          set (i + h) (j + h) ((corners /. 4.) +. (bump *. random seed (i + h) (j + h)))
        done
      done;
      for y = 0 to (size / h) - 1 do
        for x = 0 to (size / h) - 1 do
          (* the edges' middles: an odd number of halves from the corner *)
          if (x + y) land 1 = 1 then begin
            let i = x * h and j = y * h in
            let around = get (i - h) j +. get (i + h) j +. get i (j - h) +. get i (j + h) in
            set i j ((around /. 4.) +. (bump *. random seed i j))
          end
        done
      done;
      go h (bump *. roughness)
    end
  in
  go size 1.;
  a

let generate ~(seed : int) ~(size : int) ~(top : float) ~(roughness : float) : t =
  let a = diamond_square seed size roughness in
  let lo = Array.fold_left Float.min infinity a and hi = Array.fold_left Float.max neg_infinity a in
  (* 0..1, then lowered by the squared distance to the middle (0 there,
   * 1 at an edge's middle): the island *)
  let half = float_of_int size /. 2. in
  let island =
    Array.mapi
      (fun k h ->
        let dx = (float_of_int (k mod size) -. half) /. half and dy = (float_of_int (k / size) -. half) /. half in
        ((h -. lo) /. (hi -. lo)) -. (1.5 *. ((dx *. dx) +. (dy *. dy))))
      a
  in
  let high = Array.fold_left Float.max neg_infinity island in
  let sea = top /. 5. in
  (* 0 (and less) the sea's level, [high] the top *)
  { size; top; sea; cells = Array.map (fun h -> Float.max sea (sea +. (h /. high *. (top -. sea)))) island }

(*****************************************************************************)
(* Asking *)
(*****************************************************************************)

let cell (t : t) (i : int) (j : int) : float =
  if i < 0 || j < 0 || i >= t.size || j >= t.size then t.sea else t.cells.((j * t.size) + i)

let height (t : t) (x : float) (y : float) : float =
  let i = Float.to_int (Float.floor x) and j = Float.to_int (Float.floor y) in
  let fx = x -. Float.floor x and fy = y -. Float.floor y in
  let mix a b f = a +. ((b -. a) *. f) in
  mix (mix (cell t i j) (cell t (i + 1) j) fx) (mix (cell t i (j + 1)) (cell t (i + 1) (j + 1)) fx) fy
