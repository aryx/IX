(* an exception raised three calls deep, in ML, and not caught
 * (debuggers/tests/walk.sh): the runtime names the frames it went
 * through, from the program's own table *)
exception Deep of int

let rec down n = if n = 0 then raise (Deep 7) else 1 + down (n - 1)

let () = print_int (down 3)
