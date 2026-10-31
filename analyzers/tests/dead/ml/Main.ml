let a = Lib.by_name 1
let b = Lib.through_apply @@ 2
let c = 3 |> Lib.through_rev
let d = List.map Lib.in_list [ 4 ]
type h = { f : int -> int }
let e = { f = Lib.in_record }
let g = e.f 5
let i = Lib.curried 1 2
let r = { Lib.kept = 1; dropped = 2 }
let j = r.Lib.kept
let k = Lib.area (Lib.Circle 1) + Lib.area (Lib.Square 2)
let () = incr Lib.counter
let l = Lib.live_value
let () = Lib.looped { Lib.on = true }
