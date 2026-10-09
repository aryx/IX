(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

let infinity = Pervasives.infinity
let neg_infinity = Pervasives.neg_infinity
let nan = Pervasives.nan
let max_float = Pervasives.max_float
let min_float = Pervasives.min_float
let epsilon_float = Pervasives.epsilon_float

external of_int : int -> float = "%floatofint"

type t = float

(* ix: OCaml's later functions, those ix's programs use *)

(* nan if one is; -0.0 less than 0.0, which < doesn't say *)
let sign_bit x = Int64.compare (Int64.bits_of_float x) 0L < 0
