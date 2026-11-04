(* 6264d271, its fix: Collision, the only unit of its name *)
let walk () = fst (Collision.try_move 1 2)

let () = print_int (walk ())
