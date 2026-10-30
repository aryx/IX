(* the program mini-acid debugs with ix's acid library (debuggers/tests/acid_proc.sh):
 * down three calls deep: its stack walked, a breakpoint by its line *)
let count = ref 0

let rec down n = if n = 0 then !count + 7 else 1 + down (n - 1)

let () = print_int (down 3)
