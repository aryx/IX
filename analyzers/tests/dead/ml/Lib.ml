(* mini-analyze -dead on ML: every call is through a variable *)
type shape = Circle of int | Square of int | Never of int
type r = { kept : int; dropped : int }

let by_name x = x + 1
let through_apply x = x + 2
let through_rev x = x + 3
let in_list x = x + 4
let in_record x = x + 5
let curried a b = a + b

let unused x = x + 6
let only_by_dead x = x + 7
let dead_caller x = only_by_dead x
let rec ping x = pong x
and pong x = ping x

let area s = match s with Circle r -> r | Square a -> a | Never n -> n

let counter = ref 0
let dead_value = 42
let live_value = 43

(* a field read only as a condition is read *)
type flag = { mutable on : bool }
let looped f = while f.on do f.on <- false done
