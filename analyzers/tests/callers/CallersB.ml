(* the library by an alias, ix's way *)
module L = CallersLib

let b = L.by_b 1 + L.by_both 2
let () = if b = 0 then exit 1
