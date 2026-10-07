(* ix: the author's playground's libs/core/Set.ml; over ix's Set_ (lib_core/commons), which is the playground's with more (docs/plans/plan_playground.md) *)
type 'a t = 'a Set_.t
let empty = Set_.empty
let insert = Set_.add
let remove = Set_.remove
