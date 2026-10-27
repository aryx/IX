(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Unbox's boxes where the double is read as a word: a loop's sum
 * returned (boxed once, after the loop), a double boxed in one branch
 * alone, one made before a loop and kept at each turn (boxed once, not
 * in the loop), one made in an outer loop and read in an inner one;
 * blocks made meanwhile, so that the collector runs (ML_HEAP=64) *)

let sum (a : Float.Array.t) : float =
  let s = ref 0.0 in
  for i = 0 to Float.Array.length a - 1 do
    s := !s +. Float.Array.get a i
  done;
  !s

let shown = ref []
let show (x : float) = shown := x :: !shown

let branch (x : float) (k : int) : float =
  let y = x *. 2.0 in
  if k mod 3 = 0 then (show y; 0.0) else y +. 1.0

let kept (x : float) (n : int) : float list =
  let y = x +. 0.5 in
  let l = ref [] in
  for _j = 1 to n do
    l := y :: !l
  done;
  !l

let nested (n : int) : float list =
  let l = ref [] in
  for i = 1 to n do
    let y = float_of_int i *. 1.5 in
    for _j = 1 to i do
      l := y :: !l
    done
  done;
  !l

let () =
  let a = Float.Array.init 1000 (fun i -> float_of_int i *. 0.25) in
  Printf.printf "sum %g\n" (sum a);
  let t = ref 0.0 in
  for k = 0 to 99 do
    t := !t +. branch (float_of_int k) k
  done;
  Printf.printf "branch %g %d %g\n" !t (List.length !shown) (List.fold_left ( +. ) 0.0 !shown);
  let l = kept 3.0 5000 in
  Printf.printf "kept %d %g\n" (List.length l) (List.fold_left ( +. ) 0.0 l);
  let l = nested 60 in
  Printf.printf "nested %d %g\n" (List.length l) (List.fold_left ( +. ) 0.0 l)
