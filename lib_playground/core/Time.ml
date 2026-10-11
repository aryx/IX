(* ix: the author's playground's libs/core/Time.ml (docs/plans/done/plan_playground.md) *)
type posix = float
let millis_to_posix n =
  float_of_int n
let posix_to_millis n =
  int_of_float ( n *. 1000.)
