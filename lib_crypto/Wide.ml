(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wide.mli. mini-ml's: Lower makes the external Ir's MulHigh, the
 * processor's long multiplication in ssa's code. A function over it, so
 * that Bignum's calls inline it (this unit's summary, Lower.imports):
 * an external is not in a summary, and through the .mli's val it was a
 * closure's call. OCaml's is ocaml/Wide.ml, apart: a unit's summary is
 * read when its text, found by the -I's, is the one it was made of *)

external mul_high_ext : int -> int -> int = "ml_mul_high"

let mul_high (a : int) (b : int) : int = mul_high_ext a b
