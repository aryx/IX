(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wide.mli. This is mini-ml's version. Lower turns the external
 * into Ir's MulHigh, which is the processor's long multiplication in
 * ssa's code. mul_high is a function over the external so that
 * Bignum's calls inline it, through this unit's summary
 * (Lower.imports). An external is not in a summary, and a call through
 * the .mli's val would be a closure's call. OCaml's version is
 * ocaml/Wide.ml, in a directory apart, because a unit's summary is
 * read only when its source, found through the -I's, is the one the
 * summary was made from. *)

external mul_high_ext : int -> int -> int = "ml_mul_high"

let mul_high (a : int) (b : int) : int = mul_high_ext a b
