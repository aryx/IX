(* the program mini-acid debugs with ix's ml.acid (debuggers/tests/acid_proc.sh):
 * down three calls deep, the stack walked from its base case *)
let count = ref 0

let rec down n = if n = 0 then !count + 7 else 1 + down (n - 1)

let () = print_int (down 3)
