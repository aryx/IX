(* a fault three calls deep, in ML (debuggers/tests/walk.sh): an
 * integer read as a block *)
let bad () : int = Obj.obj (Obj.field (Obj.repr 0) 0)

let rec down n = if n = 0 then bad () else 1 + down (n - 1)

let () = print_int (down 3)
