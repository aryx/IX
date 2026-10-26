(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A unit whose small functions another of its directory inlines:
 * floats compared, ints compared, strings equal, an exception raised,
 * a global read (its summary, Small.inline: Summary.mli) *)

exception Negative of int

let two_pi = 8. *. atan 1.
let table = Array.init 8 (fun i -> i * i)
let norm (a : float) : float = if a >= 0. && a < two_pi then a else a -. (two_pi *. floor (a /. two_pi))
let fine (a : float) : int = int_of_float (norm a *. 100.) land 1023
let less (a : int) (b : int) : bool = a < b
let same (a : string) (b : string) : bool = a = b
let checked (n : int) : int = if n < 0 then raise (Negative n) else n
let at (i : int) : int = table.(i land 7)
let clamp (lo : float) (hi : float) (x : float) : float = if x < lo then lo else if x > hi then hi else x
