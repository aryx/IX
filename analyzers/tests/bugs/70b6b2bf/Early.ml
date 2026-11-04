(* the same, linked first: 70b6b2bf's order *)
let base_bits = if Sys.int_size < 63 then 14 else 26
let of_int (n : int) : int list = [ n land ((1 lsl base_bits) - 1) ]
