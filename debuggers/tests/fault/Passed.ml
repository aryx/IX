(* an exception passed on by a handler that does not match it
 * (debuggers/tests/walk.sh): the trace says where it was raised, not
 * the handler's raise again (mini-ml's Reraise, OCaml's reraise) *)
exception Deep of int

let rec down n = if n = 0 then raise (Deep 7) else 1 + down (n - 1)

let shallow () = try down 3 with Not_found -> 0

let () = print_int (shallow ())
