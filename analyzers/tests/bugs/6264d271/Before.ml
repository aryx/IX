(* 6264d271^, games/doom/Play.ml: Collide named, two units of that name in
 * the program (mini-doom's, lib_physics's): the walks a segmentation
 * fault, one's code called with the other's values *)
let walk () = fst (Collide.try_move 1 2)

let () = print_int (walk ()); print_float (Body.step 1.0)
