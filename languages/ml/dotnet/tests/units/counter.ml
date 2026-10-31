(* a unit with state: a reference made by its toplevel, which runs
   before main's (its type initializer, in link order) *)
let total = ref 0

let add s = total := !total + Geometry.area s

let () = print_endline "counter: ready"
