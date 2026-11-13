(* ix: copied from libs/core/Set.ml in the author's playground
 * (docs/plans/done/plan_playground.md). It is built over ix's Set_
 * (lib_core/commons), which is the playground's Set_ with more in it. *)
type 'a t = 'a Set_.t
let empty = Set_.empty
let insert = Set_.add
let remove = Set_.remove
