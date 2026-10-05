type t = [%mli]

let show_point : t Classy.show = { show = (fun p -> "(" ^ Classy.show p.x ^ ", " ^ Classy.show p.y ^ ")") } [@@instance]
let origin = { x = 0; y = 0 }
